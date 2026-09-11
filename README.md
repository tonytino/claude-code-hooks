# claude-code-hooks

Claude Code plugins that put guardrails on agent behavior.

| Plugin | Purpose |
| --- | --- |
| [block-self-bind-schedule](#block-self-bind-schedule) | Deny tool calls that schedule wakeups of the current session. |

## Install

```
/plugin marketplace add tonytino/claude-code-hooks
/plugin install block-self-bind-schedule@claude-code-hooks
```

Requires `jq` on the machine that runs the session.

## block-self-bind-schedule

**Problem.** An agent can schedule its own session to wake later, for example an hourly "check-in" while it watches a pull request. Each wake resends the full conversation. On a long session this drains usage with no benefit over a reactive subscription.

**What it does.** A `PreToolUse` hook denies these calls:

| Tool | Denied when |
| --- | --- |
| `send_later` | Always. |
| `create_trigger` | No `persistent_session_id` and no `create_new_session_on_fire: true`, or `persistent_session_id` is the current session. |
| `update_trigger` | It sets `enabled: true`, `cron_expression`, or `run_once_at`. |
| `CronCreate` | Always. |
| `ScheduleWakeup` | Always, except `stop: true`. |

The MCP tools match on any server name. Triggers that spawn a fresh session or target a different session pass. So do rename, prompt, and disable updates.

A `SessionStart` hook reminds you what is blocked and tells the model not to try.

The hook fails closed. If `jq` is missing or the policy errors, the call is denied and the reason names the fix.

### Change the mode

Set `BLOCK_SELF_BIND_SCHEDULE` in the environment that launches Claude Code, then restart it. The model cannot change this from inside a session.

| Value | Effect |
| --- | --- |
| unset or `deny` | Deny the calls above. Default. |
| `ask` | Prompt you to approve each call. In `bypassPermissions` or `dontAsk` mode, or a session with no prompt host, this is a deny. |
| `off` | Allow everything. |

## Develop

```
test/run.sh
```

Cases live in `test/cases.json`. CI runs the tests, `shellcheck`, and JSON validation.

## License

[MIT](LICENSE)
