#!/usr/bin/env python3
"""
One-time setup: register the native messaging host so the extension popup
can trigger the updater. Run this once per machine after loading the extension.

Usage:
  python install_native_host.py

You will be prompted for:
  1. Extension ID - from chrome://extensions (enable Developer mode, copy ID under the extension)
  2. Path to this native_host folder - default is the folder containing this script
"""
import json
import os
import sys

HOST_NAME = "com.cbph.autofill.updater"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MANIFEST_FILENAME = HOST_NAME + ".json"
TEMPLATE = os.path.join(SCRIPT_DIR, MANIFEST_FILENAME + ".template")


def main():
    if not os.path.isfile(TEMPLATE):
        print("Template not found:", TEMPLATE)
        sys.exit(1)

    extension_id = input("Extension ID (from chrome://extensions): ").strip()
    if not extension_id:
        print("Extension ID is required.")
        sys.exit(1)

    default_path = os.path.join(SCRIPT_DIR, "run_host.bat")
    path_prompt = f"Full path to run_host.bat [{default_path}]: "
    path_input = input(path_prompt).strip() or default_path
    path_input = os.path.abspath(path_input)
    if not os.path.isfile(path_input):
        print("File not found:", path_input)
        sys.exit(1)

    with open(TEMPLATE, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    manifest["path"] = path_input
    manifest["allowed_origins"] = [f"chrome-extension://{extension_id}/"]

    manifest_path = os.path.join(SCRIPT_DIR, MANIFEST_FILENAME)
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print("Wrote:", manifest_path)

    if sys.platform == "win32":
        try:
            import winreg
            key_path = r"Software\Google\Chrome\NativeMessagingHosts\%s" % HOST_NAME
            key = winreg.CreateKeyEx(
                winreg.HKEY_CURRENT_USER,
                key_path,
                0,
                winreg.KEY_SET_VALUE,
            )
            winreg.SetValue(key, None, winreg.REG_SZ, manifest_path)
            winreg.CloseKey(key)
            print("Registered in Windows registry:", key_path)
        except ImportError:
            print("Could not import winreg. Register manually:")
            print("  HKEY_CURRENT_USER\\Software\\Google\\Chrome\\NativeMessagingHosts\\" + HOST_NAME)
            print("  Default value =", manifest_path)
        except Exception as e:
            print("Registry error:", e)
            print("Register manually:")
            print("  HKEY_CURRENT_USER\\Software\\Google\\Chrome\\NativeMessagingHosts\\" + HOST_NAME)
            print("  Default value =", manifest_path)
    else:
        print("For Chrome on macOS/Linux, copy the manifest to the expected path.")
        print("See: https://developer.chrome.com/docs/apps/nativeMessaging/#native-messaging-host-location")

    print("Done. You can now use the Update button in the extension popup.")


if __name__ == "__main__":
    main()
