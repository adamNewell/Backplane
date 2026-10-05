#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
bend test/web/fold.html -o build/web-fold-test
bun test test/tools/web_fold_test.ts
