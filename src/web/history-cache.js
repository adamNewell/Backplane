// The browser's copy of the hub log. Store batches in IndexedDB so an
// update copies only new events, and never serializes the whole history.
export class HistoryCache {
  constructor(storage = globalThis.indexedDB, timeoutMs = 3000) {
    this.timeoutMs = timeoutMs;
    this.origin = null;
    this.seq = 0;
    this.pending = Promise.resolve();
    this.db = new Promise((resolve) => {
      if (!storage) { resolve(null); return; }
      let settled = false;
      const finish = (db) => {
        if (settled) { db?.close(); return; }
        settled = true;
        clearTimeout(timer);
        resolve(db);
      };
      // A blocked or stalled database must not prevent a live connection.
      const timer = setTimeout(() => finish(null), this.timeoutMs);
      try {
        const request = storage.open("backplane-history", 1);
        request.onupgradeneeded = () => {
          request.result.createObjectStore("meta");
          request.result.createObjectStore("batches");
        };
        request.onsuccess = () => {
          const db = request.result;
          db.onversionchange = () => db.close();
          finish(db);
        };
        request.onerror = request.onblocked = () => finish(null);
      } catch { finish(null); }
    });
  }

  // Abort a stalled transaction and settle once. Late callbacks must not
  // adopt a history after the live connection has started without it.
  deadline(tx, resolve, fallback) {
    let settled = false;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(value);
    };
    const timer = setTimeout(() => {
      finish(fallback);
      try { tx.abort(); } catch {}
    }, this.timeoutMs);
    finish.expired = () => settled;
    return finish;
  }

  async load() {
    const db = await this.db;
    if (!db) return null;
    return new Promise((resolve) => {
      let finish;
      try {
        const tx = db.transaction(["meta", "batches"], "readonly");
        finish = this.deadline(tx, resolve, null);
        const meta = tx.objectStore("meta").get("head");
        const batches = tx.objectStore("batches").getAll();
        tx.onabort = tx.onerror = () => finish(null);
        tx.oncomplete = () => {
          if (finish.expired()) return;
          const head = meta.result;
          if (!head || typeof head.origin !== "string") { finish(null); return; }
          const items = [];
          for (const batch of batches.result) {
            if (batch.since !== items.length || !Array.isArray(batch.items)) { finish(null); return; }
            for (const item of batch.items) items.push(item);
          }
          if (items.length !== head.seq) { finish(null); return; }
          this.origin = head.origin;
          this.seq = head.seq;
          finish({ t: "log", since: 0, origin: head.origin, items });
        };
      } catch { if (finish) finish(null); else resolve(null); }
    });
  }

  keep(msg) {
    if (!Array.isArray(msg?.items)) return;
    let reset = false;
    let since = this.seq;
    if (msg.t === "log") {
      since = msg.since ?? 0;
      reset = since === 0;
      if (!reset && (msg.origin !== this.origin || since !== this.seq)) return;
      this.origin = msg.origin ?? "";
    } else if (msg.t !== "changes" || this.origin === null) {
      return;
    }
    const origin = this.origin;
    const items = msg.items;
    const seq = since + items.length;
    this.seq = seq;
    // Serialize transactions, not histories. An aborted write leaves a
    // valid shorter prefix; the hub supplies the missing events on reload.
    this.pending = this.pending.then(() => this.write(origin, since, seq, items, reset)).catch(() => {});
  }

  async write(origin, since, seq, items, reset) {
    const db = await this.db;
    if (!db) return;
    return new Promise((resolve) => {
      let finish;
      try {
        const tx = db.transaction(["meta", "batches"], "readwrite");
        finish = this.deadline(tx, resolve);
        tx.oncomplete = tx.onabort = tx.onerror = () => finish();
        const meta = tx.objectStore("meta");
        const batches = tx.objectStore("batches");
        const head = meta.get("head");
        head.onsuccess = () => {
          if (finish.expired()) return;
          // Another tab may already have saved this range. Never append
          // across a gap or combine two hub histories.
          if (!reset && (head.result?.origin !== origin || head.result?.seq !== since)) return;
          if (reset) batches.clear();
          for (let i = 0; i < items.length; i += 256) {
            batches.put({ since: since + i, items: items.slice(i, i + 256) }, since + i);
          }
          meta.put({ origin, seq }, "head");
        };
      } catch { if (finish) finish(); else resolve(); }
    });
  }
}
