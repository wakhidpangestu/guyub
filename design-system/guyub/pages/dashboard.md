# Role dashboards

Overrides for each role's home page. Everything else follows `../MASTER.md`.

The grid has at most 4 columns, with a target cell width of 240 and never fewer than 2 columns. Rows are 176 to 216 high, scaled with the user's text size. Sizes: `sm` 1×1, `wide` 2×1, `tall` 1×2, `lg` 2×2.

Card IDs are saved in people's browsers. Do not rename one without a reason: a renamed card goes back to its default place.

## Organizer

| ID | Size | Tone | Data |
| --- | --- | --- | --- |
| `hero` | wide | primary | Greeting, New event |
| `upcoming` | sm | cyan | Published events from today on, and the number of drafts |
| `registrations` | sm | pink | Sum of `registered_count` |
| `chart` | lg | plain | Running totals for the next event, from its attendance |
| `next` | wide | green | Next event, countdown, seats |
| `activity` | wide | plain | Latest registrations and check-ins of the next event |
| `events` | lg | plain | The organization's events, soonest first, finished last |
| `rate` | sm | orchid | Checked in as a share of registered, next event |
| `committee` | sm | violet | Committee member count |
| `certificates` | sm | plain | Planned, M5 |
| `sheets` | sm | plain | Planned, M6 |

"Next event" is the soonest published event from midnight WIB today, the same boundary the attendee list uses.

## Committee

| ID | Size | Tone | Data |
| --- | --- | --- | --- |
| `hero` | wide | primary | Greeting, Scan tickets (next event) |
| `assigned` | sm | cyan | Assigned events |
| `today` | sm | pink | Assigned events today |
| `events` | lg | plain | Assigned events, each opens the door screen |
| `door` | wide | green | Check-ins for the next event, live |
| `tips` | wide | violet | Scanning tips |

## Attendee

| ID | Size | Tone | Data |
| --- | --- | --- | --- |
| `hero` | wide | primary | Greeting, Find events |
| `tickets` | sm | cyan | Tickets for upcoming events |
| `upcoming` | sm | pink | Events open for registration now |
| `events` | lg | plain | Upcoming events |
| `ticket` | wide | green | Next ticket, opens the QR |
| `certificates` | sm | plain | Planned, M5 |
| `twibbon` | sm | plain | Planned, M6 |

## Admin

| ID | Size | Tone | Data |
| --- | --- | --- | --- |
| `hero` | wide | primary | Greeting, Manage organizations |
| `organizations` | sm | cyan | Organization count |
| `metrics` | sm | plain | Planned, M6 |
| `list` | lg | plain | Organizations |
| `organizers` | wide | violet | How adding organizers works |
| `retention` | wide | orchid | The 12-month retention rule |

Platform-wide event numbers wait for M6, because the admin dashboard does not read other organizations' events today.
