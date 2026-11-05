import { Timestamp, type Firestore } from "firebase-admin/firestore";

/**
 * Promised in the registration privacy notice: attendance records are kept
 * for 12 months after the event, then deleted (SPEC §0 decision 6, audit H3).
 */
export const RETENTION_DAYS = 365;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Events dated before this moment have passed the retention period. */
export function retentionCutoff(now: Date): Date {
  return new Date(now.getTime() - RETENTION_DAYS * DAY_MS);
}

export interface PurgeResult {
  /** Events past retention that were checked. */
  events: number;
  /** Attendance records deleted (each with its ticket secret). */
  deleted: number;
}

/**
 * Deletes attendance records and ticket secrets of events older than the
 * retention period. Events stay: they hold no attendee data, and organizers
 * keep their history. Safe to run repeatedly.
 *
 * Each batch deletes `pageSize` records and their secrets, so it stays under
 * Firestore's 500-writes-per-batch limit.
 */
export async function purgeExpiredAttendance(db: Firestore, now: Date, pageSize = 200): Promise<PurgeResult> {
  const cutoff = Timestamp.fromDate(retentionCutoff(now));
  const events = await db.collection("events").where("date", "<", cutoff).get();
  let deleted = 0;

  for (const event of events.docs) {
    for (;;) {
      const page = await db.collection("attendance").where("event_id", "==", event.id).limit(pageSize).get();
      if (page.empty) break;
      const batch = db.batch();
      for (const doc of page.docs) {
        batch.delete(doc.ref);
        batch.delete(db.collection("attendance_secrets").doc(doc.id));
      }
      await batch.commit();
      deleted += page.size;
    }
  }

  return { events: events.size, deleted };
}
