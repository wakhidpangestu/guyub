import { ConflictError, PermissionError, type Actor } from "./members";
import { RoleInputError } from "./claims";

/** The event fields registration depends on. */
export interface EventState {
  status: string;
  registrationOpen: boolean;
  capacity: number | null;
  registeredCount: number;
}

/** Attendance ID is deterministic, so one person cannot register twice. */
export const attendanceIdFor = (eventId: string, uid: string) => `${eventId}_${uid}`;

export function parseRegistrationRequest(data: unknown): { eventId: string } {
  const input = (data ?? {}) as Record<string, unknown>;
  if (typeof input.eventId !== "string" || input.eventId.length === 0) {
    throw new RoleInputError("eventId is required.");
  }
  if (input.privacyConsent !== true) {
    throw new RoleInputError("You must accept the privacy notice to register.");
  }
  return { eventId: input.eventId };
}

/**
 * Decides a registration request.
 * Returns "register" (create the ticket) or "existing" (already registered:
 * the call is idempotent so a double tap or retry is harmless).
 *
 * `event` is null when the event does not exist or the caller may not see it.
 */
export function decideRegistration(caller: Actor, event: EventState | null, alreadyRegistered: boolean): "register" | "existing" {
  if (caller.role !== "attendee") {
    throw new PermissionError("Only attendee accounts can register for events.");
  }
  if (event === null || (event.status !== "active" && !alreadyRegistered)) {
    throw new ConflictError("This event is not open for registration.");
  }
  if (alreadyRegistered) return "existing";
  if (!event.registrationOpen) throw new ConflictError("Registration for this event is closed.");
  if (event.capacity !== null && event.registeredCount >= event.capacity) {
    throw new ConflictError("This event is full.");
  }
  return "register";
}

/** A registration can be cancelled until check-in, while the event is not completed. */
export function decideCancellation(attendance: { isCheckedIn: boolean } | null, eventStatus: string | null): void {
  if (attendance === null) throw new ConflictError("You are not registered for this event.");
  if (attendance.isCheckedIn) throw new ConflictError("You have already checked in, so the registration cannot be cancelled.");
  if (eventStatus === "completed") throw new ConflictError("This event is completed.");
}
