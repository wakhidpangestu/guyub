import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";

/**
 * Dynamic QR tickets.
 *
 * Each registration gets a random secret `qr_token` (stored on the attendance
 * document, readable by the attendee). The ticket screen shows a QR that
 * changes every WINDOW_SECONDS:
 *
 *   G1.<attendanceId>.<window>.<signature>
 *
 * window    = floor(unix seconds / WINDOW_SECONDS)
 * signature = first 16 hex chars of HMAC-SHA256(key = qr_token, message = "<attendanceId>.<window>")
 *
 * A screenshot shared in a group chat stops working after about one window.
 * The Flutter app computes the same value (lib/data/ticket_code.dart); both
 * sides are tested against the same vector.
 */
export const WINDOW_SECONDS = 30;

/** Windows accepted on each side of "now", to allow for clock drift and scan delay. */
export const WINDOW_TOLERANCE = 2;

const PREFIX = "G1";

export function newQrToken(): string {
  return randomBytes(16).toString("base64url");
}

export function windowAt(unixSeconds: number): number {
  return Math.floor(unixSeconds / WINDOW_SECONDS);
}

export function ticketSignature(qrToken: string, attendanceId: string, window: number): string {
  return createHmac("sha256", qrToken).update(`${attendanceId}.${window}`).digest("hex").slice(0, 16);
}

export function ticketPayload(qrToken: string, attendanceId: string, window: number): string {
  return `${PREFIX}.${attendanceId}.${window}.${ticketSignature(qrToken, attendanceId, window)}`;
}

export interface ParsedTicket {
  attendanceId: string;
  window: number;
  signature: string;
}

/** Splits from the right, so an attendance ID containing dots still parses. */
export function parseTicketPayload(payload: string): ParsedTicket | null {
  if (typeof payload !== "string" || !payload.startsWith(`${PREFIX}.`)) return null;
  const rest = payload.slice(PREFIX.length + 1);
  const sigDot = rest.lastIndexOf(".");
  const windowDot = rest.lastIndexOf(".", sigDot - 1);
  if (sigDot < 0 || windowDot <= 0) return null;
  const attendanceId = rest.slice(0, windowDot);
  const window = Number(rest.slice(windowDot + 1, sigDot));
  const signature = rest.slice(sigDot + 1);
  if (!Number.isInteger(window) || !/^[0-9a-f]{16}$/.test(signature)) return null;
  return { attendanceId, window, signature };
}

export type TicketCheck = "valid" | "expired" | "invalid";

/**
 * Checks a scanned ticket against the stored token. Used by check-in (M4).
 * "expired" means the signature was right for its window, but the window is
 * too old or too far ahead: usually a screenshot.
 */
export function verifyTicket(ticket: ParsedTicket, qrToken: string, nowUnixSeconds: number): TicketCheck {
  const expected = Buffer.from(ticketSignature(qrToken, ticket.attendanceId, ticket.window));
  const actual = Buffer.from(ticket.signature);
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return "invalid";
  return Math.abs(windowAt(nowUnixSeconds) - ticket.window) <= WINDOW_TOLERANCE ? "valid" : "expired";
}
