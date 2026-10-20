/**
 * Firestore REST API Client
 * Operates as the signed-in user using their Firebase ID Token.
 * Bypasses the need for Firebase Admin SDK and service accounts.
 */

function getFirestoreBaseUrl(projectId) {
  const pid = projectId || process.env.FIREBASE_PROJECT_ID || "pulse-expense-3156f";
  return `https://firestore.googleapis.com/v1/projects/${pid}/databases/(default)/documents`;
}

// =========================================================================
// TYPED VALUE CONVERTERS
// =========================================================================

function toFirestoreValue(val) {
  if (val === null || val === undefined) {
    return { nullValue: null };
  }
  if (typeof val === "boolean") {
    return { booleanValue: val };
  }
  if (typeof val === "number") {
    if (Number.isInteger(val)) {
      return { integerValue: String(val) };
    }
    return { doubleValue: val };
  }
  if (typeof val === "string") {
    return { stringValue: val };
  }
  if (val instanceof Date) {
    return { timestampValue: val.toISOString() };
  }
  if (Array.isArray(val)) {
    return {
      arrayValue: {
        values: val.map(toFirestoreValue),
      },
    };
  }
  if (typeof val === "object") {
    // Check if it's already an explicit Firestore typed object like { doubleValue: 250.0 }
    if (
      val.doubleValue !== undefined ||
      val.integerValue !== undefined ||
      val.stringValue !== undefined ||
      val.booleanValue !== undefined ||
      val.timestampValue !== undefined ||
      val.nullValue !== undefined ||
      val.mapValue !== undefined ||
      val.arrayValue !== undefined
    ) {
      return val;
    }

    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      if (v !== undefined) {
        fields[k] = toFirestoreValue(v);
      }
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj || {})) {
    if (v !== undefined) {
      fields[k] = toFirestoreValue(v);
    }
  }
  return fields;
}

function fromFirestoreValue(val) {
  if (!val || typeof val !== "object") {
    return val;
  }
  if ("stringValue" in val) return val.stringValue;
  if ("integerValue" in val) return parseInt(val.integerValue, 10);
  if ("doubleValue" in val) return Number(val.doubleValue);
  if ("booleanValue" in val) return val.booleanValue;
  if ("timestampValue" in val) return val.timestampValue;
  if ("nullValue" in val) return null;
  if ("arrayValue" in val) {
    return (val.arrayValue.values || []).map(fromFirestoreValue);
  }
  if ("mapValue" in val) {
    return fromFirestoreFields(val.mapValue.fields || {});
  }
  return val;
}

function fromFirestoreFields(fields) {
  const result = {};
  for (const [k, v] of Object.entries(fields || {})) {
    result[k] = fromFirestoreValue(v);
  }
  return result;
}

function parseDocResponse(docJson) {
  if (!docJson || !docJson.name) return null;
  const parts = docJson.name.split("/");
  const id = parts[parts.length - 1];
  const data = fromFirestoreFields(docJson.fields || {});
  data.id = id;
  data._createTime = docJson.createTime;
  data._updateTime = docJson.updateTime;
  return data;
}

// =========================================================================
// FIRESTORE REST OPERATIONS
// =========================================================================

class FirestoreRestClient {
  constructor({ idToken, projectId, fetchFn }) {
    this.idToken = idToken;
    this.projectId = projectId || process.env.FIREBASE_PROJECT_ID || "pulse-expense-3156f";
    this.baseUrl = getFirestoreBaseUrl(this.projectId);
    this.fetch = fetchFn || globalThis.fetch;
  }

  getHeaders() {
    return {
      "Content-Type": "application/json",
      Authorization: `Bearer ${this.idToken}`,
    };
  }

  async _handleResponse(res, pathDescription = "") {
    if (res.status === 403) {
      throw new Error(`Permission denied by security rules for ${pathDescription}`);
    }
    if (res.status === 404) {
      return null;
    }
    if (!res.ok) {
      const errorText = await res.text();
      let message = `Firestore REST error (${res.status})`;
      try {
        const parsed = JSON.parse(errorText);
        if (parsed.error && parsed.error.message) {
          message += `: ${parsed.error.message}`;
        }
      } catch (_) {
        message += `: ${errorText}`;
      }
      throw new Error(message);
    }
    return res.json();
  }

  /**
   * Get a single document by relative path
   * e.g. getDoc('users/foo%40bar_uid/pending_actions/act123')
   */
  async getDoc(docPath) {
    const url = `${this.baseUrl}/${docPath}`;
    const res = await this.fetch(url, {
      method: "GET",
      headers: this.getHeaders(),
    });

    const json = await this._handleResponse(res, docPath);
    if (!json) return null;

    return {
      id: json.name.split("/").pop(),
      fields: fromFirestoreFields(json.fields || {}),
      rawFields: json.fields,
      createTime: json.createTime,
      updateTime: json.updateTime,
    };
  }

  /**
   * Lists a collection with pagination (pageSize 300, capped at 2000 docs)
   */
  async listCollection(collectionPath, options = {}) {
    const pageSize = options.pageSize || 300;
    const maxDocs = options.maxDocs || 2000;
    let pageToken = null;
    const allDocs = [];

    do {
      let url = `${this.baseUrl}/${collectionPath}?pageSize=${pageSize}`;
      if (pageToken) {
        url += `&pageToken=${encodeURIComponent(pageToken)}`;
      }

      const res = await this.fetch(url, {
        method: "GET",
        headers: this.getHeaders(),
      });

      const json = await this._handleResponse(res, collectionPath);
      if (!json || !json.documents) break;

      for (const d of json.documents) {
        allDocs.push(parseDocResponse(d));
        if (allDocs.length >= maxDocs) break;
      }

      pageToken = json.nextPageToken;
    } while (pageToken && allDocs.length < maxDocs);

    return allDocs;
  }

  /**
   * Create or overwrite a document
   */
  async createDoc(parentPath, collectionId, docId, data) {
    let url = `${this.baseUrl}/${parentPath}/${collectionId}`;
    if (docId) {
      url += `?documentId=${encodeURIComponent(docId)}`;
    }

    const fields = toFirestoreFields(data);
    const res = await this.fetch(url, {
      method: "POST",
      headers: this.getHeaders(),
      body: JSON.stringify({ fields }),
    });

    const json = await this._handleResponse(res, `${parentPath}/${collectionId}/${docId || ""}`);
    return parseDocResponse(json);
  }

  docResourceName(docPath) {
    return `projects/${this.projectId}/databases/(default)/documents/${docPath}`;
  }

  /**
   * Executes atomic commit of multiple writes with preconditions
   * writes: Array of write objects
   */
  async commit(writes) {
    const url = `${this.baseUrl}:commit`;
    const res = await this.fetch(url, {
      method: "POST",
      headers: this.getHeaders(),
      body: JSON.stringify({ writes }),
    });

    return this._handleResponse(res, "commit transaction");
  }
}

function getDocResourceName(projectId, docPath) {
  const pid = projectId || process.env.FIREBASE_PROJECT_ID || "pulse-expense-3156f";
  return `projects/${pid}/databases/(default)/documents/${docPath}`;
}

module.exports = {
  getFirestoreBaseUrl,
  getDocResourceName,
  toFirestoreValue,
  toFirestoreFields,
  fromFirestoreValue,
  fromFirestoreFields,
  parseDocResponse,
  FirestoreRestClient,
};
