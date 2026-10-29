#!/usr/bin/env bash
# E2E smoke test for chiangmai-handbook static PWA
# Verifies: HTML exists, key title present, manifest exists, HTTP 200 from local server
# Final output line: E2E OK

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=18321
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- Static file checks ---
echo "[1/4] Checking index.html exists and contains title..."
if [ ! -f "$REPO_DIR/index.html" ]; then
  echo "FAIL: index.html not found"
  exit 1
fi
if ! grep -q "清邁" "$REPO_DIR/index.html"; then
  echo "FAIL: index.html missing expected title content"
  exit 1
fi

echo "[2/4] Checking manifest.webmanifest exists..."
if [ ! -f "$REPO_DIR/manifest.webmanifest" ]; then
  echo "FAIL: manifest.webmanifest not found"
  exit 1
fi

echo "[3/4] Checking PWA icons exist..."
for icon in icon-192.png icon-512.png; do
  if [ ! -f "$REPO_DIR/$icon" ]; then
    echo "FAIL: $icon not found"
    exit 1
  fi
done

# --- HTTP check via local server ---
echo "[4/4] Starting local HTTP server on port $PORT..."
cd "$REPO_DIR"
python3 -m http.server "$PORT" --bind 127.0.0.1 > /dev/null 2>&1 &
SERVER_PID=$!

# Wait for server to be ready (max 5 seconds)
for i in $(seq 1 10); do
  if curl -sf "http://127.0.0.1:$PORT/" > /dev/null 2>&1; then
    break
  fi
  sleep 0.5
  if [ "$i" -eq 10 ]; then
    echo "FAIL: local server did not start in time"
    exit 1
  fi
done

HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "http://127.0.0.1:$PORT/")
if [ "$HTTP_STATUS" != "200" ]; then
  echo "FAIL: HTTP status $HTTP_STATUS (expected 200)"
  exit 1
fi

MANIFEST_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "http://127.0.0.1:$PORT/manifest.webmanifest")
if [ "$MANIFEST_STATUS" != "200" ]; then
  echo "FAIL: manifest HTTP status $MANIFEST_STATUS (expected 200)"
  exit 1
fi

echo "E2E OK"
