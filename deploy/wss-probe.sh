#!/usr/bin/env bash
#
# WSS Probe Script for lucky-sign WebSocket endpoint
#
# Tests WebSocket upgrade handshake and expects HTTP 101 Switching Protocols.
# Does NOT require wscat/websocat - uses curl for basic HTTP upgrade check.
#
# Usage:
#   ./wss-probe.sh https://your-domain.example
#   ./wss-probe.sh http://127.0.0.1:8080        # local backend test
#
# Exit codes:
#   0 - WebSocket upgrade successful (HTTP 101)
#   1 - Connection failed or unexpected response
#
# NOTE: This tests /ws (exact path), not /ws/ (with trailing slash).
#       The backend STOMP endpoint is registered at /ws.

set -euo pipefail

usage() {
    echo "Usage: $0 <base-url>"
    echo ""
    echo "Examples:"
    echo "  $0 https://api.example.com"
    echo "  $0 http://127.0.0.1:8080"
    echo ""
    echo "Tests WebSocket upgrade handshake at /ws endpoint."
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

BASE_URL="${1%/}"

if [[ "$BASE_URL" == https://* ]]; then
    WS_URL="${BASE_URL}/ws"
elif [[ "$BASE_URL" == http://* ]]; then
    WS_URL="${BASE_URL}/ws"
else
    echo "ERROR: Base URL must start with http:// or https://"
    exit 1
fi

echo "=== WSS Probe ==="
echo "Target: $WS_URL"
echo ""

HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
    --max-time 10 \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    "$WS_URL" 2>/dev/null || echo "000")

echo "HTTP Response Code: $HTTP_CODE"

if [[ "$HTTP_CODE" == "101" ]]; then
    echo ""
    echo "SUCCESS: WebSocket upgrade handshake OK (HTTP 101 Switching Protocols)"
    exit 0
elif [[ "$HTTP_CODE" == "000" ]]; then
    echo ""
    echo "FAILED: Could not connect to $WS_URL"
    echo "Check: Is the server running? Is the URL correct? Firewall/network issues?"
    exit 1
elif [[ "$HTTP_CODE" == "404" ]]; then
    echo ""
    echo "FAILED: HTTP 404 Not Found"
    echo "Check: Is the WebSocket endpoint registered at /ws?"
    echo "       Security config must permit /ws (exact) AND /ws/**"
    exit 1
elif [[ "$HTTP_CODE" == "403" ]]; then
    echo ""
    echo "FAILED: HTTP 403 Forbidden"
    echo "Check: Security config permitAll for /ws and /ws/**"
    exit 1
elif [[ "$HTTP_CODE" == "429" ]]; then
    echo ""
    echo "FAILED: HTTP 429 Too Many Requests"
    echo "Check: RateLimitFilter should exempt /ws paths"
    exit 1
else
    echo ""
    echo "FAILED: Unexpected HTTP code $HTTP_CODE (expected 101)"
    echo ""
    echo "Verbose output:"
    curl -v \
        --max-time 10 \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
        -H "Sec-WebSocket-Version: 13" \
        "$WS_URL" 2>&1 || true
    exit 1
fi
