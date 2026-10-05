import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

function sender(results: number[]) {
  let now = 0;
  let parked: any;
  let sent = 0;
  const context: any = {
    performance: { now: () => now },
    io_sys: () => ({ mac: true, ptr: (b: any) => b,
      send: () => { sent++; return results.shift() ?? -1; }, errno: () => 35 }),
    io_tup: (socket: number, result: any) => ({socket, result}),
    io_fail: (code: number) => ({error: code}), io_done: (value: any) => ({value}),
    io_park_on: (...args: any[]) => { parked = args; },
  };
  runInNewContext(readFileSync(new URL('../../src/server/effects/host.js', import.meta.url), 'utf8'), context);
  return { send: () => context.host_send(7, new Uint8Array(8), () => {}),
    advance: (n: number) => { now = n; }, resume: () => parked[3](),
    parked: () => parked, sent: () => sent };
}

test("socket backpressure parks once and expires at the absolute deadline", () => {
  const s = sender([-1]);
  expect(s.send()).toBeUndefined();
  expect(s.sent()).toBe(1);
  expect(s.parked()[4]).toBe(30000);
  s.advance(30000);
  expect(s.resume()).toEqual({socket: 7, result: {error: 60}});
  expect(s.sent()).toBe(1);
});

test("partial writes keep the original deadline; zero writes fail", () => {
  const s = sender([3, -1, 2, -1]);
  s.send();
  s.advance(20000);
  s.resume();
  expect(s.parked()[4]).toBe(30000);
  s.advance(30000);
  expect(s.resume().result.error).toBe(60);
  expect(sender([0]).send().result.error).toBe(32);
});
