#!/bin/sh
# Fetch the pinned sources of experiment #1 into $WORKDIR/src.
# Usage: WORKDIR=/path/outside/the/repo sh fetch.sh
# Pins are in ../pins.json and ../sources.json.
set -eu
: "${WORKDIR:?set WORKDIR to a directory outside the repository}"
SRC="$WORKDIR/src"
mkdir -p "$SRC"
cd "$SRC"

pin() { # repo dir commit [sparse-path]
  if [ ! -d "$2" ]; then
    git init -q "$2"
    git -C "$2" remote add origin "https://github.com/$1.git"
    if [ -n "${4:-}" ]; then
      git -C "$2" config core.sparseCheckout true
      git -C "$2" sparse-checkout set "$4" >/dev/null 2>&1 || echo "$4" > "$2/.git/info/sparse-checkout"
    fi
    git -C "$2" fetch -q --depth 1 --filter=blob:none origin "$3"
    git -C "$2" checkout -q FETCH_HEAD
  fi
  test "$(git -C "$2" rev-parse HEAD)" = "$3"
}

pin microsoft/vscode vscode 184833947d794fddbe2cda93f3ad318c42724f55 extensions
pin microsoft/vscode-textmate vscode-textmate 5fc1758043624ace930a2b417259852e534668d8
pin microsoft/vscode-oniguruma vscode-oniguruma 1e38f9612a2599529cfa54283dd419bad697de23
pin php/doc-en doc-en 5b7d0e3c7a1339ef0871851e4611dafcc75c4fb5 reference/mbstring

tarball() { # url file sha256
  [ -f "$2" ] || curl -sSL -o "$2" "$1"
  echo "$3  $2" | sha256sum -c -
}
tarball https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-1.8.2.tar.gz \
  jq-1.8.2.tar.gz 71b8d6e8f5fe81f6c6d0d110e3892251f6ce76ed095abd315e26e6e1193af3af
tarball https://www.php.net/distributions/php-8.5.12.tar.xz \
  php-8.5.12.tar.xz 08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209
[ -d jq-1.8.2 ] || tar xzf jq-1.8.2.tar.gz
[ -d php-8.5.12 ] || tar xJf php-8.5.12.tar.xz

mkdir -p "$WORKDIR/node"
cd "$WORKDIR/node"
[ -f package.json ] || npm init -y >/dev/null
npm install --ignore-scripts --no-audit --no-fund vscode-textmate@9.3.2 vscode-oniguruma@1.7.0
