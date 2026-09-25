{ lib, enable }:

# Worktrunk activity markers, shown per branch in `wt list`: 🤖 while Claude
# works, 💬 while it waits, cleared at session end. Same events as upstream's
# plugin (worktrunk.dev/claude-code/#activity-tracking). The hook path is
# stable so a wt bump never strands a store path in the additive hook policy.
#
# The settings reconciler adds these while Worktrunk is the workspace backend.
# Under any other backend it removes these exact entries from the live
# settings.json, because the marker script is no longer installed.
let
  marker = state: "$HOME/.claude/hooks/worktrunk-marker.sh ${state}";
  hooks = [
    { event = "UserPromptSubmit"; matcher = ""; command = marker "working"; }
    { event = "Notification"; matcher = ""; command = marker "waiting"; }
    { event = "PreToolUse"; matcher = "AskUserQuestion"; command = marker "waiting"; }
    { event = "PermissionRequest"; matcher = ""; command = marker "waiting"; }
    { event = "Stop"; matcher = ""; command = marker "waiting"; }
    { event = "SessionEnd"; matcher = ""; command = marker "clear"; }
  ];
in
{
  add = lib.optionals enable hooks;
  remove = lib.optionals (!enable) hooks;
}
