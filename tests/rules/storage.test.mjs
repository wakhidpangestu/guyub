import { after, before, beforeEach, describe, it } from "node:test";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { getMetadata, ref, uploadBytes } from "firebase/storage";

import { as, createEnv, seed } from "./helpers.mjs";

let env;
const storage = (persona) => persona(env).storage();
const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
const pdf = new Uint8Array([0x25, 0x50, 0x44, 0x46]);

before(async () => {
  env = await createEnv();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  // Storage rules look up event ownership in Firestore.
  await seed(env);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), "events/evtA/banner.png"), png, { contentType: "image/png" });
    await uploadBytes(ref(ctx.storage(), "certificates/evtA/att1.pdf"), pdf, { contentType: "application/pdf" });
  });
});

after(async () => {
  await env.cleanup();
});

describe("event assets", () => {
  it("organizer uploads to own org's event", async () => {
    await assertSucceeds(
      uploadBytes(ref(storage(as.organizer), "events/evtA/twibbon-overlay.png"), png, { contentType: "image/png" }),
    );
  });

  it("organizer of another org cannot upload", async () => {
    await assertFails(
      uploadBytes(ref(storage(as.otherOrganizer), "events/evtA/banner.png"), png, { contentType: "image/png" }),
    );
  });

  it("attendee cannot upload", async () => {
    await assertFails(uploadBytes(ref(storage(as.attendee), "events/evtA/banner.png"), png, { contentType: "image/png" }));
  });

  it("rejects non-image, non-PDF files", async () => {
    await assertFails(
      uploadBytes(ref(storage(as.organizer), "events/evtA/notes.txt"), png, { contentType: "text/plain" }),
    );
  });

  it("anyone can read event banners", async () => {
    await assertSucceeds(getMetadata(ref(storage(as.anonymous), "events/evtA/banner.png")));
  });
});

describe("certificates", () => {
  it("owner reads own certificate", async () => {
    await assertSucceeds(getMetadata(ref(storage(as.attendee), "certificates/evtA/att1.pdf")));
  });

  it("other users cannot read it", async () => {
    await assertFails(getMetadata(ref(storage(as.otherAttendee), "certificates/evtA/att1.pdf")));
    await assertFails(getMetadata(ref(storage(as.organizer), "certificates/evtA/att1.pdf")));
  });

  it("nobody writes certificates from the client", async () => {
    await assertFails(
      uploadBytes(ref(storage(as.attendee), "certificates/evtA/att1.pdf"), pdf, { contentType: "application/pdf" }),
    );
  });
});
