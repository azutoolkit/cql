#!/usr/bin/env bash
# usage: gates.sh <spec files...>   runs FAST_TEST twice, build, format, ameba, docs checks if docs changed, size
set -uo pipefail
cd /home/user/cql
source .factory/env.sh
fail() { echo "GATE FAIL: $1"; exit 1; }
for i in 1 2; do
  out=$(crystal spec "$@" 2>&1); rc=$?
  echo "$out" | tail -4
  [ $rc -eq 0 ] || { echo "$out" | grep -E "Failure|Error|expected|got" | head -30; fail "fast test run $i"; }
done
crystal build --no-codegen src/cql.cr -o /tmp/cql_build_check >/dev/null 2>&1 || fail "build"
crystal tool format --check src spec >/dev/null 2>&1 || { crystal tool format --check src spec 2>&1 | head; fail "format"; }
amb=$(.factory/ameba -f progress ./src ./spec 2>&1); echo "$amb" | tail -1 | grep -q " 0 failures" || { echo "$amb" | grep -A3 -E "^\S+\.cr:" | head -30; fail "ameba"; }
if git status --porcelain | grep -q " docs/"; then
  python3 script/docs/check_links.py >/dev/null && python3 script/docs/check_nav.py >/dev/null && python3 script/docs/gitbook_lint.py >/dev/null || fail "docs checks"
fi
git add -A -- . ':!.factory' ':!.tmp_cql_snippet_*' 2>/dev/null
added=$(git diff --cached --numstat | awk '{s+=$1} END {print s+0}')
echo "added lines: $added"; git diff --cached --stat | tail -1
[ "$added" -le 150 ] || { git reset -q; fail "size $added > 150"; }
echo "GATES PASS"
