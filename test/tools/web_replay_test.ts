import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
const dir = resolve(import.meta.dir, "../../build/web-replay-test");
const entry = readFileSync(resolve(dir, "replay.html"), "utf8").match(/src="\.\/([^"]+\.js)"/)![1];
new Function(readFileSync(resolve(dir, entry), "utf8"))();
const R = (globalThis as any).BackplaneReplayTest;

test("direct ingestion preserves the full read model and UI event effects", () => {
  const items = [
    {$: "ThreadCreated", id: "t", project: "p", title: "Test", env: "local", branch: "", worktree: "", provider: "claude", model: "", at: 0},
    {$: "MessagePosted", thread: "t", msg: "m", role: "user", text: "hello", at: 1},
    {$: "ActivityLogged", thread: "t", act: "step", tone: "step", kind: "kicad", summary: JSON.stringify({e:"m",c:"c",p:"",g:"/g",t:"/t",f:["M\ta.kicad_pcb","D\tb.kicad_sch"]}), at: 2},
    {$: "UnknownFutureEvent", thread: "t"},
    null,
    {$: "MessagePosted", thread: "t", msg: "a", role: "assistant", text: "done", at: 3},
    {$: "TurnChanged", thread: "t", state: "completed", at: 4},
    {$: "ProviderSet", id: "t", provider: "codex", model: "test", at: 5},
  ];
  const json = R.parse(JSON.stringify({items})).value;
  expect(R.ingest(R.init(), json)).toEqual(R.fold(R.init(), json));
});

test("history is prepared on selection, then updated without losing deferred steps", () => {
  const step = (thread: string, act: string) => ({$: "ActivityLogged", thread, act, tone: "step", kind: "kicad",
    summary: JSON.stringify({e:"m",c:act,p:"",g:"/g",t:"/t",f:["M\ta.kicad_pcb"]}), at: 1});
  const json = (items: any[]) => R.parse(JSON.stringify({items})).value;
  const deferred = R.ingest(R.init(), json([step("a", "a1"), step("b", "b1")]));
  expect(R.ready(deferred.st.bots.head, "a")).toBe(false);
  expect(R.ready(deferred.st.bots.head, "b")).toBe(false);
  const selected = R.select(deferred, "a");
  expect(R.ready(selected.st.bots.head, "a")).toBe(true);
  expect(R.ready(selected.st.bots.head, "b")).toBe(false);
  const updated = R.ingest(selected, json([step("a", "a2"), step("b", "b2")]));
  function ids(rows: any) {const out=[];for(;rows.$==="Con";rows=rows.tail)out.push(rows.head.id);return out;}
  expect(ids(R.history(updated.st, "@board:a"))).toEqual(["a2", "a1"]);
  expect(ids(R.history(R.select(updated, "b").st, "@board:b"))).toEqual(["b2", "b1"]);
});
