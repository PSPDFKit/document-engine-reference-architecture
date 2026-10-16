#!/bin/bash

# Joins the Envoy access log with the Document Engine log by request ID, to show
# which client sent each Instant sync request and what Document Engine did with it.
#
# Usage:
#   ./trace-clients.sh [--since 10m]                  One line per sync request.
#   ./trace-clients.sh [--since 10m] --record <id>    Every sync that changed one annotation.
#
# Set KUBE_CONTEXT to target a cluster other than the current kubectl context.

set -euo pipefail

since=10m
record_id=""
while [ $# -gt 0 ]; do
    case "$1" in
        --since)
            since="${2:?--since needs a duration, e.g. 30m}"
            shift 2
            ;;
        --record)
            record_id="${2:?--record needs an annotation ID}"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

kubectl_args=()
if [ -n "${KUBE_CONTEXT:-}" ]; then
    kubectl_args+=(--context "$KUBE_CONTEXT")
fi

kubectl_logs() {
    kubectl "${kubectl_args[@]}" logs --since "$since" --tail=-1 "$@"
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Gateway: one JSON object per request, written by the EnvoyProxy in gateway.yaml.
# Only sync requests are kept; CORS preflights (OPTIONS) carry no SDK headers.
kubectl_logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=document-engine -c envoy \
    | grep '^{' \
    | jq -c 'select(.method == "POST" and .path != null and (.path | test("/sync$")))' \
    > "$workdir/gateway.jsonl" || true

# Document Engine: structured logs, one JSON object per line.
kubectl_logs -n document-engine -l app.kubernetes.io/name=document-engine \
    | grep '^{' \
    | jq -c 'select(."meta.request_id" != null)' \
    > "$workdir/document-engine.jsonl" || true

# For every sync that carried changes, Document Engine logs the counts at `info`:
# "After hooks: accepted.created=N ... rejected.created=N ...".
# A sync without changes (a client's first sync, or a long poll waiting for
# other clients' changes) doesn't produce this line.
jq -c '
  select(.message | startswith("After hooks:"))
  | {
      request_id: ."meta.request_id",
      accepted: ([.message | scan("accepted\\.[a-z]+=([0-9]+)") | .[0] | tonumber] | add),
      rejected: ([.message | scan("rejected\\.[a-z]+=([0-9]+)") | .[0] | tonumber] | add)
    }
' "$workdir/document-engine.jsonl" > "$workdir/outcomes.jsonl"

# At `debug`, Document Engine also dumps each sync with changes: which records were
# accepted or rejected (and why), and the creator name from the client's JWT.
# Document Engine doesn't log the user for syncs without changes. The dump is
# printed with Elixir's default inspect limits, so for large annotations (ink,
# images) or large batches, later fields and records are cut off as `...`.
jq -c '
  select(.message | test("\n  rejected: %\\{"))
  | .message as $message
  | ($message | index("\n  rejected: %{")) as $rejected_start
  | ($message | index("\n  accepted: %{")) as $accepted_start
  | ($message | index("\n  changes: %{")) as $accepted_end
  | $message[$rejected_start:$accepted_start] as $rejected
  | {
      request_id: ."meta.request_id",
      time: (.time | sub(" "; "T")),
      user: (($message | capture("\n  creator_name: \"(?<name>[^\"]*)\"") | .name) // null),
      rejected: [
        $rejected
        | scan("(created|updated|deleted): %\\{([^}]*)\\}")
        | .[0] as $action
        | .[1]
        | scan("\"([^\"]+)\" => \"([^\"]+)\"")
        | {id: .[0], action: $action, reason: .[1]}
      ],
      accepted: [
        $message[$accepted_start:$accepted_end]
        | scan("\\.(Create|Update|Delete)\\{[^%]*?\\bid: \"([^\"]+)\"")
        | {id: .[1], action: ({"Create": "created", "Update": "updated", "Delete": "deleted"}[.[0]])}
      ]
    }
' "$workdir/document-engine.jsonl" > "$workdir/details.jsonl"

if [ -n "$record_id" ]; then
    printf '%-24s %-8s %-10s %-10s %-8s %-9s %s\n' TIME PLATFORM SDK USER ACTION OUTCOME "REASON / REQUEST ID"

    jq -r -n \
        --arg record_id "$record_id" \
        --slurpfile gateway "$workdir/gateway.jsonl" \
        --slurpfile details "$workdir/details.jsonl" '
      ($gateway | map({(.request_id): .}) | add // {}) as $requests
      | [
          $details[]
          | . as $sync
          | (
              (.accepted[] | select(.id == $record_id) | {action, outcome: "accepted", reason: ""}),
              (.rejected[] | select(.id == $record_id) | {action, outcome: "rejected", reason})
            )
          | . + {request_id: $sync.request_id, user: $sync.user, time: $sync.time, request: ($requests[$sync.request_id] // {})}
        ]
      | map(. + {time: (.request.time // .time)})
      | sort_by(.time)
      | .[]
      | [
          .time,
          # Envoy writes its access log line when the request ends, and flushes it
          # about every 10 seconds, so a request that just finished may be missing.
          (if .request == {} then "?" else (.request.platform // "-") end),
          ((.request.sdk_version // "") | capture("client=(?<v>[^,]+)").v // "-"),
          (.user // "-"),
          .action,
          .outcome,
          (if .reason == "" then .request_id else "\(.reason) (\(.request_id))" end)
        ]
      | @tsv
    ' | while IFS=$'\t' read -r time platform sdk user action outcome rest; do
        printf '%-24s %-8s %-10s %-10s %-8s %-9s %s\n' "$time" "$platform" "$sdk" "$user" "$action" "$outcome" "$rest"
    done
    echo
    echo "PLATFORM '?' means the request isn't in the gateway log (yet). Envoy writes it about every 10 seconds."
    exit 0
fi

printf '%-24s %-8s %-10s %-6s %-10s %-9s %-9s %-9s %-9s %s\n' \
    TIME PLATFORM SDK STATUS USER DURATION ACCEPTED REJECTED RECEIVED "REQUEST ID / REJECTED RECORDS"

jq -r -n \
    --slurpfile gateway "$workdir/gateway.jsonl" \
    --slurpfile outcomes "$workdir/outcomes.jsonl" \
    --slurpfile details "$workdir/details.jsonl" '
  ($outcomes | map({(.request_id): .}) | add // {}) as $outcomes_by_id
  | ($details | map({(.request_id): .}) | add // {}) as $details_by_id
  # The smallest response on each layer is a sync that returned no changes. A
  # response clearly larger than that delivered other clients changes.
  | ($gateway | group_by(.path) | map({(.[0].path): (map(.bytes_sent) | min)}) | add // {}) as $empty_response_size
  | $gateway
  | sort_by(.time)
  | .[]
  | . as $request
  | ($outcomes_by_id[$request.request_id]) as $outcome
  | ($details_by_id[$request.request_id] // {}) as $detail
  | [
      $request.time,
      ($request.platform // "-"),
      (($request.sdk_version // "") | capture("client=(?<v>[^,]+)").v // "-"),
      ($request.status | tostring),
      ($detail.user // "-"),
      "\($request.duration_ms)ms",
      (if $outcome != null then ($outcome.accepted | tostring)
       elif $request.status == 200 then "-"
       else "no log" end),
      (if $outcome != null then ($outcome.rejected | tostring) else "-" end),
      # A response to a sync that sent changes also echoes the accepted records,
      # so its size says nothing about other clients changes.
      (if $outcome != null or $request.status != 200 then "n/a"
       elif $request.bytes_sent > $empty_response_size[$request.path] + 64 then "yes"
       else "-" end),
      ($request.request_id
        + (($detail.rejected // []) | map("\n" + (" " * 101) + "\(.id) (\(.action)): \(.reason)") | join("")))
    ]
  | @tsv
' | while IFS=$'\t' read -r time platform sdk status user duration accepted rejected received rest; do
    printf '%-24s %-8s %-10s %-6s %-10s %-9s %-9s %-9s %-9s %b\n' \
        "$time" "$platform" "$sdk" "$status" "$user" "$duration" "$accepted" "$rejected" "$received" "$rest"
done

echo
echo "ACCEPTED/REJECTED: changes this client sent. '-' means it sent none (a first sync, or a long poll"
echo "waiting for other clients). 'no log' means Document Engine has no log for the request: it failed"
echo "before Document Engine processed it, or the container that handled it has restarted since."
echo "RECEIVED: for syncs that sent nothing, whether the response delivered other clients' changes"
echo "(estimated from the response size)."
echo "Follow one annotation across clients with: ./trace-clients.sh --record <annotation-id>"
