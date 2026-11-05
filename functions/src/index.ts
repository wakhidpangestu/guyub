import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as functionsV1 from "firebase-functions/v1";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { applyRole, RoleInputError, validateRoleInput, type RoleInput } from "./claims";
import { REGION } from "./config";

initializeApp();

// Jakarta region: closest to Indonesian users. The Flutter client uses the same value.
setGlobalOptions({ region: REGION, maxInstances: 10 });

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
    if (error instanceof RoleInputError) {
      throw new HttpsError("invalid-argument", error.message);
    }
    throw error;
  }
});

/**
 * Creates the users/{uid} profile on first sign-in.
 * New users have no role claim, which every client and rule treats as "attendee".
 * `create()` never overwrites, so a role set by an admin is never reset.
 */
export const onUserCreated = functionsV1
  .region(REGION)
  .auth.user()
  .onCreate(async (user) => {
    try {
      await getFirestore().collection("users").doc(user.uid).create({
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
  });

// Next milestones:
//   - onDocumentUpdated("attendance/{id}"): when is_checked_in flips to true,
//     generate the personalized PDF certificate and email it (M5).
//   - onCall "issueQrHash": create qr_hash for each attendance record (M3).
