# PreToolUse policy. Input: hook JSON on stdin. Output: a permission decision, or {} to allow.
# Mode comes from BLOCK_SELF_BIND_SCHEDULE: "deny" (default), "ask", or "off".

def mode: (env.BLOCK_SELF_BIND_SCHEDULE // "deny") | if . == "ask" or . == "off" then . else "deny" end;

# Session ids differ in prefix between surfaces ("session_01X" vs "cse_01X"). Compare the part after the prefix.
def session_key: if type == "string" then sub("^[a-z]+_"; "") else null end;
def own_session: env.CLAUDE_CODE_REMOTE_SESSION_ID | session_key;

def tool: .tool_name;
def input: .tool_input // {};
def is_mcp($name): tool | test("^mcp__.+__" + $name + "$");

def targets_self:
  (input.persistent_session_id | session_key) as $target
  | ($target != null and own_session != null and $target == own_session);

def self_bind_create:
  ((input.persistent_session_id // "") == "" and input.create_new_session_on_fire != true) or targets_self;

# Re-arming an existing trigger can revive a self-bind schedule. Renaming, changing the prompt, or disabling stays allowed.
def rearms_trigger:
  input.enabled == true or input.cron_expression != null or input.run_once_at != null;

def reason:
  if is_mcp("send_later") then "send_later re-wakes this session"
  elif is_mcp("create_trigger") then "this create_trigger re-wakes this session"
  elif is_mcp("update_trigger") then "this update_trigger re-arms a schedule"
  elif tool == "CronCreate" then "CronCreate re-wakes this session"
  elif tool == "ScheduleWakeup" then "ScheduleWakeup re-wakes this session"
  else null end;

def blocked:
  is_mcp("send_later")
  or (is_mcp("create_trigger") and self_bind_create)
  or (is_mcp("update_trigger") and rearms_trigger)
  or tool == "CronCreate"
  or (tool == "ScheduleWakeup" and input.stop != true);

def decision($mode):
  { hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $mode,
      permissionDecisionReason: (
        "block-self-bind-schedule: " + reason + ". Each wake resends the full conversation and can drain usage. "
        + "Use a reactive subscription, or create_trigger with create_new_session_on_fire:true or a persistent_session_id for another session. "
        + "Only a human can lift this: set BLOCK_SELF_BIND_SCHEDULE=ask or off before launching Claude Code."
      )
  } };

if mode == "off" or (blocked | not) then {} else decision(mode) end
