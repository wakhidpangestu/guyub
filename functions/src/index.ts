import { initializeApp } from "firebase-admin/app";
import { getAuth, type UserRecord } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import * as functionsV1 from "firebase-functions/v1";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";

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
import { newQrToken } from "./tickets";

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
    const target = await auth.getUser(uid).catch(() => {
      throw new RoleInputError("No account with this uid.");
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
 * the event's `registered_count` and the attendance document change together.
 * Idempotent: registering twice returns the existing ticket.
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
        attendee_name: user.displayName ?? null,
        attendee_email: user.email ?? null,
        qr_token: newQrToken(),
        is_checked_in: false,
        certificate_issued: false,
        privacy_consent: true,
        consent_at: FieldValue.serverTimestamp(),
        registered_at: FieldValue.serverTimestamp(),
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
      if (event.exists) tx.update(eventRef, { registered_count: FieldValue.increment(-1) });
    });
    return { ok: true };
  } catch (error) {
    toHttpsError(error);
  }
});

// Next milestones:
//   - onCall "checkIn" (M4): parse and verify the dynamic QR with
//     tickets.verifyTicket, then mark the attendance checked in.
//   - onDocumentUpdated("attendance/{id}"): when is_checked_in flips to true,
//     generate the personalized PDF certificate and email it (M5).
