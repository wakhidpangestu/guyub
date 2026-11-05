# STACK 2026 Hackathon Abstract Submission

**Guyub: An All-in-One Operations Platform for Community & Student Event Orchestration**

**Selected Case:** Case 2: Stronger Communities and Everyday Services
**Team Name:** [Team Name]
**Team Members:** [Member 1 Name (Lead), Member 2 Name, Member 3 Name]

---

## Abstract

Managing community and campus organization events presents severe operational bottlenecks. Student associations (Ormawa), local community groups, and small businesses repeatedly face high administrative overhead, budget waste, and time-consuming manual workflows. Key pain points include crafting sponsorship proposals, coordinating volunteer committees, verifying physical attendance, and manually distributing credentials. Campus organizations report that committees spend tens of hours on redundant tasks, sponsors often ignore unstructured outreach, and participants wait too long for their credentials.

We present Guyub, a unified Platform-as-a-Service (PaaS) that streamlines event management into one role-based ecosystem. Guyub provides dedicated workspaces for System Administrators, Event Organizers, On-site Committees, and General Attendees. Organizers create events and use AI-assisted tools to draft sponsorship pitches. Attendees sign in with Google, register for events, and receive a dynamic QR ticket. On event day, committee members assigned to an event scan attendee QR codes to verify check-in in real time. Each verified check-in triggers a Cloud Function that generates a personalized certificate and emails it to the attendee. Attendees can also create an event twibbon: their photo is composited with the event overlay directly in the browser, so the photo is never uploaded to a server.

Guyub uses a hybrid stack. The public landing page is built with Next.js and TypeScript for search visibility and fast loading. Dashboards for all four roles are built with Flutter Web, so one codebase serves every role. Firebase Authentication with Google Sign-In enforces role-based access through custom claims. Cloud Firestore syncs attendance state in real time across scanner devices, and Firebase Storage holds event assets. Google Cloud Functions handle certificate generation and email delivery. Organizers can export registration and attendance data to Google Sheets. Access is scoped by organization and by event, so a committee member cannot scan events they are not assigned to.

Guyub also protects personal data. Registration requires explicit consent to a privacy notice, and personal data is retained for twelve months.

The primary benefit is a drastic reduction in event preparation and wrap-up effort, with less administrative overhead and faster credential delivery. Our one-week sprint delivers a Minimum Viable Product with the organizer dashboard, committee scanner, real-time QR check-in, and automated certificate delivery. Payments and offline check-in are out of scope for this MVP and are planned for later phases.

---

*Source Acknowledgments:* Built using Flutter SDK, Next.js Framework, and Firebase Cloud Engine guidelines (2026).
