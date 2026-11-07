#!/usr/bin/env python3
"""Read-only RustDesk TOML inspection. Never prints public keys or passwords."""
import argparse
from pathlib import Path
import sys
try:
    import tomllib
except ImportError:
    print("需要 Python 3.11+ 才能解析 RustDesk 配置", file=sys.stderr)
    raise SystemExit(2)

def load(path):
    try:
        with Path(path).open('rb') as f:
            return tomllib.load(f)
    except (FileNotFoundError, PermissionError, ValueError, tomllib.TOMLDecodeError):
        return None

def fields(config):
    config = config or {}
    opts = config.get('options', {})
    if not isinstance(opts, dict):
        opts = {}
    ident = opts.get('custom-rendezvous-server') or config.get('rendezvous_server') or ''
    relay = opts.get('relay-server') or config.get('relay-server') or ''
    key = opts.get('key') or config.get('key') or ''
    return tuple(str(v) if isinstance(v, str) else '' for v in (ident, relay, key))

def draft(path):
    result = {}
    try:
        for line in Path(path).read_text(encoding='utf-8').splitlines():
            if '\t' not in line: continue
            k,v=line.split('\t', 1)
            if k in ('id', 'relay', 'key'):
                result[k]=v
    except (FileNotFoundError, PermissionError):
        pass
    return result

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=('inspect','get-id','get-relay','verify','validate'))
    parser.add_argument('path')
    parser.add_argument('--draft')
    args=parser.parse_args()
    cfg=load(args.path)
    if cfg is None:
        if args.action=='inspect':
            print('配置文件：未找到或无法解析（不能确认导入生效）')
        return 2
    ident,relay,key=fields(cfg)
    if args.action=='inspect':
        print('配置文件：'+args.path)
        print('ID 服务器：'+(ident or '未找到'))
        print('中继服务器：'+(relay or '未找到'))
        print('服务器公钥：'+('存在（内容不显示）' if key else '未找到'))
        print('提示：文件内容并不能证明 RustDesk 服务已加载或成功注册。')
    elif args.action=='get-id':
        if not ident: return 2
        print(ident)
    elif args.action=='get-relay':
        if not relay: return 2
        print(relay)
    elif args.action=='validate':
        print('TOML 格式有效；ID：%s；Relay：%s；公钥：%s' % (bool(ident), bool(relay), bool(key)))
    elif args.action=='verify':
        expected=draft(args.draft or '')
        if not all(expected.get(k) for k in ('id','relay','key')): return 2
        if (ident,relay,key)==(expected['id'],expected['relay'],expected['key']):
            print('CLI 配置文件读回一致（但运行服务是否采用该文件仍待验证）')
        else:
            print('配置文件与本次输入不一致，无法确认保存成功',file=sys.stderr)
            return 1
    return 0

if __name__=='__main__':
    sys.exit(main())
