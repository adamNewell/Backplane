#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
bend test/native/socket_deadline.bend -o build/socket-deadline-runtime.js
bun test test/tools/socket_deadline_test.ts
