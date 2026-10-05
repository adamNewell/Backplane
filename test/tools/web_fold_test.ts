// sh test/tools/web_fold_test.sh (requires Bend and Bun on PATH)
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

test("closed folds do not parse or build large design rows", () => {
  const root = resolve(import.meta.dir, "../..");
  const output = resolve(root, process.env.FOLD_TEST_OUT || "build/web-fold-test");
  const bundle = readFileSync(resolve(output, "fold.html"), "utf8").match(/src="\.\/([^"]+\.js)"/)![1];
  new Function(readFileSync(resolve(output, bundle), "utf8"))();
  const fold = (globalThis as any).BackplaneFoldTest;
  // Reading this row calls String.split on a long path and overflows the JS stack.
  // A closed fold must never read it, regardless of the fold's role.
  const summary = JSON.stringify({ c: "commit", p: "previous", g: "/git", t: "/board", f: ["M\t" + "x".repeat(200000) + ".kicad_pcb"] });
  for (const role of [0n, 1n, 2n]) {
    const nodes = fold.closed(summary, role);
    expect(nodes.$).toBe(role === 1n ? "Nil" : "Con");
    if (nodes.$ === "Con") {
      expect(nodes.head.tag).toBe("button");
      expect(nodes.tail.$).toBe("Nil");
    }
  }
}, 120000);
