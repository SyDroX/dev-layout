import json
import os
import re
import sys

STATE_DIR = os.path.join(os.path.expanduser("~"), ".claude", "hooks", "state")

BLANK = {"suppressOutput": True, "terminalSequence": "\x1b]2;\x07"}


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    path = data.get("transcript_path")
    if not path:
        return
    title = None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                # cheap substring filter before json parse; last custom-title wins
                if '"custom-title"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                if rec.get("type") == "custom-title" and rec.get("customTitle"):
                    title = rec["customTitle"]
    except OSError:
        return
    if not title:
        return
    # /clear drops a marker with the pre-clear title; keep tab blank until a NEW rename supersedes it
    sid = data.get("session_id")
    if sid:
        marker = os.path.join(STATE_DIR, "tab-cleared-" + sid + ".txt")
        if os.path.isfile(marker):
            try:
                with open(marker, "r", encoding="utf-8") as f:
                    cleared = f.read()
            except OSError:
                cleared = None
            if cleared == title:
                print(json.dumps(BLANK))
                return
            try:
                os.remove(marker)
            except OSError:
                pass
    title = re.sub(r"[\x00-\x1f\x7f]", "", title)[:120]
    print(json.dumps({
        "suppressOutput": True,
        "terminalSequence": "\x1b]2;" + title + "\x07",
    }))


main()
