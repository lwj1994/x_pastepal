#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ "${1:-}" != "--skip-build" ]]; then ./scripts/build.sh; fi
source_app="$PWD/dist/XPastepal.app"
target_app="$HOME/Applications/XPastepal.app"
if pgrep -f "$target_app/Contents/MacOS/XPastepal" >/dev/null; then
  print -r -- "请先退出正在运行的 XPastepal，再安装更新。"
  exit 1
fi
launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
mkdir -p "$HOME/Applications"
if [[ -d "$target_app" ]]; then
  backup_root="$HOME/Library/Application Support/XPastepal/AppBackups"
  mkdir -p "$backup_root"
  "$launch_services" -u "$target_app" || true
  mv "$target_app" "$backup_root/XPastepal-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$source_app" "$target_app"
codesign --verify --deep --strict "$target_app"
"$launch_services" -f "$target_app"
print -r -- "已安装：$target_app"
