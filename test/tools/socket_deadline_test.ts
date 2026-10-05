import { expect, test } from "bun:test";

// Use the generated runtime unchanged. Only the send syscall is replaced.
// The real select call must wake the real scheduler when the deadline expires.
test("the Bend JS parker resumes a blocked send at its deadline without readiness", async () => {
  const probe = String.raw`
    const {readFileSync} = require('node:fs');
    const {runInNewContext} = require('node:vm');
    let offset = 0, sends = 0, result;
    const context = {require, process, TextEncoder, TextDecoder,
      performance: {now: () => performance.now() + offset}};
    const source = readFileSync('build/socket-deadline-runtime.js', 'utf8');
    const entry = 'cli(process.argv.slice(2));\nio_exit($main$, null);';
    if (!source.endsWith(entry)) throw Error('Unexpected Bend runtime entry');
    runInNewContext(source.slice(0, -entry.length), context);
    const sys = context.io_sys();
    context.BEND_SYS = {...sys, send: () => {sends++; offset = 29980; return -1;},
      errno: () => sys.mac ? 35 : 11};
    runInNewContext(readFileSync('src/server/effects/host.js', 'utf8'), context);
    const start = performance.now();
    const exit = context.io_run(() => k => ({run: context.host_send,
      args: [undefined, new Uint8Array(1)], kont: value => {
        result = value; return k({$:'Unit'});
      }}));
    console.log(JSON.stringify({exit, sends, elapsed: performance.now()-start,
      result, timeout: sys.mac ? 60 : 110, waits: context.BEND_IO.waits.length}));
  `;
  const child = Bun.spawn([process.execPath, "-e", probe], { stdout: "pipe", stderr: "pipe" });
  const watchdog = setTimeout(() => child.kill(), 5000);
  try {
    const [output, error, exit] = await Promise.all([
      new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited]);
    expect(error).toBe("");
    expect(exit).toBe(0);
    const row = JSON.parse(output);
    expect(row.exit).toBe(0);
    expect(row.sends).toBe(1);
    expect(row.result.snd.$).toBe("Fail");
    expect(row.result.snd.error.fst).toBe(row.timeout);
    expect(row.waits).toBe(0);
    expect(row.elapsed).toBeGreaterThanOrEqual(10);
    expect(row.elapsed).toBeLessThan(1000);
  } finally { clearTimeout(watchdog); child.kill(); }
}, 10000);
