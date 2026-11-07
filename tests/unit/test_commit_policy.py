#!/usr/bin/env python3
"""Unit tests for HDM commit-message formatting constraints."""
from __future__ import annotations
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('commit_policy', root / 'scripts/check-commit-messages.py')
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

for message in [
    'v0.1.1 修复 Windows PowerShell 上传脚本乱码并加入版本规范',
    'v2.0.0 Add integration tests for Xorg Dummy installer',
    'v0.1.1 首次导入 HDM 源码并改进版本提交规范',
]:
    assert mod.valid(message)[0], message
for message in [
    'Initial HDM implementation v0.1.0',
    'v0.1.1 修复xxx',
    'v0.1.1 日常更新',
    'v0.1.1',
    'v0.1.1 Fix bugs',
    'Update files',
    'fix: uploaded source',
]:
    assert not mod.valid(message)[0], message
print('PASS commit policy unit tests')
