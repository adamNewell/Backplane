#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
bend test/web/switch.html -o build/web-switch-test
bun test test/tools/web_switch_test.ts
