const { describe, it } = require("node:test");
const assert = require("node:assert");
const {
  toFirestoreValue,
  fromFirestoreValue,
  toFirestoreFields,
  fromFirestoreFields,
  FirestoreRestClient,
} = require("../lib/db");

describe("Firestore REST Client & Converters", () => {
  it("converts primitive types to and from Firestore REST representations", () => {
    // String
    const strVal = toFirestoreValue("hello");
    assert.deepStrictEqual(strVal, { stringValue: "hello" });
    assert.strictEqual(fromFirestoreValue(strVal), "hello");

    // Integer
    const intVal = toFirestoreValue(42);
    assert.deepStrictEqual(intVal, { integerValue: "42" });
    assert.strictEqual(fromFirestoreValue(intVal), 42);

    // Double
    const doubleVal = toFirestoreValue(250.75);
    assert.deepStrictEqual(doubleVal, { doubleValue: 250.75 });
    assert.strictEqual(fromFirestoreValue(doubleVal), 250.75);

    // Explicit double value (e.g. 250.0)
    const explicitDouble = { doubleValue: 250.0 };
    assert.deepStrictEqual(toFirestoreValue(explicitDouble), { doubleValue: 250.0 });
    assert.strictEqual(fromFirestoreValue(explicitDouble), 250.0);

    // Boolean
    const boolVal = toFirestoreValue(true);
    assert.deepStrictEqual(boolVal, { booleanValue: true });
    assert.strictEqual(fromFirestoreValue(boolVal), true);

    // Null
    const nullVal = toFirestoreValue(null);
    assert.deepStrictEqual(nullVal, { nullValue: null });
    assert.strictEqual(fromFirestoreValue(nullVal), null);

    // Timestamp from Date
    const now = new Date("2026-10-20T08:00:00.000Z");
    const tsVal = toFirestoreValue(now);
    assert.deepStrictEqual(tsVal, { timestampValue: "2026-10-20T08:00:00.000Z" });
    assert.strictEqual(fromFirestoreValue(tsVal), "2026-10-20T08:00:00.000Z");

    // Array / List
    const arrVal = toFirestoreValue(["apple", 100, true]);
    assert.deepStrictEqual(arrVal, {
      arrayValue: {
        values: [
          { stringValue: "apple" },
          { integerValue: "100" },
          { booleanValue: true },
        ],
      },
    });
    assert.deepStrictEqual(fromFirestoreValue(arrVal), ["apple", 100, true]);

    // Nested Map
    const nested = {
      user: {
        name: "Alice",
        age: 30,
        settings: { notifications: true },
      },
    };
    const mapVal = toFirestoreValue(nested);
    assert.deepStrictEqual(mapVal, {
      mapValue: {
        fields: {
          user: {
            mapValue: {
              fields: {
                name: { stringValue: "Alice" },
                age: { integerValue: "30" },
                settings: {
                  mapValue: {
                    fields: {
                      notifications: { booleanValue: true },
                    },
                  },
                },
              },
            },
          },
        },
      },
    });
    assert.deepStrictEqual(fromFirestoreValue(mapVal), nested);
  });

  it("getDoc sends Authorization header and encodes '@' in document path", async () => {
    let capturedUrl = "";
    let capturedHeaders = {};

    const mockFetch = async (url, options) => {
      capturedUrl = url;
      capturedHeaders = options.headers;
      return {
        ok: true,
        status: 200,
        json: async () => ({
          name: "projects/test-proj/databases/(default)/documents/users/alice%40example.com_123/pending_actions/act_1",
          fields: {
            status: { stringValue: "PENDING" },
          },
          updateTime: "2026-10-20T08:00:00.000Z",
        }),
      };
    };

    const client = new FirestoreRestClient({
      idToken: "mock_test_token",
      projectId: "test-proj",
      fetchFn: mockFetch,
    });

    const docPath = `users/${encodeURIComponent("alice@example.com_123")}/pending_actions/act_1`;
    const doc = await client.getDoc(docPath);

    assert.strictEqual(capturedHeaders["Authorization"], "Bearer mock_test_token");
    assert.match(capturedUrl, /users\/alice%40example\.com_123\/pending_actions\/act_1/);
    assert.strictEqual(doc.id, "act_1");
    assert.strictEqual(doc.fields.status, "PENDING");
    assert.strictEqual(doc.updateTime, "2026-10-20T08:00:00.000Z");
  });

  it("listCollection paginates and follows nextPageToken", async () => {
    let callCount = 0;

    const mockFetch = async (url) => {
      callCount++;
      if (callCount === 1) {
        assert.match(url, /pageSize=300/);
        return {
          ok: true,
          status: 200,
          json: async () => ({
            documents: [
              {
                name: "projects/p/databases/(default)/documents/users/u/income_expenses/tx_1",
                fields: { amount: { doubleValue: 100.0 }, date: { stringValue: "2026-10-01" } },
              },
            ],
            nextPageToken: "page_2_token",
          }),
        };
      } else {
        assert.match(url, /pageToken=page_2_token/);
        return {
          ok: true,
          status: 200,
          json: async () => ({
            documents: [
              {
                name: "projects/p/databases/(default)/documents/users/u/income_expenses/tx_2",
                fields: { amount: { doubleValue: 200.0 }, date: { stringValue: "2026-10-02" } },
              },
            ],
          }),
        };
      }
    };

    const client = new FirestoreRestClient({
      idToken: "token",
      projectId: "p",
      fetchFn: mockFetch,
    });

    const docs = await client.listCollection("users/u/income_expenses");
    assert.strictEqual(callCount, 2);
    assert.strictEqual(docs.length, 2);
    assert.strictEqual(docs[0].id, "tx_1");
    assert.strictEqual(docs[1].id, "tx_2");
  });

  it("commit sends atomic writes with preconditions", async () => {
    let capturedBody = null;

    const mockFetch = async (url, options) => {
      capturedBody = JSON.parse(options.body);
      return {
        ok: true,
        status: 200,
        json: async () => ({
          writeResults: [{ updateTime: "2026-10-20T08:01:00.000Z" }],
        }),
      };
    };

    const client = new FirestoreRestClient({
      idToken: "token",
      projectId: "test-proj",
      fetchFn: mockFetch,
    });

    const writes = [
      {
        update: {
          name: client.docResourceName("users/u/pending_actions/act_1"),
          fields: { status: { stringValue: "CONFIRMED" } },
        },
        currentDocument: { updateTime: "2026-10-20T08:00:00.000Z" },
      },
    ];

    await client.commit(writes);

    assert.strictEqual(capturedBody.writes.length, 1);
    assert.deepStrictEqual(capturedBody.writes[0].currentDocument, {
      updateTime: "2026-10-20T08:00:00.000Z",
    });
  });
});
