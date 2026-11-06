# STACK 2026 Hackathon Abstract Submission

**Guyub: An All-in-One Operations Platform for Community & Student Event Orchestration**

**Selected Case:** Case 2: Stronger Communities and Everyday Services
**Team Name:** Lah  
**Team Members:** [Wakhid Pangestu (Lead), Rendy Setiawan, Ahmad Dandi Subhani, Rafi Budiansyah]

---

## Abstract

Managing community and campus organization events presents severe operational bottlenecks. Student associations (Ormawa), local community groups, and small businesses repeatedly encounter high administrative overhead, budget waste, and time-consuming manual workflows. Key pain points include crafting sponsorship proposals, coordinating volunteer committees, verifying physical attendance, and manually distributing credentials. Observations from campus organizations show that committees waste tens of hours on redundant tasks, while sponsors frequently ignore unstructured outreach and participants experience significant delays receiving credentials.

To solve these operational friction points, we present Guyub, a unified Platform-as-a-Service (PaaS) engineered to streamline event management into an intuitive ecosystem. Guyub introduces a multi-role architecture featuring dedicated workspaces for System Administrators, Event Organizers, On-site Committees, and General Attendees. The core workflow begins with organizers setting up event parameters and utilizing AI-driven assistance to draft tailored sponsorship pitches. During registration, attendees receive dynamic QR credentials. On event day, committee members verify check-ins in real time through an optimized QR scanner interface. Immediately upon verified check-in, an automated Cloud Function triggers personalized certificate generation and instant email delivery, eliminating post-event backlogs.

Guyub utilizes a specialized hybrid tech stack. The public-facing presentation layer employs Next.js with TypeScript for a high-performance, visually engaging landing page. Role-specific dashboards (Organizer, Committee Scanner, Attendee Portal) are powered by Flutter Web for unified, cross-platform state synchronization. Backend infrastructure leverages Firebase Authentication for secure role enforcement and Cloud Firestore for real-time data sync. Automated tasks, including certificate compilation and email notifications, run on Google Cloud Functions.

The primary benefit of Guyub is a drastic reduction in event preparation and wrap-up effort, cutting administrative overhead while improving participant satisfaction. Our one-week development roadmap delivers a functional Minimum Viable Product (MVP) containing core organizer and committee dashboards, real-time QR attendance verification, and automated post-event credential delivery.

---

## Technical Architecture Mapping

| Layer | Technology Selected | Operational Role |
|---|---|---|
| Landing Page | Next.js + TypeScript | High-performance marketing, SEO, & interactive onboarding showcase |
| Dashboards | Flutter Web | Unified cross-platform workspaces (Organizer, Committee, Attendee) |
| Backend & Data | Firebase Auth & Cloud Firestore | Role-based access control & real-time attendance state sync |
| Automations | Google Cloud Functions | Trigger-based automated certificate generation & instant email delivery |

*Source Acknowledgments:* Built using Flutter SDK, Next.js Framework, and Firebase Cloud Engine guidelines (2026).

*Excluded from abstract word count (abstract core text: ~375 words).*
