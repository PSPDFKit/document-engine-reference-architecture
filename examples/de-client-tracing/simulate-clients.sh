#!/bin/bash

# Plays a short story with two clients on the same annotation, using the same
# HTTP requests and headers as the iOS and Web SDKs, so that trace-clients.sh has
# accepted changes, a conflict and a rejection from two platforms to show:
#
#   1. Carol's iPad creates a rectangle.
#   2. Dave's browser moves it.
#   3. Carol's iPad, which hasn't synced since step 1, moves it too: rejected as a conflict.
#   4. Carol's iPad creates an annotation signed with another author's name: rejected.
#   5. Carol's iPad syncs, then deletes the rectangle.
#
# Usage: ./simulate-clients.sh [server-url]   (default: http://localhost:8080)

set -euo pipefail

cd "$(dirname "$0")"

server_url="${1:-http://localhost:8080}"
document_id=client-tracing-demo

ios_headers=(
    -H "PSPDFKit-Platform: ios"
    -H "PSPDFKit-Version: protocol=4, client=27.0.1, client-git=simulated"
    -H "User-Agent: ExampleApp/1.0 CFNetwork/3826 Darwin/25.0.0"
)
web_headers=(
    -H "PSPDFKit-Platform: web"
    -H "PSPDFKit-Version: protocol=5, client=1.22.0, client-git=simulated"
    -H "User-Agent: Mozilla/5.0 (simulated browser)"
    -H "Origin: http://localhost:4300"
)

# Prints "<token> <layer handle>" for a new client session.
authenticate() {
    local user_id="$1" creator_name="$2"
    shift 2
    curl -s --fail -X POST "$server_url/i/d/$document_id/auth" \
        -H "Content-Type: application/json" "$@" \
        -d "{\"jwt\":\"$(./mint-jwt.sh "$document_id" "$user_id" "$creator_name")\",\"bundle_id\":\"com.example.app\"}" \
        | jq -r '"\(.token) \(.layerHandle)"'
}

# Sends one sync request and prints the response.
sync_request() {
    local session="$1" body="$2"
    shift 2
    curl -s --fail -X POST "$server_url/i/d/$document_id/h/${session#* }/sync" \
        -H "X-PSPDFKit-Token: ${session%% *}" \
        -H "Content-Type: text/plain;charset=UTF-8" "$@" \
        -d "$body"
}

sync_body() {
    local record_rev="$1" created="${2:-[]}" updated="${3:-[]}" deleted="${4:-[]}"
    printf '{"request_id":"%s","record_rev":%s,"timeout":0,"changes":{"created":%s,"updated":%s,"deleted":%s}}' \
        "$RANDOM$RANDOM" "$record_rev" "$created" "$updated" "$deleted"
}

rectangle() {
    local id="$1" left="$2" creator_name="$3"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '{"id":"%s","content":{"v":2,"type":"pspdfkit/shape/rectangle","pageIndex":0,"bbox":[%s,80,120,80],"strokeWidth":3,"strokeColor":"#2B6CB0","creatorName":"%s","opacity":1,"createdAt":"%s","updatedAt":"%s"}}' \
        "$id" "$left" "$creator_name" "$now" "$now"
}

new_id() {
    openssl rand -hex 13 | tr '[:lower:]' '[:upper:]'
}

report() {
    jq -r --arg step "$1" '
      "\($step): record_rev \(.record_rev)"
      + ([.rejected | to_entries[] | .key as $action | .value | to_entries[] | ", rejected \($action) \(.key): \(.value)"] | join(""))
    '
}

if ! curl -s --fail -o /dev/null "$server_url/healthcheck"; then
    echo "Document Engine isn't reachable at $server_url. Is the port-forward from setup.sh running?" >&2
    exit 1
fi

rectangle_id=$(new_id)
forged_id=$(new_id)

ipad=$(authenticate carol Carol "${ios_headers[@]}")
browser=$(authenticate dave Dave "${web_headers[@]}")

ipad_rev=$(sync_request "$ipad" "$(sync_body 0)" "${ios_headers[@]}" | jq .record_rev)
browser_rev=$(sync_request "$browser" "$(sync_body 0)" "${web_headers[@]}" | jq .record_rev)

response=$(sync_request "$ipad" "$(sync_body "$ipad_rev" "[$(rectangle "$rectangle_id" 60 Carol)]")" "${ios_headers[@]}")
echo "$response" | report "1. iPad creates the rectangle"
ipad_rev=$(echo "$response" | jq .record_rev)
sleep 1

browser_rev=$(sync_request "$browser" "$(sync_body "$browser_rev")" "${web_headers[@]}" | jq .record_rev)
sync_request "$browser" "$(sync_body "$browser_rev" "[]" "[$(rectangle "$rectangle_id" 220 Carol)]")" "${web_headers[@]}" \
    | report "2. Browser moves it"
sleep 1

sync_request "$ipad" "$(sync_body "$ipad_rev" "[]" "[$(rectangle "$rectangle_id" 380 Carol)]")" "${ios_headers[@]}" \
    | report "3. iPad moves it without syncing first"
sleep 1

response=$(sync_request "$ipad" "$(sync_body "$ipad_rev" "[$(rectangle "$forged_id" 60 Mallory)]")" "${ios_headers[@]}")
echo "$response" | report "4. iPad creates an annotation signed by Mallory"
ipad_rev=$(echo "$response" | jq .record_rev)
sleep 1

sync_request "$ipad" "$(sync_body "$ipad_rev" "[]" "[]" "[\"$rectangle_id\"]")" "${ios_headers[@]}" \
    | report "5. iPad deletes the rectangle"

echo
echo "Follow the rectangle across both clients:"
echo "  ./trace-clients.sh --record $rectangle_id"
