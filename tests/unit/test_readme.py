"""README and compatibility contract checks for the current public version.

This is a structural QA guard; it cannot assert GUI/remote behavior.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
version = (root / "VERSION").read_text(encoding="utf-8").strip()
cn = (root / "README.md").read_text(encoding="utf-8")
en = (root / "README.en.md").read_text(encoding="utf-8")
arm = (root / "docs/ubuntu26-arm64.md").read_text(encoding="utf-8")
matrix = (root / "config/compatibility.tsv").read_text(encoding="utf-8")
menu = (root / "ui/menu.sh").read_text(encoding="utf-8")

assert int(version.split(".")[0]) >= 4, version
assert f"v{version}" in cn and f"v{version}" in en
assert len(re.findall(r"^# ", cn, flags=re.M)) == 1
assert cn.startswith('<div align="center">')
assert all(re.match(r"^##\s+\S", x) for x in cn.splitlines() if x.startswith("## "))
for term in ("快速开始", "项目结构", "数据存储", "兼容", "GNOME", "RustDesk", "XFCE + X11", "LightDM",
             "WaylandEnable=false", "锁屏", "登录界面", "x86_64", "ARM64"):
    assert term in cn, term
for term in ("Lock screen", "login", "WaylandEnable=false", "ARM64", "README.md"):
    assert term.lower() in en.lower(), term
assert "cannot open display: :0" in arm
assert "锁屏" in arm and "注销" in arm and "GDM" in arm
assert "HDM v%s" in menu and "hdm_menu_rule" in menu
platforms = [line for line in matrix.splitlines() if line.startswith("ubuntu\t")]
assert len(platforms) == 10, len(platforms)
assert len([line for line in platforms if "xfce-x11" in line]) == 3
assert cn.count("```") % 2 == 0, "Markdown code fences must be paired"
assert en.count("```") % 2 == 0, "English code fences must be paired"
# All relative README links should lead to existing repository resources.
for filename, data in (("README.md", cn), ("README.en.md", en), ("README.zh-CN.md",
    (root / "README.zh-CN.md").read_text(encoding="utf-8"))):
    for target in re.findall(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+[^)]*)?\)", data):
        if target.startswith(("https://", "http://", "mailto:", "#")):
            continue
        base = target.split("#", 1)[0]
        assert (root / base).exists(), (filename, target)
print("PASS JRS-style bilingual README, 10-path evidence matrix and local documentation links")
