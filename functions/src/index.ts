import { initializeApp } from "firebase-admin/app";
import { getAuth, type UserRecord } from "firebase-admin/auth";
import { FieldValue, getFirestore, type Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import * as functionsV1 from "firebase-functions/v1";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { applyRole, RoleInputError, validateRoleInput, type Role, type RoleInput } from "./claims";
import { REGION } from "./config";
import {
  ConflictError,
  decideInvite,
  decideRemove,
  parseInviteRequest,
  PermissionError,
  type Actor,
} from "./members";
import { attendanceIdFor, decideCancellation, decideRegistration, parseRegistrationRequest } from "./registration";
import { purgeExpiredAttendance } from "./retention";
import { authorizeCheckIn, classifyScan, decideCheckIn, parseCheckInRequest } from "./checkin";
import { newQrToken, parseTicketPayload, verifyTicket, type ParsedTicket } from "./tickets";

initializeApp();

// Jakarta region: closest to Indonesian users. The Flutter client uses the same value.
setGlobalOptions({ region: REGION, maxInstances: 10 });

/** Maps domain errors to callable error codes. Unknown errors stay internal. */
function toHttpsError(error: unknown): never {
  if (error instanceof PermissionError) throw new HttpsError("permission-denied", error.message);
  if (error instanceof ConflictError) throw new HttpsError("failed-precondition", error.message);
  if (error instanceof RoleInputError) throw new HttpsError("invalid-argument", error.message);
  throw error;
}

function callerOf(request: CallableRequest): Actor {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const role = (request.auth.token.role as Role | undefined) ?? "attendee";
  const orgId = request.auth.token.orgId as string | undefined;
  return orgId ? { role, orgId } : { role };
}

function actorOf(user: UserRecord): Actor {
  const claims = user.customClaims ?? {};
  const role = (claims.role as Role | undefined) ?? "attendee";
  const orgId = claims.orgId as string | undefined;
  return orgId ? { role, orgId } : { role };
}

/**
 * Sets RBAC custom claims on a user. Only an admin may call this.
 * Firestore and Storage rules trust `role` and `orgId` from these claims.
 */
export const setUserClaims = onCall<Partial<RoleInput>>(async (request) => {
  if (request.auth?.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  try {
    const input = validateRoleInput(request.data);
    await applyRole({ auth: getAuth(), db: getFirestore() }, input);
    return { ok: true };
  } catch (error) {
    toHttpsError(error);
  }
});

/**
 * Adds a person to an organization by email.
 * Admin: organizer or committee, any org. Organizer: committee, own org only.
 * If the account exists the role applies now ("granted"). Otherwise an invite
 * is stored and applied at the person's first sign-in ("invited").
 */
export const inviteMember = onCall(async (request) => {
  const caller = callerOf(request);
  try {
    const invite = parseInviteRequest(request.data);
    const auth = getAuth();
    const db = getFirestore();

    const org = await db.collection("organizations").doc(invite.orgId).get();
    if (!org.exists) throw new RoleInputError(`organization ${invite.orgId} does not exist.`);

    const existing = await auth.getUserByEmail(invite.email).catch((error: { code?: string }) => {
      if (error.code === "auth/user-not-found") return null;
      throw error;
    });

    const action = decideInvite(caller, invite, existing ? actorOf(existing) : null);

    if (action === "grant" && existing) {
      await applyRole({ auth, db }, { uid: existing.uid, role: invite.role, orgId: invite.orgId });
      return { status: "granted", uid: existing.uid };
    }

    // One pending invite per email. Another org's pending invite wins until cancelled.
    const inviteRef = db.collection("invites").doc(invite.email);
    await db.runTransaction(async (tx) => {
      const pending = await tx.get(inviteRef);
      if (pending.exists && pending.get("organization_id") !== invite.orgId) {
        throw new ConflictError("This email already has a pending invite from another organization.");
      }
      tx.set(inviteRef, {
        email: invite.email,
        role: invite.role,
        organization_id: invite.orgId,
        invited_by: request.auth!.uid,
        created_at: FieldValue.serverTimestamp(),
      });
    });
    return { status: "invited" };
  } catch (error) {
    toHttpsError(error);
  }
});

/**
 * Removes a person from their organization: role goes back to attendee and
 * every committee assignment they had is deleted.
 * Admin: any organizer or committee member. Organizer: own org's committee.
 */
export const removeMember = onCall(async (request) => {
  const caller = callerOf(request);
  try {
    const uid = (request.data as { uid?: unknown } | null)?.uid;
    if (typeof uid !== "string" || uid.length === 0) throw new RoleInputError("uid is required.");

    const auth = getAuth();
    const db = getFirestore();
    // Only "not found" means a bad uid. Any other Auth error is a real failure.
    const target = await auth.getUser(uid).catch((error: { code?: string }) => {
      if (error.code === "auth/user-not-found") throw new RoleInputError("No account with this uid.");
      throw error;
    });
    decideRemove(caller, actorOf(target));

    await applyRole({ auth, db }, { uid, role: "attendee" });

    const assignments = await db.collectionGroup("committees").where("uid", "==", uid).get();
    const batch = db.batch();
    assignments.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    return { ok: true, removedAssignments: assignments.size };
  } catch (error) {
    toHttpsError(error);
  }
});

/**
 * Creates the users/{uid} profile on first sign-in, then applies a pending
 * invite for the account's verified email.
 * New users have no role claim, which every client and rule treats as "attendee".
 * `create()` never overwrites, so a role set by an admin is never reset.
 */
export const onUserCreated = functionsV1
  .region(REGION)
  .auth.user()
  .onCreate(async (user) => {
    const db = getFirestore();
    try {
      await db.collection("users").doc(user.uid).create({
        role: "attendee",
        organization_id: null,
        email: user.email ?? null,
        display_name: user.displayName ?? null,
        created_at: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      // 6 = ALREADY_EXISTS. The profile was written first by applyRole.
      if ((error as { code?: number }).code !== 6) throw error;
    }

    // Only a verified email may claim an invite (Google accounts are verified).
    const email = user.email?.toLowerCase();
    if (!email || !user.emailVerified) return;

    const inviteRef = db.collection("invites").doc(email);
    const invite = await inviteRef.get();
    if (!invite.exists) return;

    try {
      await applyRole(
        { auth: getAuth(), db },
        validateRoleInput({ uid: user.uid, role: invite.get("role"), orgId: invite.get("organization_id") }),
      );
      await inviteRef.delete();
      logger.info("Applied invite", { uid: user.uid, role: invite.get("role"), orgId: invite.get("organization_id") });
    } catch (error) {
      // Keep the invite so an admin can see it failed (for example, org deleted).
      logger.error("Could not apply invite", { uid: user.uid, error: (error as Error).message });
    }
  });

/**
 * Registers the caller for an event and issues their QR ticket.
 *
 * Runs in a transaction so capacity holds under concurrent registrations:
 * the event's `registered_count`, the attendance document, and the ticket
 * secret change together. Idempotent: registering twice returns the existing ticket.
 *
 * The QR signing key lives in attendance_secrets/{id}, readable only by the
 * ticket owner. Organizers and committee read attendance but never the key,
 * so they cannot mint valid tickets (audit H2).
 */
export const registerForEvent = onCall(async (request) => {
  const caller = callerOf(request);
  try {
    const { eventId } = parseRegistrationRequest(request.data);
    const uid = request.auth!.uid;
    const db = getFirestore();
    const user = await getAuth().getUser(uid);
    const eventRef = db.collection("events").doc(eventId);
    const attendanceRef = db.collection("attendance").doc(attendanceIdFor(eventId, uid));
    const secretRef = db.collection("attendance_secrets").doc(attendanceRef.id);

    const status = await db.runTransaction(async (tx) => {
      const [event, attendance] = await Promise.all([tx.get(eventRef), tx.get(attendanceRef)]);
      const state = event.exists
        ? {
            status: event.get("status") as string,
            registrationOpen: event.get("registration_open") === true,
            capacity: (event.get("capacity") as number | null | undefined) ?? null,
            registeredCount: (event.get("registered_count") as number | undefined) ?? 0,
          }
        : null;

      if (decideRegistration(caller, state, attendance.exists) === "existing") return "existing";

      tx.create(attendanceRef, {
        event_id: eventId,
        user_id: uid,
        organization_id: event.get("organization_id"),
        // Name only: check-in needs nothing else (audit M1). Organizers who
        // need contact details use the Admin SDK paths (exports, certificates).
        attendee_name: user.displayName ?? null,
        is_checked_in: false,
        certificate_issued: false,
        privacy_consent: true,
        consent_at: FieldValue.serverTimestamp(),
        registered_at: FieldValue.serverTimestamp(),
      });
      tx.create(secretRef, {
        user_id: uid,
        event_id: eventId,
        qr_token: newQrToken(),
        created_at: FieldValue.serverTimestamp(),
      });
      tx.update(eventRef, { registered_count: FieldValue.increment(1) });
      return "registered";
    });

    return { status, attendanceId: attendanceRef.id };
  } catch (error) {
    toHttpsError(error);
  }
});

/**
 * Cancels the caller's registration before check-in and frees the spot.
 */
export const cancelRegistration = onCall(async (request) => {
  callerOf(request);
  try {
    const eventId = (request.data as { eventId?: unknown } | null)?.eventId;
    if (typeof eventId !== "string" || eventId.length === 0) throw new RoleInputError("eventId is required.");
    const db = getFirestore();
    const eventRef = db.collection("events").doc(eventId);
    const attendanceRef = db.collection("attendance").doc(attendanceIdFor(eventId, request.auth!.uid));

    await db.runTransaction(async (tx) => {
      const [event, attendance] = await Promise.all([tx.get(eventRef), tx.get(attendanceRef)]);
      decideCancellation(
        attendance.exists ? { isCheckedIn: attendance.get("is_checked_in") === true } : null,
        event.exists ? (event.get("status") as string) : null,
      );
      tx.delete(attendanceRef);
      tx.delete(db.collection("attendance_secrets").doc(attendanceRef.id));
      if (event.exists) tx.update(eventRef, { registered_count: FieldValue.increment(-1) });
    });
    return { ok: true };
  } catch (error) {
    toHttpsError(error);
  }
});

/**
 * Daily retention purge (03:00 WIB): deletes attendance records and ticket
 * secrets 12 months after the event, as the privacy notice promises.
 */
export const retentionPurge = onSchedule({ schedule: "every day 03:00", timeZone: "Asia/Jakarta" }, async () => {
  const result = await purgeExpiredAttendance(getFirestore(), new Date());
  logger.info("Retention purge", result);
});

/** Runs the retention purge now. Admin only; for demos and incident response. */
export const runRetentionPurge = onCall(async (request) => {
  if (request.auth?.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
  return purgeExpiredAttendance(getFirestore(), new Date());
});

/**
 * Checks an attendee in, from a scanned rotating QR or (organizers only)
 * manually. The only way attendance becomes checked in: clients cannot write
 * attendance (audit H1).
 *
 * The code is verified against the ticket's key in attendance_secrets, which
 * only this function and the ticket owner can read. Everything that decides
 * the outcome is read in one transaction, so two doors scanning the same
 * ticket at once record one check-in.
 */
export const checkIn = onCall(async (request) => {
  const caller = callerOf(request);
  try {
    const req = parseCheckInRequest(request.data);
    const uid = request.auth!.uid;
    const db = getFirestore();
    const eventRef = db.collection("events").doc(req.eventId);

    const [event, assignment] = await Promise.all([eventRef.get(), eventRef.collection("committees").doc(uid).get()]);
    authorizeCheckIn(caller, event.exists ? (event.get("organization_id") as string) : null, assignment.exists, req.mode === "manual");

    let ticket: ParsedTicket | null = null;
    let attendanceId: string;
    if (req.mode === "scan") {
      ticket = parseTicketPayload(req.payload);
      const scan = classifyScan(req.eventId, ticket);
      // Same shape as every other outcome; nothing about the ticket holder.
      if ("result" in scan) return { result: scan.result, attendeeName: null, checkedInAt: null };
      attendanceId = scan.attendanceId;
    } else {
      attendanceId = req.attendanceId;
    }

    const attendanceRef = db.collection("attendance").doc(attendanceId);
    const secretRef = db.collection("attendance_secrets").doc(attendanceId);

    return await db.runTransaction(async (tx) => {
      const [freshEvent, attendance, secret] = await Promise.all([tx.get(eventRef), tx.get(attendanceRef), tx.get(secretRef)]);
      const check =
        req.mode === "manual"
          ? "manual"
          : secret.exists
            ? verifyTicket(ticket!, secret.get("qr_token") as string, Date.now() / 1000)
            : "invalid";
      const result = decideCheckIn(
        freshEvent.get("status") as string,
        attendance.exists
          ? { eventId: attendance.get("event_id") as string, isCheckedIn: attendance.get("is_checked_in") === true }
          : null,
        req.eventId,
        check,
      );

      if (result === "checked_in") {
        tx.update(attendanceRef, {
          is_checked_in: true,
          checked_in_at: FieldValue.serverTimestamp(),
          checked_in_by: uid,
          check_in_method: req.mode,
        });
      }

      // Only name and time go back to the door: nothing else about the attendee.
      const known = attendance.exists && result !== "wrong_event";
      const checkedInAt = known ? (attendance.get("checked_in_at") as Timestamp | undefined) : undefined;
      return {
        result,
        attendeeName: known ? ((attendance.get("attendee_name") as string | null) ?? null) : null,
        checkedInAt: result === "already_checked_in" && checkedInAt ? checkedInAt.toDate().toISOString() : null,
      };
    });
  } catch (error) {
    toHttpsError(error);
  }
});

// Next milestone:
//   - onDocumentUpdated("attendance/{id}"): when is_checked_in flips to true,
//     generate the personalized PDF certificate and email it (M5).
