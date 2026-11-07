#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
source "$ROOT/modules/rustdesk/rustdesk.sh"
for good in rd.example.com rd.example.com:21116 127.0.0.1:21117 '[::1]:21116' my-server.local:443; do
  hdm_rustdesk_endpoint_valid "$good" || { echo "Expected accepted: $good"; exit 1; }
done
for bad in '' 'http://example.com' 'a:99999' 'a:0' 'a:123456' '-host.example.com' 'host..example.com' 'host.example.com:' 'host;rm -rf /' 'a/b' 'a b'; do
  if hdm_rustdesk_endpoint_valid "$bad"; then echo "Expected rejected: $bad"; exit 1; fi
done
echo 'PASS RustDesk endpoint allowlist and port bounds'
