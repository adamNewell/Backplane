#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
bend test/web/wire.html -o build/web-wire-test
bun test test/tools/web_wire_test.ts
