#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
bend test/web/hier.html -o build/web-hier-test
bun test test/tools/web_hier_test.ts
