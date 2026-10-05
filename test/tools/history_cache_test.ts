// npm install --prefix test/tools && bun test test/tools/history_cache_test.ts
import { describe, expect, test } from "bun:test";
import { IDBFactory } from "fake-indexeddb";
import { HistoryCache } from "../../src/web/history-cache.js";

const log = (items: unknown[], origin = "hub-a", since = 0) => ({ t: "log", origin, since, items });
const changes = (items: unknown[]) => ({ t: "changes", items });
const restore = async (storage: IDBFactory) => new HistoryCache(storage).load();

describe("browser history cache", () => {
  test("rebuilds a version-1 cache instead of restoring rounded numbers", async () => {
    const storage = new IDBFactory();
    const old = await new Promise<IDBDatabase>((resolve) => {
      const request = storage.open("backplane-history", 1);
      request.onupgradeneeded = () => {
        request.result.createObjectStore("meta");
        request.result.createObjectStore("batches");
      };
      request.onsuccess = () => resolve(request.result);
    });
    const tx = old.transaction(["meta", "batches"], "readwrite");
    tx.objectStore("meta").put({ origin: "hub", seq: 1 }, "head");
    tx.objectStore("batches").put({ since: 0, items: [{ number: 9007199254740992 }] }, 0);
    await new Promise<void>((resolve) => { tx.oncomplete = () => resolve(); });
    old.close();
    const current = new HistoryCache(storage);
    expect(await current.load()).toBeNull();
    expect(current.origin).toBeNull();
    expect(current.seq).toBe(0);
    current.keep(log([{ number: 42 }]));
    await current.pending;
    expect(await restore(storage)).toEqual(log([{ number: 42 }]));
  });

  test("restores a history larger than localStorage and appends only new events", async () => {
    const storage = new IDBFactory();
    const cache = new HistoryCache(storage);
    expect(await cache.load()).toBeNull();
    const items = Array.from({ length: 23000 }, (_, id) => ({ id, text: "x".repeat(840) }));
    cache.keep(log(items));
    await cache.pending;
    const db = await cache.db;
    const tx = db!.transaction("batches", "readonly");
    const rows = tx.objectStore("batches").getAll();
    const before = await new Promise<any[]>((resolve) => { rows.onsuccess = () => resolve(rows.result); });
    expect(before.length).toBe(Math.ceil(items.length / 256));
    cache.keep(changes([{ id: 23000, text: "new" }]));
    await cache.pending;
    const saved = await restore(storage);
    expect(saved?.items).toEqual([...items, { id: 23000, text: "new" }]);
    const tx2 = db!.transaction("batches", "readonly");
    const first = tx2.objectStore("batches").get(0);
    expect(await new Promise((resolve) => { first.onsuccess = () => resolve(first.result); })).toEqual(before[0]);
  });

  test("reconnect appends missing events; a new origin replaces the old log", async () => {
    const storage = new IDBFactory();
    const cache = new HistoryCache(storage);
    cache.keep(log([1, 2]));
    cache.keep(log([3], "hub-a", 2));
    cache.keep(changes([4]));
    await cache.pending;
    expect((await restore(storage))?.items).toEqual([1, 2, 3, 4]);
    cache.keep(log([5], "hub-b"));
    cache.keep(changes([6]));
    await cache.pending;
    expect(await restore(storage)).toEqual(log([5, 6], "hub-b"));
  });

  test("ignores history gaps and incremental messages from another origin", async () => {
    const storage = new IDBFactory();
    const cache = new HistoryCache(storage);
    cache.keep(log([1]));
    cache.keep(log([9], "hub-a", 3));
    cache.keep(log([9], "hub-b", 1));
    cache.keep(changes([2]));
    await cache.pending;
    expect((await restore(storage))?.items).toEqual([1, 2]);
  });

  test("two tabs do not duplicate events or combine different histories", async () => {
    const storage = new IDBFactory();
    const a = new HistoryCache(storage);
    a.keep(log([1]));
    await a.pending;
    const b = new HistoryCache(storage);
    await b.load();
    a.keep(changes([2]));
    await a.pending;
    b.keep(changes([2]));
    await b.pending;
    b.keep(log([7], "hub-b"));
    await b.pending;
    a.keep(changes([3]));
    await a.pending;
    expect(await restore(storage)).toEqual(log([7], "hub-b"));
  });

  test("an aborted write keeps a complete prefix for the next reconnect", async () => {
    const storage = new IDBFactory();
    const cache = new HistoryCache(storage);
    cache.keep(log([1]));
    await cache.pending;
    const db = await cache.db;
    const transaction = db!.transaction.bind(db);
    db!.transaction = (...args: any[]) => {
      const tx = transaction(...args);
      queueMicrotask(() => tx.abort());
      return tx;
    };
    cache.keep(changes([2]));
    await cache.pending;
    db!.transaction = transaction;
    const next = new HistoryCache(storage);
    expect((await next.load())?.items).toEqual([1]);
    next.keep(log([2, 3], "hub-a", 1));
    await next.pending;
    expect((await restore(storage))?.items).toEqual([1, 2, 3]);
  });

  test("unavailable storage does not stop live updates", async () => {
    const cache = new HistoryCache({ open() { throw new Error("storage denied"); } });
    expect(await cache.load()).toBeNull();
    cache.keep(log([1]));
    cache.keep(changes([2]));
    await cache.pending;
    expect(cache.seq).toBe(2);
  });
});

function stalledTransaction() {
  const requests = [{ result: { origin: "late", seq: 1 } }, { result: [{ since: 0, items: [1] }] }];
  const tx: any = {
    aborted: false,
    objectStore(name: string) {
      return name === "meta"
        ? { get: () => requests[0], put() {} }
        : { getAll: () => requests[1], clear() {}, put() {} };
    },
    abort() { this.aborted = true; },
  };
  return tx;
}

test("a stalled cache read expires; late completion cannot replace live history", async () => {
  const tx = stalledTransaction();
  const cache = new HistoryCache(undefined, 20);
  cache.db = Promise.resolve({ transaction: () => tx });
  expect(await cache.load()).toBeNull();
  expect(tx.aborted).toBe(true);
  cache.keep(log([9], "live"));
  tx.oncomplete();
  expect(cache.origin).toBe("live");
  expect(cache.seq).toBe(1);
  await cache.pending;
});

test("a stalled write expires and releases the next queued write", async () => {
  const stalled = stalledTransaction();
  const storage = new IDBFactory();
  const cache = new HistoryCache(storage, 20);
  const db = await cache.db;
  const transaction = db!.transaction.bind(db);
  let first = true;
  db!.transaction = (...args: any[]) => {
    if (first) { first = false; return stalled; }
    return transaction(...args);
  };
  cache.keep(log([1]));
  cache.keep(log([2], "hub-b"));
  await cache.pending;
  expect(stalled.aborted).toBe(true);
  expect(await restore(storage)).toEqual(log([2], "hub-b"));
});
