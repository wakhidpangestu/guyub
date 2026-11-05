import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const ROLES = ["admin", "organizer", "committee", "attendee"] as const;
type Role = (typeof ROLES)[number];

interface SetClaimsInput {
  uid: string;
  role: Role;
  orgId?: string;
}

/**
 * Sets RBAC custom claims on a user. Only an admin may call this.
 * Firestore and Storage rules trust `role` and `orgId` from these claims.
 */
export const setUserClaims = onCall<SetClaimsInput>(async (request) => {
  const caller = request.auth;
  if (!caller || caller.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  const { uid, role, orgId } = request.data;
  if (!uid || !ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", "uid and a valid role are required.");
  }
  if ((role === "organizer" || role === "committee") && !orgId) {
    throw new HttpsError("invalid-argument", "orgId is required for organizer and committee.");
  }

  const claims: Record<string, string> = { role };
  if (orgId) claims.orgId = orgId;

  await getAuth().setCustomUserClaims(uid, claims);
  await getFirestore()
    .collection("users")
    .doc(uid)
    .set({ role, organization_id: orgId ?? null, updated_at: FieldValue.serverTimestamp() }, { merge: true });

  return { ok: true };
});

// Placeholder for the next milestones (kept here so the wiring exists):
//   - onDocumentUpdated("attendance/{id}"): when is_checked_in flips to true,
//     generate the personalized PDF certificate and email it.
//   - onCall "issueQrHash": create qr_hash for each attendance record.
