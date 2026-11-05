import { RoleInputError } from "./claims";
import { PermissionError, type Actor } from "./members";
import type { ParsedTicket, TicketCheck } from "./tickets";

/**
 * Outcome of one scan or manual check-in. Returned to the scanner instead of
 * thrown, so the door screen can show it immediately. Errors are reserved
 * for "you may not check in at this event at all" and malformed input.
 */
export type CheckInResult =
  | "checked_in"
  | "already_checked_in"
  | "expired"
  | "invalid"
  | "wrong_event"
  | "not_registered"
  | "closed";

export type CheckInRequest =
  | { eventId: string; mode: "scan"; payload: string }
  | { eventId: string; mode: "manual"; attendanceId: string };

/** Exactly one of `payload` (camera or pasted code) or `attendanceId` (manual). */
export function parseCheckInRequest(data: unknown): CheckInRequest {
  const input = (data ?? {}) as Record<string, unknown>;
  const { eventId, payload, attendanceId } = input;
  if (typeof eventId !== "string" || eventId.length === 0) throw new RoleInputError("eventId is required.");
  const hasPayload = typeof payload === "string" && payload.length > 0;
  const hasAttendance = typeof attendanceId === "string" && attendanceId.length > 0;
  if (hasPayload === hasAttendance) throw new RoleInputError("Send either a scanned code or an attendance ID.");
  if (hasPayload && (payload as string).length > 300) throw new RoleInputError("The scanned code is too long.");
  return hasPayload
    ? { eventId, mode: "scan", payload: payload as string }
    : { eventId, mode: "manual", attendanceId: attendanceId as string };
}

/**
 * Who may check people in at an event:
 * - a committee member assigned to it, by scanning only;
 * - an organizer of the event's organization, by scanning or manually
 *   (for an attendee whose phone died).
 *
 * `eventOrgId` is null when the event does not exist.
 */
export function authorizeCheckIn(caller: Actor, eventOrgId: string | null, isAssigned: boolean, manual: boolean): void {
  if (eventOrgId === null) throw new RoleInputError("This event does not exist.");
  if (caller.role === "organizer" && caller.orgId === eventOrgId) return;
  if (caller.role === "committee" && isAssigned) {
    if (manual) throw new PermissionError("Committee members check people in by scanning their ticket.");
    return;
  }
  throw new PermissionError("You are not assigned to check people in at this event.");
}

/**
 * First look at a scanned code, before any database read: is it a Guyub
 * ticket, and is it for this event? Returns the attendance ID to look up.
 */
export function classifyScan(eventId: string, ticket: ParsedTicket | null): { result: "invalid" | "wrong_event" } | { attendanceId: string } {
  if (ticket === null) return { result: "invalid" };
  if (!ticket.attendanceId.startsWith(`${eventId}_`)) return { result: "wrong_event" };
  return { attendanceId: ticket.attendanceId };
}

/**
 * Final decision, from the state read inside the check-in transaction.
 * Order matters: a closed event or a missing ticket wins over the code check,
 * and a bad or old code is refused even if the person is already in, so a
 * screenshot never looks like a valid ticket.
 */
export function decideCheckIn(
  eventStatus: string,
  attendance: { eventId: string; isCheckedIn: boolean } | null,
  expectedEventId: string,
  check: TicketCheck | "manual",
): CheckInResult {
  if (eventStatus !== "active") return "closed";
  if (attendance === null) return "not_registered";
  if (attendance.eventId !== expectedEventId) return "wrong_event";
  if (check === "invalid" || check === "expired") return check;
  return attendance.isCheckedIn ? "already_checked_in" : "checked_in";
}
