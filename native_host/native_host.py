#!/usr/bin/env python3
"""
Chrome Native Messaging host for the extension updater.
Chrome sends a JSON message; on action "run_update" we run update_extension.py
and return the result. Reads/writes Chrome's length-prefixed JSON protocol.
"""
import json
import os
import struct
import subprocess
import sys

# Directory where this script lives; update_extension.py is in the parent directory
HOST_DIR = os.path.dirname(os.path.abspath(__file__))
UPDATER_SCRIPT = os.path.join(HOST_DIR, "..", "update_extension.py")
UPDATER_DIR = os.path.dirname(UPDATER_SCRIPT)


def read_message():
    """Read one length-prefixed JSON message from stdin (Chrome native messaging protocol)."""
    raw_length = sys.stdin.buffer.read(4)
    if len(raw_length) == 0:
        return None
    length = struct.unpack("=I", raw_length)[0]
    if length == 0:
        return None
    payload = sys.stdin.buffer.read(length)
    if len(payload) != length:
        return None
    return json.loads(payload.decode("utf-8"))


def send_message(msg):
    """Send one length-prefixed JSON message to stdout."""
    payload = json.dumps(msg).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("=I", len(payload)))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def run_update():
    """Run update_extension.py and return success, message."""
    if not os.path.isfile(UPDATER_SCRIPT):
        return False, "update_extension.py not found next to native_host folder"
    try:
        result = subprocess.run(
            [sys.executable, UPDATER_SCRIPT],
            cwd=UPDATER_DIR,
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode == 0:
            return True, (result.stdout or "").strip() or "Update complete. Reload the extension in chrome://extensions"
        return False, (result.stderr or result.stdout or f"Exit code {result.returncode}").strip()
    except subprocess.TimeoutExpired:
        return False, "Update timed out"
    except Exception as e:
        return False, str(e)


def main():
    try:
        msg = read_message()
        if msg is None:
            return
        action = (msg.get("action") or "").strip().lower()
        if action == "run_update":
            success, message = run_update()
            send_message({"success": success, "message": message})
        else:
            send_message({"success": False, "message": f"Unknown action: {action}"})
    except Exception as e:
        send_message({"success": False, "message": str(e)})


if __name__ == "__main__":
    main()
