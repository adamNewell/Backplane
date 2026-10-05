import { expect, test } from "bun:test";

test("an unchanged 3D panel does not redraw for composer updates", async () => {
  const frames: Array<FrameRequestCallback> = [];
  const windowEvents = new Map<string, Function>();
  const canvasEvents = new Map<string, Function>();
  const oldWindow = globalThis.window;
  const oldRaf = globalThis.requestAnimationFrame;
  (globalThis as any).window = { devicePixelRatio: 1, addEventListener: (name: string, fn: Function) => windowEvents.set(name, fn) };
  globalThis.requestAnimationFrame = fn => { frames.push(fn); return frames.length; };
  let draws = 0;
  const gl: any = new Proxy({}, { get: (_, name) => {
    if (name === "drawArrays") return () => { draws++; };
    return () => 0;
  } });
  const canvas: any = {
    dataset: { key: "2|render-test" }, width: 300, height: 150, clientWidth: 300, clientHeight: 150,
    getContext: () => gl, addEventListener: (name: string, fn: Function) => canvasEvents.set(name, fn),
    setPointerCapture: () => {}, parentElement: { querySelector: () => null },
  };
  const flush = () => { for (const frame of frames.splice(0)) frame(performance.now()); };
  try {
    const solid = await import("../../src/web/solid.js");
    solid.got({ key: canvas.dataset.key, n: 1, mesh: new Uint8Array(10) });
    await Bun.sleep(50);
    solid.mount(canvas);
    flush();
    expect(draws).toBe(1);
    for (let i = 0; i < 20; i++) solid.mount(canvas);
    expect(frames.length).toBe(0);
    expect(draws).toBe(1);
    canvas.clientWidth = 400;
    solid.mount(canvas);
    flush();
    expect(draws).toBe(2);
    expect(canvas.width).toBe(400);
    canvas.clientHeight = 200;
    windowEvents.get("resize")!();
    flush();
    expect(draws).toBe(3);
    expect(canvas.height).toBe(200);
    canvasEvents.get("pointerdown")!({ pointerId: 1, clientX: 10, clientY: 10, button: 0 });
    canvasEvents.get("pointermove")!({ pointerId: 1, clientX: 30, clientY: 20 });
    flush();
    expect(draws).toBe(4);
    solid.fit();
    flush();
    expect(draws).toBe(5);
    solid.mount(null);
  } finally {
    (globalThis as any).window = oldWindow;
    globalThis.requestAnimationFrame = oldRaf;
  }
});
