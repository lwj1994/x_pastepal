# Backup and synchronization validation

Date: 2026-10-20 (Asia/Taipei).

## Automated checks

`swift test --skip ClipInteractionTests` completed successfully: the runner reported
53 tests across five suites; the existing opt-in panel profiling test was skipped.
The unrelated `ClipInteractionTests` fixture appeared during concurrent workspace
work and was excluded from this verification. An earlier unrestricted run exited
at that fixture without a final test summary, so it is not reported as a full pass.

The 21 new tests cover:

- Nine local snapshot cases: private permissions, round-trip content, interval
  gating, count/byte rotation, unrelated-file filtering, same-time names,
  clock rollback, invalid snapshots, and failed atomic writes.
- Twelve synchronization/integration cases: deterministic concurrent edits,
  two-store offline reconciliation, permanent deletion, persistence across restart,
  collection deletion, local-only file references, network/account errors, invalid
  remote payloads, fresh-ID recovery, corrupt-primary preservation, failed local
  persistence, cancellation during downloads/uploads, large legacy libraries,
  entitlement preflight, and nested CloudKit retry delays. Some tests cover
  multiple related cases.

The injected cloud transport uses temporary directories and named pasteboards.
It never reads the user's clipboard or contacts CloudKit.

`./scripts/build.sh` completed the Release build and generated
`dist/XPastepal.app` with local ad-hoc signing. `codesign --verify --deep --strict`,
`plutil -lint Resources/XPastepal.entitlements`, and `zsh -n scripts/build.sh`
all succeeded. The installed app was not replaced.

## Unverified external dependencies

The machine has Apple signing identities but no macOS provisioning profile for
`milu.pastepal`. A profile for another application is not usable for this app.
No Apple account, container, production schema or profile was created or changed.

Real cloud authentication, record-zone creation, schema deployment, asset transfer
and two-Mac convergence remain unverified. Follow `docs/iCloud-setup.md` using a
profile and CloudKit container owned by the app's developer. The default app build
keeps CloudKit unavailable and exposes the configuration reason in Settings.
