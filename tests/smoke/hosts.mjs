// Finds the emulators started by `firebase emulators:exec`.
// The test config (firebase.test.json) uses its own ports so tests never
// touch the dev emulators. The hub lists every running emulator.

export async function emulatorHosts() {
  const hub = process.env.FIREBASE_EMULATOR_HUB;
  if (!hub) throw new Error("Run through `npm run test:smoke` (FIREBASE_EMULATOR_HUB is not set).");
  const list = await (await fetch(`http://${hub}/emulators`)).json();
  const host = (name) => {
    const entry = list[name];
    if (!entry) throw new Error(`The ${name} emulator is not running.`);
    return `${entry.host}:${entry.port}`;
  };
  return { auth: host("auth"), firestore: host("firestore"), functions: host("functions") };
}
