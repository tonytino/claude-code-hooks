#!/bin/sh
# PreToolUse hook. Fails closed: when jq is missing or the policy errors, the call is denied.
set -u

mode=${BLOCK_SELF_BIND_SCHEDULE:-deny}
[ "$mode" = off ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "block-self-bind-schedule: jq is not installed, call denied. Install jq, or set BLOCK_SELF_BIND_SCHEDULE=off." >&2
  exit 2
fi

dir=$(dirname "$0")
jq -c -f "$dir/guard.jq" || {
  echo "block-self-bind-schedule: policy error, call denied." >&2
  exit 2
}
