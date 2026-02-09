# Native messaging host (Update button)

One-time setup so the extension popup **Update** button can run the updater.

## No extra software required

- **Windows**: Uses **PowerShell only** (built into Windows 10/11). No Node.js or Python needed on the client.
- `run_host.bat` launches `native_host.ps1`; the host then runs `update_extension.ps1` to copy `public/` to your extension folder.

## One-time install — Windows

1. **Extension folder path** — Either:
   - **Preferred:** In the extension popup, set “Extension folder path” once (the folder you use for “Load unpacked”). It’s saved and sent with each Update, so no config file is needed.
   - **Or:** In the **project root**, create `updater_config.json` with that path (copy from `updater_config.json.example`) if you prefer not to set it in the popup.

2. Open PowerShell in this `native_host` folder and run:
   ```powershell
   .\install_native_host.ps1
   ```
3. Enter your **Extension ID** (from `chrome://extensions`, with Developer mode on).
4. Confirm the path to `run_host.bat` (default is this folder).
5. Reload the extension and use the Update button.

If PowerShell blocks the script:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## After setup

- **Windows**: The script registers the host in the registry. Clicking **Update** runs `run_host.bat` → `native_host.ps1` → `update_extension.ps1`, which copies `public/` to the path in `updater_config.json`.
- **macOS/Linux**: Copy the generated `com.cbph.autofill.updater.json` to Chrome’s native messaging host path (see [Chrome docs](https://developer.chrome.com/docs/apps/nativeMessaging/#native-messaging-host-location)). A shell equivalent of the host/updater would be needed.
