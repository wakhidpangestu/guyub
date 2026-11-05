import type { Auth } from "firebase-admin/auth";
import { FieldValue, type Firestore } from "firebase-admin/firestore";

export const ROLES = ["admin", "organizer", "committee", "attendee"] as const;
export type Role = (typeof ROLES)[number];

export interface RoleInput {
  uid: string;
  role: Role;
  orgId?: string;
}

/** Thrown when input is invalid. Callers map it to their own error type. */
export class RoleInputError extends Error {}

/**
 * Validates role input. Organizer and committee must belong to an org.
 * Admin and attendee never carry an orgId, so stale org access cannot leak.
 */
export function validateRoleInput(input: Partial<RoleInput>): RoleInput {
  const { uid, role, orgId } = input;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new RoleInputError("uid is required.");
  }
  if (!ROLES.includes(role as Role)) {
    throw new RoleInputError(`role must be one of: ${ROLES.join(", ")}.`);
  }
  const needsOrg = role === "organizer" || role === "committee";
  if (needsOrg && (typeof orgId !== "string" || orgId.length === 0)) {
    throw new RoleInputError("orgId is required for organizer and committee.");
  }
  return needsOrg ? { uid, role: role as Role, orgId } : { uid, role: role as Role };
}

/**
 * Writes the custom claims and mirrors them to users/{uid}.
 * The `updated_at` write tells signed-in clients to refresh their ID token,
 * so a role change applies without signing out.
 * Auth and Firestore are passed in so scripts and functions share this code.
 */
export async function applyRole(
  deps: { auth: Auth; db: Firestore },
  input: RoleInput,
): Promise<void> {
  if (input.orgId) {
    const org = await deps.db.collection("organizations").doc(input.orgId).get();
    if (!org.exists) {
      throw new RoleInputError(`organization ${input.orgId} does not exist.`);
    }
  }

  const claims: Record<string, string> = { role: input.role };
  if (input.orgId) claims.orgId = input.orgId;

  await deps.auth.setCustomUserClaims(input.uid, claims);
  await deps.db
    .collection("users")
    .doc(input.uid)
    .set(
      {
        role: input.role,
        organization_id: input.orgId ?? null,
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}
