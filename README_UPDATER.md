# Extension updater (Python)

This folder contains a Python script that updates the browser extension on your machine by pulling the latest **public/** folder from a GitHub repo and copying it to your "Load unpacked" folder.

## What you need to provide

1. **GitHub repo URL**  
   The repo that contains the **public/** folder and this updater (e.g. `https://github.com/your-username/extension-repo`).

2. **Branch**  
   Usually `main` or `master`.

3. **Target path** (optional)  
   The folder where you load the extension in Chrome (the "Load unpacked" folder).  
   If you **leave it empty or omit it**, the script uses the **public** folder next to itself (e.g. if the script is in `C:\Dev\extension-app`, it updates `C:\Dev\extension-app\public`). Set it only if your extension is loaded from a different folder.

## One-time setup

1. Edit **updater_config.json** next to this script:
   - Set **repo_url** to your GitHub repo URL.
   - Set **branch** (e.g. `main`).
   - Set **target_path** only if your "Load unpacked" folder is not the **public** folder next to the script (otherwise leave it empty).

2. Ensure Python 3 is installed (no pip packages required).

## How to run

**Option A – From the extension popup (recommended after one-time setup)**  
1. Do the **Native host one-time setup** below once per machine.  
2. In the extension popup, click the **download icon** (Update) in the footer.  
3. The updater runs; when it finishes, reload the extension in **chrome://extensions**.

**Option B – Manually**  
From a terminal, in the folder that contains `update_extension.py`:

```bash
python update_extension.py
```

Or double-click `update_extension.py` if Python is associated with `.py` files.

After it finishes, open **chrome://extensions** and click **Reload** on the extension.

---

## Native host one-time setup (for popup Update button)

So the **Update** button in the extension popup can run the updater without opening a terminal:

1. **Load the extension** in Chrome (Load unpacked). Note the **Extension ID** from **chrome://extensions** (enable "Developer mode" to see it).

2. **Run the installer** once per machine, in the folder that contains `native_host`:
   ```bash
   cd native_host
   python install_native_host.py
   ```
   When prompted:
   - **Extension ID**: paste the ID from chrome://extensions (e.g. `abcdefghijklmnopqrstuvwxyz123456`).
   - **Path to run_host.bat**: press Enter to use the default, or type the full path to `run_host.bat` (e.g. `C:\Dev\extension-app\native_host\run_host.bat`).

3. The script writes `com.cbph.autofill.updater.json` and (on Windows) registers it in the registry. After that, the **Update** button in the popup will trigger the native host, which runs `update_extension.py`.

4. **Requirements**: Python 3 and `updater_config.json` with at least **repo_url** (branch and target_path are optional; target_path defaults to the **public** folder next to the script). The `native_host` folder must sit next to `update_extension.py` (e.g. `extension-app/update_extension.py` and `extension-app/native_host/`).

---

## Repo layout on GitHub

The repo you push should look like:

- **public/** — all extension files (manifest.json, content.js, background.js, static/, etc.)
- **update_extension.py** — this updater script
- **updater_config.json** — config (you can omit from repo and create on each client with their own target_path)
- **native_host/** — for the popup Update button (optional):
  - **native_host.py** — native messaging host
  - **run_host.bat** — launcher for the host
  - **com.cbph.autofill.updater.json.template** — template for the host manifest
  - **install_native_host.py** — one-time registration script
- **README_UPDATER.md** — this file (optional)

Clients run the script (or use the popup Update button after native host setup); it downloads the repo zip, extracts it, and copies **public/** into **target_path**.
