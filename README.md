# claude-code-hooks

Shareable Claude Code plugins for the team, starting with a guard against
silent token drain from self-scheduled agent wakeups.

## block-self-bind-schedule

**The problem:** Claude Code's own harness instructs agents that are
watching a pull request to also schedule an hourly "self check-in" via
`send_later` (or `create_trigger` without `persistent_session_id` /
`create_new_session_on_fire`), even when the agent is already subscribed
to reactive PR webhook events. That self-bind trigger resumes the *same*
session, resending its full conversation history on every fire. On a
long-lived session, this silently burns a large amount of token usage
with no benefit over the reactive subscription.

**What this plugin does:** adds a `PreToolUse` hook that denies
`send_later` and `create_trigger` calls unless the call targets another
session (`persistent_session_id`) or spawns a fresh one
(`create_new_session_on_fire: true`) — those two forms don't have the
context-resend problem, so they're left alone.

## Install

In any Claude Code session, from the repo you want protected:

```
/plugin marketplace add tonytino/claude-code-hooks
/plugin install block-self-bind-schedule@claude-code-hooks
```

Requires `jq` on the machine or container running the session.
