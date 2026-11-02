#!/bin/zsh
# 正式发布：Developer ID 签名 + hardened runtime + 公证，产出已装订票据的 DMG。
#   DEVELOPER_ID_IDENTITY  签名证书（SHA-1 或名称），默认取钥匙串中第一个 Developer ID Application
#   NOTARY_PROFILE         `xcrun notarytool store-credentials` 保存的配置名，默认 notary
# 未设置 ICLOUD_PROVISION_PROFILE 时产物不含 iCloud 能力，与本地构建一致。
# 用法：./scripts/release.sh [--publish 更新说明.md]
#   --publish 把 DMG 发布到 GitHub Release（标签 v<版本>）；App 的自动更新从最新 Release 读取。
set -euo pipefail
cd "${0:A:h:h}"

publish=false
notes_file=""
if [[ "${1:-}" == "--publish" ]]; then
  publish=true
  notes_file="${2:-}"
  if [[ -z "$notes_file" || ! -f "$notes_file" ]]; then
    print -u2 -r -- "发布需要提供更新说明文件：./scripts/release.sh --publish notes.md"
    exit 1
  fi
fi

identity="${DEVELOPER_ID_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | awk '/"Developer ID Application: / { print $2; exit }')}"
notary_profile="${NOTARY_PROFILE:-notary}"
if [[ -z "$identity" ]]; then
  print -u2 -r -- "未找到 Developer ID Application 证书，可用 DEVELOPER_ID_IDENTITY 指定。"
  exit 1
fi
if ! xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null 2>&1; then
  print -u2 -r -- "公证凭据 $notary_profile 不可用，请先运行 xcrun notarytool store-credentials $notary_profile。"
  exit 1
fi

if [[ -n "${ICLOUD_PROVISION_PROFILE:-}" ]]; then
  CODE_SIGN_IDENTITY="$identity" ./scripts/build.sh
else
  ./scripts/build.sh
fi

APP="$PWD/dist/XPastepal.app"
# build.sh 只给本地运行签名；带 iCloud 时保留它写入的 entitlements。
sign_args=(--force --options runtime --timestamp --sign "$identity")
if [[ -n "${ICLOUD_PROVISION_PROFILE:-}" ]]; then sign_args+=(--preserve-metadata=entitlements); fi
codesign "${sign_args[@]}" "$APP"
codesign --verify --deep --strict "$APP"
signature_info="$(codesign -dv "$APP" 2>&1)"
[[ "$signature_info" == *"(runtime)"* ]] || { print -u2 -r -- "签名缺少 hardened runtime。"; exit 1 }

version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="$PWD/dist/XPastepal-$version.dmg"
staging="$(mktemp -d "${TMPDIR:-/tmp}/xpastepal-dmg.XXXXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$APP" "$staging/XPastepal.app"
ln -s /Applications "$staging/Applications"
rm -f "$DMG"
hdiutil create -volname "XPastepal $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --timestamp --sign "$identity" "$DMG"

print -r -- "提交公证：${DMG:t}"
submission="$(xcrun notarytool submit "$DMG" --keychain-profile "$notary_profile" --wait --output-format json)"
submission_id="$(print -r -- "$submission" | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')"
submission_status="$(print -r -- "$submission" | python3 -c 'import json, sys; print(json.load(sys.stdin)["status"])')"
if [[ "$submission_status" != "Accepted" ]]; then
  xcrun notarytool log "$submission_id" --keychain-profile "$notary_profile" >&2 || true
  print -u2 -r -- "公证未通过（$submission_status）：$submission_id"
  exit 1
fi
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"
print -r -- "发布包：$DMG"

if [[ "$publish" == true ]]; then
  tag="v$version"
  if [[ -n "$(git status --porcelain)" ]]; then
    print -u2 -r -- "工作区有未提交的改动，请先提交再发布。"
    exit 1
  fi
  git push origin HEAD
  gh release create "$tag" "$DMG" --target "$(git rev-parse HEAD)" --title "XPastepal $tag" --notes-file "$notes_file"
  print -r -- "已发布：$(gh release view "$tag" --json url --jq .url)"
fi
