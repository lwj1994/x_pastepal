#!/bin/sh
# 对同一 arm64 切片执行已定位函数的定向反编译，不执行 PastePal。
set -eu
analysis_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$analysis_directory/env.sh"
temporary_project=$(mktemp -d /tmp/xpastepal-ghidra-targeted.XXXXXX)
trap 'rmdir "$temporary_project" 2>/dev/null || true' EXIT
"$GHIDRA_INSTALL_DIR/support/analyzeHeadless" "$temporary_project" pastepal-targeted \
  -import /Users/luwenjie/.rea/targets/pastepal-ecc6c102/PastePal.arm64 \
  -noanalysis -readOnly -deleteProject \
  -scriptPath "$analysis_directory" \
  -postScript TargetedDecompile.java "$analysis_directory/targeted-pseudocode"
