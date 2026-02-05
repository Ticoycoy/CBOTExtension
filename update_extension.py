#!/usr/bin/env python3
"""
Extension updater: downloads the repo from GitHub and copies the public/ folder
to your local "Load unpacked" path. No git or Node.js required on the client.

Usage:
  1. Edit updater_config.json: set repo_url (and optionally branch, target_path).
  2. Run: python update_extension.py

target_path: If omitted or empty, defaults to the "public" folder next to this
script (e.g. C:\\Dev\\extension-app\\public when the script is in C:\\Dev\\extension-app).
Set target_path only if your "Load unpacked" folder is elsewhere.

After running, reload the extension in chrome://extensions.
"""

import json
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile

# Default config (overridden by updater_config.json if present)
# target_path empty = use "public" folder next to this script (dynamic)
DEFAULT_CONFIG = {
    "repo_url": "https://github.com/Ticoycoy/CBOTExtension.git",
    "branch": "main",
    "target_path": "",
}

CONFIG_FILENAME = "updater_config.json"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def load_config():
    """Load config from updater_config.json next to this script, else use defaults."""
    config_path = os.path.join(SCRIPT_DIR, CONFIG_FILENAME)
    if os.path.isfile(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                return {**DEFAULT_CONFIG, **cfg}
        except (json.JSONDecodeError, IOError) as e:
            print(f"Warning: could not read {CONFIG_FILENAME}: {e}. Using defaults.")
    return DEFAULT_CONFIG.copy()


def parse_repo_url(repo_url):
    """
    Parse GitHub repo URL to owner and repo name.
    Supports: https://github.com/owner/repo, https://github.com/owner/repo/, git@github.com:owner/repo.git
    """
    s = (repo_url or "").strip().rstrip("/")
    if "github.com" in s:
        if s.startswith("https://github.com/") or s.startswith("http://github.com/"):
            parts = s.replace("http://", "").replace("https://", "").split("github.com/")[-1].split("/")
            if len(parts) >= 2:
                return parts[0], parts[1].replace(".git", "")
        if "git@github.com:" in s:
            part = s.split("git@github.com:")[-1].replace(".git", "")
            if "/" in part:
                owner, repo = part.split("/", 1)
                return owner, repo
    return None, None


def download_repo_zip(owner, repo, branch):
    """Download repo as zip from GitHub. Returns path to downloaded zip file."""
    url = f"https://github.com/{owner}/{repo}/archive/refs/heads/{branch}.zip"
    print(f"Downloading: {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "ExtensionUpdater/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
    tmp.write(data)
    tmp.close()
    return tmp.name


def copy_public_to_target(archive_dir, target_path):
    """
    Copy contents of archive_dir/public/ to target_path.
    archive_dir is the extracted root (e.g. repo-main/). We look for public/ inside it.
    """
    # GitHub zip extracts to repo-branch/ so we have one top-level folder
    entries = os.listdir(archive_dir)
    public_src = None
    if "public" in entries:
        public_src = os.path.join(archive_dir, "public")
    else:
        # Maybe archive root is the only folder (repo-main)
        for name in entries:
            full = os.path.join(archive_dir, name)
            if os.path.isdir(full):
                inner_public = os.path.join(full, "public")
                if os.path.isdir(inner_public):
                    public_src = inner_public
                    break
        if public_src is None and len(entries) == 1:
            only = os.path.join(archive_dir, entries[0])
            if os.path.isdir(only) and "public" in os.listdir(only):
                public_src = os.path.join(only, "public")
    if not public_src or not os.path.isdir(public_src):
        raise FileNotFoundError(
            f"No 'public' folder found in downloaded repo. Check that the repo contains a 'public/' folder. "
            f"Contents: {entries}"
        )
    os.makedirs(target_path, exist_ok=True)
    for name in os.listdir(public_src):
        src_item = os.path.join(public_src, name)
        dst_item = os.path.join(target_path, name)
        if os.path.isdir(src_item):
            if os.path.isdir(dst_item):
                shutil.rmtree(dst_item, ignore_errors=True)
            shutil.copytree(src_item, dst_item)
        else:
            shutil.copy2(src_item, dst_item)
    print(f"Copied public/ contents to: {target_path}")


def main():
    config = load_config()
    repo_url = config.get("repo_url", "").strip()
    branch = (config.get("branch") or "main").strip()
    target_path = (config.get("target_path") or "").strip()

    if not repo_url or "YOUR_USERNAME" in repo_url or "YOUR_REPO" in repo_url:
        print("Please edit updater_config.json and set repo_url to your GitHub repo (e.g. https://github.com/username/repo)")
        sys.exit(1)
    # If target_path not set: use "public" folder next to this script (where user chose to place the project)
    if not target_path:
        target_path = os.path.join(SCRIPT_DIR, "public")
        print(f"Using target_path (extension folder): {target_path}")
    else:
        target_path = os.path.expanduser(target_path)
    owner, repo = parse_repo_url(repo_url)
    if not owner or not repo:
        print(f"Could not parse repo from: {repo_url}. Use https://github.com/owner/repo")
        sys.exit(1)

    zip_path = None
    extract_dir = None
    try:
        zip_path = download_repo_zip(owner, repo, branch)
        extract_dir = tempfile.mkdtemp()
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(extract_dir)
        copy_public_to_target(extract_dir, target_path)
        print("Update complete. Reload the extension in chrome://extensions")
    except urllib.request.HTTPError as e:
        print(f"Download failed ({e.code}): {e.reason}. Check repo_url and branch.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    finally:
        if zip_path and os.path.isfile(zip_path):
            try:
                os.unlink(zip_path)
            except OSError:
                pass
        if extract_dir and os.path.isdir(extract_dir):
            try:
                shutil.rmtree(extract_dir, ignore_errors=True)
            except OSError:
                pass


if __name__ == "__main__":
    main()
