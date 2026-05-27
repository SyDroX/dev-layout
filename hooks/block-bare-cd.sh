#!/bin/bash
# Blocks any working-directory-change command in Bash or PowerShell tool calls.
# Hook input is JSON on stdin: {"tool_input": {"command": "..."}}.
# Splits on ; && || | newline, then checks the first token of each segment
# (case-insensitive) against the cd-equivalents list. Use absolute paths or
# `git -C /path` / `& 'C:\full\path\to\tool.bat'` instead.
INPUT=$(cat)
RESULT=$(HOOK_INPUT="$INPUT" python <<'PY'
import json, os, re, sys
data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
cmd = (data.get("tool_input") or {}).get("command", "") or ""
banned = {"cd", "chdir", "set-location", "push-location", "pop-location", "sl"}
segments = re.split(r"(?:;|&&|\|\||\||\n)", cmd)
for seg in segments:
    seg = seg.strip()
    if not seg:
        continue
    first = seg.split(None, 1)[0].lower()
    if first in banned:
        print(first)
        sys.exit(0)
PY
)

if [[ -n "$RESULT" ]]; then
  echo "BLOCKED: '$RESULT' changes working directory. Use absolute paths, 'git -C /path', or '& C:\\full\\path\\to\\tool.bat' instead." >&2
  exit 2
fi

exit 0
