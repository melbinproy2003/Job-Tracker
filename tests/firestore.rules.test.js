/**
 * Firestore security rules, exercised against the emulator.
 *
 * These assert the policy the app actually depends on: FastAPI is the only
 * write path, clients get owner-scoped reads, and nothing sensitive is reachable
 * from a client at all. A rule that silently permits a write here would let a
 * compromised client bypass every server-side invariant (status history,
 * activity log, token encryption), so the negative cases matter most.
 *
 * Run with:  firebase emulators:exec --only firestore "npm test"
 */
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const fs = require("fs");
const path = require("path");

const OWNER = "user_owner";
const OTHER = "user_other";

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "job-tracker-rules-test",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "..", "firestore.rules"),
        "utf8"
      ),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

/** Requests acting as `uid`; `null` means an unauthenticated client. */
function client(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function anon() {
  return testEnv.unauthenticatedContext().firestore();
}

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe("unauthenticated clients", () => {
  test("cannot read the user profile", async () => {
    await assertFails(anon().collection("users").doc(OWNER).get());
  });

  test("cannot list applications", async () => {
    await assertFails(anon().collection("users").doc(OWNER).collection("applications").get());
  });

  test("cannot write anywhere", async () => {
    await assertFails(
      anon().collection("users").doc(OWNER).collection("applications").doc("a1").set({ status: "offer" })
    );
  });
});

describe("owner reads", () => {
  const readable = [
    "applications",
    "companies",
    "followups",
    "devices",
    "notifications",
    "settings",
  ];

  test.each(readable)("owner can read own %s", async (collection) => {
    const db = client(OWNER);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc(OWNER).collection(collection).doc("d1").set({ ok: true });
    });
    await assertSucceeds(db.collection("users").doc(OWNER).collection(collection).doc("d1").get());
  });

  test("owner can read nested interview and activity subcollections", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const apps = ctx.firestore().collection("users").doc(OWNER).collection("applications").doc("a1");
      await apps.collection("interviews").doc("i1").set({ title: " onsite " });
      await apps.collection("activities").doc("ac1").set({ title: "Applied" });
      await apps.collection("status_history").doc("h1").set({ status: "applied" });
    });
    const apps = client(OWNER).collection("users").doc(OWNER).collection("applications").doc("a1");
    await assertSucceeds(apps.collection("interviews").doc("i1").get());
    await assertSucceeds(apps.collection("activities").doc("ac1").get());
    await assertSucceeds(apps.collection("status_history").doc("h1").get());
  });
});

describe("cross-tenant isolation", () => {
  test("one user cannot read another user's data", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc(OWNER).collection("applications").doc("a1").set({ status: "applied" });
    });
    await assertFails(
      client(OTHER).collection("users").doc(OWNER).collection("applications").doc("a1").get()
    );
  });

  test("one user cannot list another user's notifications", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc(OWNER).collection("notifications").doc("n1").set({ read: false });
    });
    await assertFails(
      client(OTHER).collection("users").doc(OWNER).collection("notifications").get()
    );
  });
});

describe("server-only writes", () => {
  const writeTargets = [
    ["users profile", (db) => db.collection("users").doc(OWNER).set({ display_name: "x" })],
    ["application", (db) => db.collection("users").doc(OWNER).collection("applications").doc("a1").set({ status: "offer" })],
    ["application status update", (db) => db.collection("users").doc(OWNER).collection("applications").doc("a1").update({ status: "offer" })],
    ["application delete", (db) => db.collection("users").doc(OWNER).collection("applications").doc("a1").delete()],
    ["company", (db) => db.collection("users").doc(OWNER).collection("companies").doc("c1").set({ name: "x" })],
    ["followup", (db) => db.collection("users").doc(OWNER).collection("followups").doc("f1").set({ completed: true })],
    ["interview", (db) => db.collection("users").doc(OWNER).collection("applications").doc("a1").collection("interviews").doc("i1").set({ status: "scheduled" })],
    ["activity", (db) => db.collection("users").doc(OWNER).collection("applications").doc("a1").collection("activities").doc("ac1").set({ title: "x" })],
    ["device token", (db) => db.collection("users").doc(OWNER).collection("devices").doc("d1").set({ token: "t" })],
    ["notification read-state", (db) => db.collection("users").doc(OWNER).collection("notifications").doc("n1").update({ read: true })],
    ["notification prefs", (db) => db.collection("users").doc(OWNER).collection("settings").doc("notifications").set({ interview_reminders: false })],
  ];

  test.each(writeTargets)("client cannot write %s", async (_label, act) => {
    await assertFails(act(client(OWNER)));
  });

  test("client cannot forge or mutate the status_history audit trail", async () => {
    const history = client(OWNER)
      .collection("users").doc(OWNER)
      .collection("applications").doc("a1")
      .collection("status_history").doc("h1");

    await assertFails(history.set({ status: "offer" }));
    await assertFails(history.update({ status: "rejected" }));
    await assertFails(history.delete());
  });
});

describe("credential confidentiality", () => {
  const secretCollections = ["gmail_accounts", "gmail_threads", "gmail_messages"];

  test.each(secretCollections)("owner cannot read own %s", async (collection) => {
    await assertFails(
      client(OWNER).collection("users").doc(OWNER).collection(collection).doc("x1").get()
    );
  });

  test.each(secretCollections)("client cannot write %s", async (collection) => {
    await assertFails(
      client(OWNER).collection("users").doc(OWNER).collection(collection).doc("x1").set({ refresh_token: "leak" })
    );
  });

  test("OAuth state is unreachable even from the owner", async () => {
    // Readable state would let a client forge a callback and hijack the flow.
    await assertFails(client(OWNER).collection("_oauth_states").doc("s1").get());
    await assertFails(client(OWNER).collection("_oauth_states").doc("s1").set({ uid: OWNER }));
  });
});

describe("default deny", () => {
  test("unknown top-level collections are denied", async () => {
    await assertFails(client(OWNER).collection("secrets").doc("s1").get());
    await assertFails(client(OWNER).collection("secrets").doc("s1").set({ a: 1 }));
  });
});
