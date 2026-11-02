#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Local builds deliberately carry no iCloud entitlements. CloudKit requires both
# a real signing identity and a provisioning profile for this exact application.
cloud_signing=false
if [[ -n "${CODE_SIGN_IDENTITY:-}" || -n "${ICLOUD_PROVISION_PROFILE:-}" ]]; then
  if [[ -z "${CODE_SIGN_IDENTITY:-}" || -z "${ICLOUD_PROVISION_PROFILE:-}" || "${CODE_SIGN_IDENTITY:-}" == "-" ]]; then
    print -u2 -r -- "Cloud signing requires CODE_SIGN_IDENTITY and ICLOUD_PROVISION_PROFILE together."
    exit 1
  fi
  if [[ ! -f "$ICLOUD_PROVISION_PROFILE" ]]; then
    print -u2 -r -- "The specified iCloud provisioning profile does not exist."
    exit 1
  fi
  cloud_signing=true
fi

BUILD_SIGNING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xpastepal-signing.XXXXXXXX")"
trap 'rm -rf "$BUILD_SIGNING_DIR"' EXIT
if [[ "$cloud_signing" == true ]]; then
  security cms -D -i "$ICLOUD_PROVISION_PROFILE" > "$BUILD_SIGNING_DIR/profile.plist"
  python3 - "$BUILD_SIGNING_DIR" "${ICLOUD_CONTAINER_ID:-iCloud.milu.pastepal}" "${ICLOUD_ENVIRONMENT:-Development}" <<'PY'
import datetime
import pathlib
import plistlib
import sys

directory, container, environment = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
profile = plistlib.loads((directory / "profile.plist").read_bytes())
info = plistlib.loads(pathlib.Path("Resources/Info.plist").read_bytes())
allowed = profile.get("Entitlements", {})
bundle_id = info["CFBundleIdentifier"]
app_id = allowed.get("com.apple.application-identifier", "")
team_id = allowed.get("com.apple.developer.team-identifier", "")

def require(condition, message):
    if not condition:
        raise SystemExit(message)

require("OSX" in profile.get("Platform", []), "The provisioning profile must support macOS.")
expires = profile.get("ExpirationDate")
require(isinstance(expires, datetime.datetime) and expires > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),
        "The provisioning profile is expired or has no expiration date.")
require(team_id and app_id.endswith("." + bundle_id) and "*" not in app_id,
        "The provisioning profile must match this app's explicit bundle identifier.")
require(container.startswith("iCloud.") and container in allowed.get("com.apple.developer.icloud-container-identifiers", []),
        "The selected container is not authorized by this provisioning profile.")
services = allowed.get("com.apple.developer.icloud-services", [])
require(services == "*" or "CloudKit" in services, "The provisioning profile does not enable CloudKit.")
environments = allowed.get("com.apple.developer.icloud-container-environment", [])
require(environment in ("Development", "Production") and
        (environments == environment or environment in environments),
        "The provisioning profile does not authorize the requested CloudKit environment.")
require(profile.get("DeveloperCertificates"), "The provisioning profile has no signing certificates.")

entitlements = plistlib.loads(pathlib.Path("Resources/XPastepal.entitlements").read_bytes())
entitlements["com.apple.application-identifier"] = app_id
entitlements["com.apple.developer.team-identifier"] = team_id
entitlements["com.apple.developer.icloud-container-identifiers"] = [container]
entitlements["com.apple.developer.icloud-container-environment"] = environment
(directory / "entitlements.plist").write_bytes(plistlib.dumps(entitlements))
info["XPastepalCloudKitContainerIdentifier"] = container
(directory / "Info.plist").write_bytes(plistlib.dumps(info))
PY
fi

swift build -c release
APP="$PWD/dist/XPastepal.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/XPastepal "$APP/Contents/MacOS/XPastepal"
cp Resources/Info.plist "$APP/Contents/Info.plist"
for resource_bundle in .build/release/*.bundle(N); do
  ditto "$resource_bundle" "$APP/Contents/Resources/${resource_bundle:t}"
done
if [[ -f THIRD_PARTY_NOTICES.md ]]; then
  cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
fi
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
if [[ "$cloud_signing" == true ]]; then
  cp "$BUILD_SIGNING_DIR/Info.plist" "$APP/Contents/Info.plist"
  cp "$ICLOUD_PROVISION_PROFILE" "$APP/Contents/embedded.provisionprofile"
  codesign --force --options runtime --sign "$CODE_SIGN_IDENTITY" \
    --entitlements "$BUILD_SIGNING_DIR/entitlements.plist" "$APP"
  codesign --verify --deep --strict "$APP"
  codesign --display --extract-certificates="$BUILD_SIGNING_DIR/signer" "$APP" 2>/dev/null
  python3 - "$BUILD_SIGNING_DIR" <<'PY'
import hashlib
import pathlib
import plistlib
import sys

directory = pathlib.Path(sys.argv[1])
profile = plistlib.loads((directory / "profile.plist").read_bytes())
signer = (directory / "signer0").read_bytes()
if not any(hashlib.sha256(cert).digest() == hashlib.sha256(signer).digest()
           for cert in profile.get("DeveloperCertificates", [])):
    raise SystemExit("The signing certificate is not authorized by the provisioning profile. Do not run this build.")
PY
  print -r -- "CloudKit signing configured (${ICLOUD_ENVIRONMENT:-Development})."
else
  rm -f "$APP/Contents/embedded.provisionprofile"
  # ad-hoc 签名按 cdhash 识别，每次构建都会让辅助功能授权失效；有开发证书时改用固定证书签名。
  local_identity="${LOCAL_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
    | awk '/"Apple Development: / { print $2; exit }')}"
  if [[ -n "$local_identity" && "$local_identity" != "-" ]]; then
    codesign --force --sign "$local_identity" "$APP"
    print -r -- "本地签名：$local_identity"
  else
    codesign --force --sign - "$APP"
    print -r -- "未找到开发证书，使用 ad-hoc 签名；重新构建后需在辅助功能列表中重新加入应用。"
  fi
fi
print -r -- "构建完成：$APP"
