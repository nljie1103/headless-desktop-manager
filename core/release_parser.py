#!/usr/bin/env python3
"""GitHub Release metadata parser. Emits only digest-verified, compatible assets."""
import json
import re
import sys
from urllib.parse import urlsplit


def semver(tag):
    m = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", tag)
    return tuple(map(int, m.groups())) if m else None


def main():
    repo, mode, arch, filename = sys.argv[1:]
    with open(filename, encoding="utf-8") as file:
        payload = json.load(file)
    releases = payload if isinstance(payload, list) else [payload]
    candidates = []
    for release in releases:
        tag = str(release.get("tag_name", ""))
        version = semver(tag)
        if not version or release.get("draft") or release.get("prerelease"):
            continue
        if repo == "hdm" and not tag.startswith("v"):
            continue
        for asset in release.get("assets", []):
            name = str(asset.get("name", ""))
            url = str(asset.get("browser_download_url", ""))
            digest = str(asset.get("digest", ""))
            valid = False
            if repo == "rustdesk":
                if arch == "x86_64":
                    valid = re.fullmatch(r"rustdesk-\d+\.\d+\.\d+-x86_64\.deb", name) is not None
                elif arch == "aarch64":
                    valid = re.fullmatch(r"rustdesk-\d+\.\d+\.\d+-aarch64\.deb", name) is not None
            else:
                valid = name == f"hdm-{tag}.tar.gz"
            parts = urlsplit(url)
            expected = "rustdesk/rustdesk" if repo == "rustdesk" else "nljie1103/headless-desktop-manager"
            if not (valid and parts.scheme == "https" and parts.netloc == "github.com"
                    and parts.path.startswith(f"/{expected}/releases/download/{tag}/")
                    and re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest)):
                continue
            candidates.append((version, tag, name, digest[7:].lower(), url))
    candidates.sort(reverse=True)
    for _, tag, name, digest, url in candidates[:1 if mode == 'latest' else 40]:
        print('\t'.join((tag, name, digest, url)))
    return 0 if candidates else 2


if __name__ == '__main__':
    raise SystemExit(main())
