#!/bin/sh
# Runs every case in test/cases.json through the PreToolUse hook and checks the decision.
# A case has: name, input (hook stdin), expect (deny, ask, or allow), and optional env.
set -u
cd "$(dirname "$0")/.." || exit 1

hook=block-self-bind-schedule/hooks/guard.sh
fail=0
n=$(jq 'length' test/cases.json)
i=0
while [ "$i" -lt "$n" ]; do
  name=$(jq -r ".[$i].name" test/cases.json)
  expect=$(jq -r ".[$i].expect" test/cases.json)
  vars=$(jq -r ".[$i].env // {} | to_entries | map(\"\(.key)=\(.value)\") | join(\" \")" test/cases.json)
  # shellcheck disable=SC2086
  got=$(jq -c ".[$i].input" test/cases.json \
    | env -i PATH="$PATH" $vars "$hook" \
    | jq -rs '.[0].hookSpecificOutput.permissionDecision // "allow"')
  if [ "$got" = "$expect" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected $expect, got $got"
    fail=1
  fi
  i=$((i + 1))
done

# The hook must fail closed when jq is missing, and stay open in mode off.
if echo '{"tool_name":"Bash"}' | env -i PATH=/nonexistent "$hook" 2>/dev/null; then
  echo "FAIL missing jq: expected exit 2"; fail=1
else
  echo "ok   missing jq denies"
fi
if echo '{"tool_name":"Bash"}' | env -i PATH=/nonexistent BLOCK_SELF_BIND_SCHEDULE=off "$hook" 2>/dev/null; then
  echo "ok   missing jq with mode off allows"
else
  echo "FAIL missing jq with mode off: expected exit 0"; fail=1
fi

# The SessionStart reminder must emit valid JSON in every mode.
for mode in deny ask off; do
  if env -i PATH="$PATH" BLOCK_SELF_BIND_SCHEDULE=$mode block-self-bind-schedule/hooks/remind.sh | jq -e .systemMessage >/dev/null; then
    echo "ok   remind.sh mode $mode"
  else
    echo "FAIL remind.sh mode $mode"; fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "all passed"
exit "$fail"
