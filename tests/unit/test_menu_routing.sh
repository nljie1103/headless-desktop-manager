#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
# Verify route labels and exact independent handlers, preventing silent regressions.
python3 - "$ROOT" <<'PY'
import sys, pathlib, re
root=pathlib.Path(sys.argv[1]); actions=(root/'ui/actions.sh').read_text(); menus=(root/'ui/menus.tsv').read_text()
for item,handler in [('2.1.1','hdm_display_packages_report'),('2.1.2','hdm_display_session_report'),('2.1.3','hdm_display_modes_report'),('4.5.1','hdm_session_report'),('4.5.2','hdm_session_protocol_report'),('4.5.3','hdm_session_service_report'),('4.5.4','hdm_session_user_report'),('4.5.5','hdm_session_start_gdm'),('4.5.6','hdm_session_logs'),('4.5.7','hdm_session_dependencies'),('4.5.8','hdm_session_enable_graphical_boot'),('4.5.9','hdm_session_repair'),('10.8.7','hdm_diag_export_full'),('10.8.9','hdm_diag_operation_list')]:
    assert re.search(r'(?m)^\s*'+re.escape(item)+r'\)\s*'+re.escape(handler)+r'\s*;;', actions), (item,handler)
    assert any(line.endswith('|'+item) for line in menus.splitlines()), item
assert 'hvm_unavailable' not in actions
PY
# Do not mistake installed Xorg Dummy for an active graphical user session.
grep -Fq '活动图形用户会话' "$ROOT/modules/display/display.sh"
grep -Fq 'sudo hdm --session-start' "$ROOT/modules/desktop/session.sh"
echo 'PASS menu routes match declared actions and diagnostic type'
