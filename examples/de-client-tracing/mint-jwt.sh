#!/bin/bash

# Prints a Document Engine JWT, signed with keys/jwt-private.pem.
#
# Usage: ./mint-jwt.sh [--write] <document-id> <user-id> [creator-name]
#
# With --write, the token is saved to viewer/tokens/<user-id>.json for the
# viewer page instead of being printed.
#
# In a real integration your backend signs this token; the private key never
# reaches the client. This script stands in for that backend.

set -euo pipefail

cd "$(dirname "$0")"

write=false
if [ "${1:-}" = "--write" ]; then
    write=true
    shift
fi

document_id="${1:?Usage: ./mint-jwt.sh <document-id> <user-id> [creator-name]}"
user_id="${2:?Usage: ./mint-jwt.sh <document-id> <user-id> [creator-name]}"
creator_name="${3:-$user_id}"

base64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

header='{"alg":"RS256","typ":"JWT"}'
expires_at=$(($(date +%s) + 3600))
payload=$(printf '{"document_id":"%s","user_id":"%s","creator_name":"%s","permissions":["read-document","write","download"],"exp":%d}' \
    "$document_id" "$user_id" "$creator_name" "$expires_at")

signing_input="$(printf '%s' "$header" | base64url).$(printf '%s' "$payload" | base64url)"
signature=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign keys/jwt-private.pem | base64url)

jwt="$signing_input.$signature"

if [ "$write" = true ]; then
    mkdir -p viewer/tokens
    printf '{"documentId":"%s","jwt":"%s"}\n' "$document_id" "$jwt" > "viewer/tokens/$user_id.json"
    echo "Wrote viewer/tokens/$user_id.json"
else
    printf '%s\n' "$jwt"
fi
