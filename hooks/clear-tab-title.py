import json
import os
import sys

STATE_DIR = os.path.join(os.path.expanduser("~"), ".claude", "hooks", "state")


def last_custom_title(path):
    title = ""
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
        pass
    return title


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    sid = data.get("session_id")
    if not sid:
        return
    os.makedirs(STATE_DIR, exist_ok=True)
    # marker holds the pre-clear title so sync-tab-title.py can tell "still stale" from "renamed since clear"
    title = last_custom_title(data.get("transcript_path") or "")
    with open(os.path.join(STATE_DIR, "tab-cleared-" + sid + ".txt"), "w", encoding="utf-8") as f:
        f.write(title)
    print(json.dumps({
        "suppressOutput": True,
        "terminalSequence": "\x1b]2;\x07",
    }))


main()
