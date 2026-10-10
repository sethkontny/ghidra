#!/usr/bin/env bash
# Usage: re.sh <binary> [out_dir]
# Runs headless Ghidra on <binary> and writes summary.txt, imports.txt, strings.txt and
# decompiled.c to out_dir (default: re-toolkit/reports/<binary name>).
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <binary> [out_dir]" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=$(realpath "$1")
OUT=$(realpath -m "${2:-$HERE/reports/$(basename "$BIN")}")
GHIDRA=${GHIDRA:-$(ls -d /opt/ghidra-dev/ghidra_* 2>/dev/null | tail -1)}
[ -x "$GHIDRA/support/analyzeHeadless" ] || { echo "Ghidra not found; run $HERE/setup.sh first" >&2; exit 1; }
export JAVA_HOME=${JAVA_HOME_25:-/usr/lib/jvm/java-25-openjdk-amd64}

PROJ=$(mktemp -d)
trap 'rm -rf "$PROJ"' EXIT
"$GHIDRA/support/analyzeHeadless" "$PROJ" re -import "$BIN" -overwrite \
  -scriptPath "$HERE/scripts" -postScript Report.java "$OUT" -deleteProject \
  > "$PROJ/log.txt" 2>&1 || { tail -30 "$PROJ/log.txt"; exit 1; }
grep -q 'REPORT WRITTEN' "$PROJ/log.txt" || { tail -30 "$PROJ/log.txt"; exit 1; }
cp "$PROJ/log.txt" "$OUT/ghidra.log"
cat "$OUT/summary.txt"
echo "Report: $OUT"
