#!/bin/sh
# SessionStart hook. Tells the user and the model what this plugin blocks, and how a human can change the mode.
set -u

mode=${BLOCK_SELF_BIND_SCHEDULE:-deny}
case "$mode" in ask | off) ;; *) mode=deny ;; esac

tools="send_later, self-bind create_trigger, re-arming update_trigger, CronCreate, ScheduleWakeup"
case "$mode" in
  deny) user="block-self-bind-schedule: denying $tools. To change: set BLOCK_SELF_BIND_SCHEDULE=ask or off, then restart Claude Code." ;;
  ask) user="block-self-bind-schedule: mode ask. Calls to $tools need your approval. To change: set BLOCK_SELF_BIND_SCHEDULE=deny or off, then restart Claude Code." ;;
  off) user="block-self-bind-schedule: mode off. Nothing is blocked this session. Unset BLOCK_SELF_BIND_SCHEDULE to restore the guard." ;;
esac

model="The block-self-bind-schedule plugin is active in mode $mode. Do not call $tools. They re-wake this session and resend the full conversation. Use reactive subscriptions instead. Only a human can change the mode."
[ "$mode" = off ] && model="The block-self-bind-schedule plugin is installed but off for this session."

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg user "$user" --arg model "$model" \
    '{systemMessage: $user, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $model}}'
else
  printf '{"systemMessage":"block-self-bind-schedule: jq is not installed. Blocked tools are denied until it is, or until BLOCK_SELF_BIND_SCHEDULE=off is set."}\n'
fi
