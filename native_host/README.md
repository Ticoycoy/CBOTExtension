# Native messaging host (Update button)

One-time setup so the extension popup **Update** button can run the updater.

## Default execution: PowerShell only (no Python)

On **Windows**, the native host uses **PowerShell by default**. Clients do **not** need Python installed.

- **Windows**: `run_host.bat` launches `native_host.ps1`, which then runs `update_extension.ps1`. All of this uses only PowerShell (built into Windows 10/11). No Node.js or Python required.
- The host and updater are PowerShell scripts only; Python is not used.

## One-time install — Windows

1. **Config (repo_url required)** — In this **native_host** folder, create `updater_config.json` with your “Load unpacked” folder path. Copy from `updater_config.json.example` (in this folder) and set `target_path`. On the client you only need the **native_host** and **public** folders — no files in the project root. **Use double backslashes** in the path (required by JSON), e.g.:
   ```json
   {"target_path":"D:\\Auto\\cb-phExtension\\public"}
   ```
   **Flow:** Update downloads the repo zip from GitHub, extracts it, and copies the configured folder (e.g. `public`) to `target_path`. No git required. Single backslashes like `D:\Auto\...` will cause “Unrecognized escape sequence” errors.

2. Open PowerShell in this `native_host` folder and run:
   ```powershell
   .\install_native_host.ps1
   ```
   **If you get "running scripts is disabled"**, run this instead (bypasses policy for this run only):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install_native_host.ps1
   ```
3. Enter your **Extension ID** (from `chrome://extensions`, with Developer mode on).
4. Confirm the path to `run_host.bat` (default is this folder).
5. Reload the extension and use the Update button.

To allow scripts permanently for your user (optional):
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## Permissions on the client (no admin required)

- **No administrator rights** — The installer writes to **current user** registry (`HKCU:\Software\Google\Chrome\...`) and to the `native_host` folder. No elevation or admin rights are needed.
- **PowerShell execution policy** — You do **not** need to change system policy. Use `powershell -ExecutionPolicy Bypass -File .\install_native_host.ps1` (and `run_host.bat` already uses Bypass when calling `native_host.ps1`). That applies only to that process.
- **Write access** — The user running the updater must be able to **write** to: (1) the project folder (e.g. `native_host` for the log file), and (2) the extension folder (`target_path` in `updater_config.json`), so the updater can copy files there. Normal user permissions are enough.

## After setup

- **Windows**: The script registers the host in the registry. Clicking **Update** runs `run_host.bat` → `native_host.ps1` → `native_host\update_extension.ps1`, which **downloads the repo from GitHub** (repo_url), extracts it, and copies the configured folder (e.g. `public`) to `target_path`. No git required — PowerShell only. The client only needs the **native_host** folder (with config and scripts); the extension folder is updated from GitHub.
- **macOS/Linux**: Copy the generated `com.cbph.autofill.updater.json` to Chrome’s native messaging host path (see [Chrome docs](https://developer.chrome.com/docs/apps/nativeMessaging/#native-messaging-host-location)). A shell equivalent of the host/updater would be needed.

---

## "Error when communicating with the native messaging host" (client machine)

This error on a **client machine** (while it works on your dev machine) usually means the native host is not set up correctly **on that machine**.

**First: run the diagnostic script on the client** (in the `native_host` folder):
```powershell
powershell -ExecutionPolicy Bypass -File .\check_native_host.ps1
```
It checks: registry, manifest path, whether `run_host.bat` exists and uses PowerShell (not Python), and that `update_extension.ps1` exists. Fix any **[FAIL]** items it reports.

Then do the following **on the client**:

1. **Install the host on the client**
   - Do **not** rely on copying the extension folder alone. On **each** machine where you use the extension, run the installer once:
   - Open PowerShell in the **native_host** folder (e.g. `D:\Auto\cb-phExtension\native_host`) and run:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\install_native_host.ps1
     ```

2. **Use that machine's Extension ID**
   - On the client, open `chrome://extensions`, enable **Developer mode**, and copy the **Extension ID** shown for this extension.
   - Unpacked extensions get a **different ID on each machine**. When you run the installer on the client, enter **this** ID (the one shown on the client), not the ID from your dev machine.

3. **Confirm the path to run_host.bat**
   - When the installer asks for the path to `run_host.bat`, use the path **on the client** (e.g. `D:\Auto\cb-phExtension\native_host\run_host.bat`). Press Enter to accept the default if the installer is run from the native_host folder.

4. **No Python required**
   - `run_host.bat` must call **PowerShell**, not Python. If your copy still has `python ... native_host.py`, replace it with the version that runs `powershell ... native_host.ps1` (see this repo's `run_host.bat`). Then run the installer again on the client so the manifest path is correct.

5. **Reload and test**
   - Reload the extension on the client, then click **Update** again.

If it still fails, check that `run_host.bat` exists at the path stored in `com.cbph.autofill.updater.json` on the client, and that `native_host.ps1` is in the same folder as `run_host.bat`. After clicking Update, look for **native_host_log.txt** in the `native_host` folder on the client — the host writes errors there so you can see what failed.

---

## "Invalid updater_config.json: Unrecognized escape sequence"

This means the path in `updater_config.json` uses **single backslashes**. In JSON, every backslash must be **doubled**.

- **Wrong:** `{"target_path":"D:\Auto\cb-phExtension\public"}`
- **Right:** `{"target_path":"D:\\Auto\\cb-phExtension\\public"}`

Edit `updater_config.json` in the **native_host** folder and change the path so each `\` is written as `\\`. Then run Update again.
