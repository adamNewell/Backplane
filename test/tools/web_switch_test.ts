// sh test/tools/web_switch_test.sh
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

test("provider changes count a large history without a JavaScript stack overflow", () => {
  const output = resolve(import.meta.dir, "../../build/web-switch-test");
  const bundle = readFileSync(resolve(output, "switch.html"), "utf8").match(/src="\.\/([^"]+\.js)"/)![1];
  (0, eval)(readFileSync(resolve(output, bundle), "utf8"));
  let entries: any = { $: "Nil" };
  for (let i = 0; i < 30000; i++) {
    const thread = i % 10 === 0 ? "thread-a" : "thread-b";
    const head = i % 2 === 0
      ? { $: "Msg", id: String(i), thread, role: { $: "User" }, text: "message", at: 0n }
      : { $: "Act", id: String(i), thread, tone: "tool", kind: "shell", summary: "done", at: 0n };
    entries = { $: "Con", head, tail: entries };
  }
  const counter = (globalThis as any).BackplaneSwitchTest;
  const state = counter.state(entries);
  expect(counter.count(state, "thread-a")).toBe(3000n);
  expect(counter.count(state, "thread-b")).toBe(27000n);
  expect(counter.count(state, "missing")).toBe(0n);
});


test("repeated count lookups preserve a large projection total", () => {
  const counter = (globalThis as any).BackplaneSwitchTest;
  let entries: any = { $: "Nil" };
  for (let i = 0; i < 100000; i++) entries = { $: "Con", head: { $: "Act", id: String(i), thread: "owner", tone: "tool", kind: "shell", summary: "done", at: 0n }, tail: entries };
  const state = counter.state(entries);
  for (let i = 0; i < 1000; i++) expect(counter.count(state, "owner")).toBe(100000n);
});
