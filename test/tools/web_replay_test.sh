#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
bend test/web/replay.html -o build/web-replay-test
bun test test/tools/web_replay_test.ts
