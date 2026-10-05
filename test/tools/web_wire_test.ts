// sh test/tools/web_wire_test.sh
import { expect, test } from "bun:test";
import { readFileSync, readdirSync } from "node:fs";
import { wireDecoder } from "../../src/web/wire.js";
import { toJson } from "../../src/web/json.js";
import { HistoryCache } from "../../src/web/history-cache.js";
import { IDBFactory } from "fake-indexeddb";

const entry = readFileSync("build/web-wire-test/wire.html", "utf8").match(/src="\.\/([^"]+\.js)"/)![1];
new Function(readFileSync(`build/web-wire-test/${entry}`, "utf8"))();
export const W = (globalThis as any).BackplaneWireTest;
export function list(xs: any): any[] {
  const out = [];
  for (; xs.$ === "Con"; xs = xs.tail) out.push(xs.head);
  return out;
}
export function bendList(bytes: Uint8Array) {
  let xs: any = {$: "Nil"};
  for (let i = bytes.length - 1; i >= 0; i--) xs = {$: "Con", head: bytes[i], tail: xs};
  return xs;
}
export const decode = wireDecoder(list(W.keys()), list(W.words()), W.rules(), W.key_text);

test("wire values match the Bend codec, including all dictionary entries", () => {
  const obj = Object.fromEntries(list(W.keys()).map((k, i) => [k, list(W.words())[i]]));
  const cases = [obj, list(W.words()), null, true, false, 0, -1, 24, 255, 256, 65535,
    65536, 4294967295, -4294967296, 1.25, 1e50, "µ 日本語 😀", "\uFEFFhello", "x".repeat(70000),
    {__proto__: null, nested: [{items: [true, null, "assistant"]}], constructor: "safe"}];
  for (const value of cases) {
    const bytes = Uint8Array.from(list(W.encode(JSON.stringify(value))));
    const result = decode(bytes);
    expect(W.show(result.json)).toBe(W.show(W.decode(bendList(bytes))));
    expect(result.value).toEqual(value);
  }
});

test("number text stays exact in Bend and object keys cannot alter prototypes", () => {
  const text = '{"__proto__":{"polluted":true},"number":9007199254740993,"decimal":1.2300}';
  const bytes = Uint8Array.from(list(W.encode(text)));
  const result = decode(bytes);
  expect(W.show(result.json)).toBe(W.show(W.decode(bendList(bytes))));
  expect(Object.hasOwn(result.value, "__proto__")).toBe(true);
  expect(({} as any).polluted).toBeUndefined();
  expect(W.show(toJson(result.value, result.numberText))).toBe(W.show(result.json));
});

test("cache restoration preserves exact number text across batches and deltas without marker collisions", async () => {
  const storage = new IDBFactory();
  const cache = new HistoryCache(storage);
  const rows = Array.from({ length: 258 }, (_, i) => i === 0 || i === 256
    ? '{"large":9007199254740993,"decimal":1.2300,"nested":[-0,1e100],"literal":{"$num":"1.2300"},"__proto__":{"value":2.000}}'
    : '{"ordinary":42}');
  const read = (text: string) => decode(Uint8Array.from(list(W.encode(text))));
  const initial = read('{"t":"log","origin":"hub","since":0,"items":[' + rows.join(',') + ']}');
  cache.keep(initial.value, initial.numberText);
  await cache.pending;
  const delta = read('{"t":"changes","items":[{"decimal":3.1400}]}');
  cache.keep(delta.value, delta.numberText);
  await cache.pending;
  const saved = await new HistoryCache(storage).load();
  const expected = read('[' + rows.join(',') + ',{"decimal":3.1400}]');
  expect(W.show(toJson(saved!.items, saved!.numberText?.items))).toBe(W.show(expected.json));
  expect(saved!.items[0].literal).toEqual({ $num: "1.2300" });
  expect(Object.hasOwn(saved!.items[0], "__proto__")).toBe(true);
  expect(({} as any).value).toBeUndefined();
  cache.keep({ t: "log", origin: "other", since: 0, items: [{ ordinary: 42 }] });
  await cache.pending;
  expect(await new HistoryCache(storage).load()).toEqual({ t: "log", origin: "other", since: 0, items: [{ ordinary: 42 }] });
});

test("truncated and unsupported messages match the Bend codec", () => {
  const full = Uint8Array.from(list(W.encode('{"items":[{"text":"hello"}],"t":"log"}')));
  const bad = [[], [0x18], [0x1b], [0x9f], [0x40], [0xa1, 0x18, 255, 0],
    [0xc6, 0x18, 255], [0xc7, 0], [0xc6, 0xc6, 0], [0xd8, 6, 0], [0xf8, 20],
    [0xf6, 0], [0x9a, 255, 255, 255, 255]];
  for (let i = 0; i < full.length; i++) bad.push([...full.subarray(0, i)]);
  for (const input of bad) {
    const bytes = Uint8Array.from(input);
    expect(W.show(decode(bytes).json)).toBe(W.show(W.decode(bendList(bytes))));
  }
});

test("large histories preserve every event and their order", () => {
  const value = {t: "log", origin: "hub", since: 0,
    items: Array.from({length: 24000}, (_, id) => ({id, text: "x".repeat(800), type: "MessagePosted"}))};
  const bytes = Uint8Array.from(list(W.encode(JSON.stringify(value))));
  expect(decode(bytes).value).toEqual(value);
}, 30000);

test("every header follows the shared Bend rules, including tagged map keys", () => {
  for (const prefix of [[], [0xc6], [0xc7]]) {
    for (let head = 0; head < 256; head++) {
      for (const tail of [[], [0], [1, 0, 0, 0, 0, 0]]) {
        const bytes = Uint8Array.from([...prefix, head, ...tail]);
        expect(W.show(decode(bytes).json)).toBe(W.show(W.decode(bendList(bytes))));
      }
    }
  }
  for (const bytes of [Uint8Array.from([0xa1, 0xc6, 0, 0]),
    Uint8Array.from([0xa1, 0xc7, 0x61, 0x30, 0])])
    expect(W.show(decode(bytes).json)).toBe(W.show(W.decode(bendList(bytes))));
});
