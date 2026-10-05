// sh test/tools/web_hier_test.sh
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

test("a large schematic sheet list preserves rows and skips blank lines", () => {
  const output = resolve(import.meta.dir, "../../build/web-hier-test");
  const bundle = readFileSync(resolve(output, "hier.html"), "utf8").match(/src="\.\/([^"]+\.js)"/)![1];
  new Function(readFileSync(resolve(output, bundle), "utf8"))();
  const lines = Array.from({length: 64}, (_, i) =>
    `${i % 3}\t${i % 2}\tsheet-${i}\t/project/sheet-${i}.kicad_sch`);
  const rows: any[] = [];
  for (let r = (globalThis as any).BackplaneHierTest.read("\n" + lines.join("\n\n") + "\n"); r.$ === "Con"; r = r.tail)
    rows.push({depth: Number(r.head.depth), name: r.head.name, file: r.head.file, loop: r.head.loop});
  expect(rows).toEqual(Array.from({length: 64}, (_, i) => ({
    depth: i % 3, name: `sheet-${i}`, file: `/project/sheet-${i}.kicad_sch`, loop: i % 2 === 1,
  })));
});
