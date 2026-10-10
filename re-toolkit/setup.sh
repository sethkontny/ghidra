#!/usr/bin/env bash
# Builds Ghidra from this repository and installs it to /opt/ghidra-dev for re.sh.
# Written for the Claude Code cloud container (Ubuntu 24.04, root, restricted network):
#  - installs JDK 25 + flex from apt and Gradle 9.1 from services.gradle.org
#  - github.com/<repo>/raw/ URLs are blocked there, so dependencies are pre-fetched from
#    raw.githubusercontent.com; every file is still checked against its pinned SHA-256
#  - the PostgreSQL source (only bundled for rebuilding the optional BSim server) is skipped
#  - Maven Central is read through Google's mirror to avoid 429 rate limiting
# Usage: setup.sh [--rebuild]
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
TOOLKIT="$REPO/re-toolkit"
DEST=/opt/ghidra-dev
JDK=/usr/lib/jvm/java-25-openjdk-amd64
GRADLE_VER=9.1.0
GRADLE=/opt/gradle-$GRADLE_VER/bin/gradle

if [ "${1:-}" != "--rebuild" ] && ls -d "$DEST"/ghidra_*/support/analyzeHeadless >/dev/null 2>&1; then
  echo "Ghidra already installed: $(ls -d "$DEST"/ghidra_* | tail -1) (use --rebuild to rebuild)"
  exit 0
fi

echo "== Toolchain"
if [ ! -x "$JDK/bin/javac" ] || ! command -v flex >/dev/null; then
  apt-get update -q
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q openjdk-25-jdk-headless flex
fi
if [ ! -x "$GRADLE" ]; then
  tmp=$(mktemp -d)
  curl -sSfL -o "$tmp/gradle.zip" "https://services.gradle.org/distributions/gradle-$GRADLE_VER-bin.zip"
  unzip -tq "$tmp/gradle.zip"
  unzip -q -o "$tmp/gradle.zip" -d /opt
  rm -rf "$tmp"
fi
export JAVA_HOME=$JDK

cd "$REPO"
echo "== Pre-fetching dependencies"
mkdir -p dependencies/downloads
# The offline listing prints the download commands and then exits non-zero on the
# patched-out postgresql entry; capture it tolerantly rather than under pipefail.
CURLS=$(mktemp)
"$GRADLE" -I gradle/support/fetchDependencies.gradle -Doffline -DnoEclipse --console=plain -q 2>/dev/null \
  | grep '^curl ' > "$CURLS" || true
while read -r _ _ _ out url; do
  out=${out//\"/}; url=${url//\'/}
  url=$(sed -E 's#https://github.com/([^/]+)/([^/]+)/raw/#https://raw.githubusercontent.com/\1/\2/#' <<<"$url")
  [ -s "$out" ] && continue
  curl -sSfL --retry 3 -o "$out" "$url" || { rm -f "$out"; echo "  skipped (unreachable): $url"; }
done < "$CURLS"
rm -f "$CURLS"

echo "== Verifying and installing dependencies"
FETCH=gradle/support/fetchDeps.local.gradle
trap 'rm -f "$REPO/$FETCH"' EXIT
python3 - "$FETCH" <<'EOF'
import re, sys
s = open('gradle/support/fetchDependencies.gradle').read()
out = re.sub(r'\t\[\n\t\tname: "postgresql-[^"]+",.*?\n\t\],\n', '', s, flags=re.S)
if out == s:
    sys.exit('postgresql entry not found in fetchDependencies.gradle; update setup.sh')
open(sys.argv[1], 'w').write(out)
EOF
"$GRADLE" -I "$FETCH" -I "$TOOLKIT/maven-mirror.init.gradle" -DnoEclipse -DhideDownloadProgress \
  --console=plain -q help

echo "== Building Ghidra (10-20 minutes)"
"$GRADLE" -I "$TOOLKIT/maven-mirror.init.gradle" buildGhidra -x ip --console=plain -q

echo "== Installing"
ZIP=$(ls -t build/dist/ghidra_*.zip | head -1)
rm -rf "$DEST" && mkdir -p "$DEST"
unzip -q "$ZIP" -d "$DEST"
echo "Installed $(ls -d "$DEST"/ghidra_* | tail -1)"
