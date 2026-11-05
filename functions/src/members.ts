import { RoleInputError, type Role } from "./claims";

/** Caller is not allowed to do this at all. Maps to permission-denied. */
export class PermissionError extends Error {}

/** Request is allowed in general but conflicts with the target's state. Maps to failed-precondition. */
export class ConflictError extends Error {}

export interface Actor {
  role: Role;
  orgId?: string;
}

export interface InviteRequest {
  email: string;
  role: Role;
  orgId: string;
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Lowercase and trim, so one person has one invite and one lookup key. */
export function normalizeEmail(value: unknown): string {
  if (typeof value !== "string") throw new RoleInputError("email is required.");
  const email = value.trim().toLowerCase();
  if (!EMAIL.test(email)) throw new RoleInputError("email is not valid.");
  return email;
}

/** Validates the shape of an invite request. Who may send it is checked in decideInvite. */
export function parseInviteRequest(data: unknown): InviteRequest {
  const input = (data ?? {}) as Record<string, unknown>;
  const email = normalizeEmail(input.email);
  const role = input.role;
  const orgId = input.orgId;
  if (role !== "organizer" && role !== "committee") {
    throw new RoleInputError("role must be organizer or committee.");
  }
  if (typeof orgId !== "string" || orgId.length === 0) {
    throw new RoleInputError("orgId is required.");
  }
  return { email, role, orgId };
}

/**
 * Decides what an invite does.
 *
 * - Admin may make anyone an organizer or committee member of any org.
 * - Organizer may only add committee members to their own org.
 * - Nobody changes an admin through this path.
 * - A member of another org must be removed there first, so one org never
 *   silently takes a person away from another.
 * - An organizer cannot demote a fellow organizer.
 *
 * `target` is null when no account exists yet for the email.
 * Returns "grant" (apply now) or "invite" (apply at first sign-in).
 */
export function decideInvite(caller: Actor, request: InviteRequest, target: Actor | null): "grant" | "invite" {
  if (caller.role === "admin") {
    // Any org, organizer or committee.
  } else if (caller.role === "organizer") {
    if (request.role !== "committee") throw new PermissionError("Organizers can only add committee members.");
    if (request.orgId !== caller.orgId) throw new PermissionError("You can only add members to your own organization.");
  } else {
    throw new PermissionError("Only admins and organizers can add members.");
  }

  if (target === null) return "invite";

  if (target.role === "admin") throw new ConflictError("This account is an admin and cannot be changed here.");
  if (target.orgId && target.orgId !== request.orgId) {
    throw new ConflictError("This account belongs to another organization. It must be removed there first.");
  }
  if (caller.role === "organizer" && target.role === "organizer") {
    throw new ConflictError("This account is an organizer. Only an admin can change it.");
  }
  return "grant";
}

/**
 * Decides whether `caller` may remove `target` from their organization.
 * Removing returns the person to the attendee role.
 */
export function decideRemove(caller: Actor, target: Actor): void {
  if (target.role === "admin") throw new ConflictError("Admins cannot be removed here.");
  if (target.role === "attendee") throw new ConflictError("This account is not a member of any organization.");

  if (caller.role === "admin") return;
  if (caller.role === "organizer" && target.role === "committee" && target.orgId === caller.orgId) return;
  throw new PermissionError("You can only remove committee members of your own organization.");
}
