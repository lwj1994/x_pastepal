# Local backups and CloudKit setup

XPastepal keeps its clipboard library on the Mac and supports independent local
backup snapshots. CloudKit synchronization adds another device's changes to that
library. Synchronization is not a versioned backup: deletions and edits propagate
to other devices, so keep local backups enabled.

This is an independent implementation. It does not connect to PastePal's
container, read its private database, or promise binary compatibility with
PastePal backups. PastePal's observed design uses Core Data with CloudKit and
optional image storage in iCloud Drive. XPastepal uses explicit CloudKit records
with JSON assets instead.

## Default local build

```sh
./scripts/build.sh
open dist/XPastepal.app
```

This build uses ad-hoc signing and leaves iCloud disabled. Before constructing a
CloudKit container, the app checks its actual signed entitlements using Security's
`SecTaskCopyValueForEntitlement`, its signing flags, application identity,
container, environment, and embedded provisioning profile. Running the plain Swift
executable or an ad-hoc app must show a configuration message instead of invoking
CloudKit without authorization.

## Apple developer configuration

1. In your own Apple Developer account, register the explicit macOS App ID
   `milu.pastepal`, enable iCloud with CloudKit, and associate a container you own.
   The default container name is `iCloud.milu.pastepal`; if that identifier is
   unavailable, create another owned container and use `ICLOUD_CONTAINER_ID`.
2. Generate a macOS provisioning profile for this exact App ID and container.
   Select the signing certificate installed in your keychain. A profile for
   another app, even one on the same team, cannot authorize this app.
3. Download the profile. For development builds, ensure that both test Macs are
   registered if the profile restricts eligible devices. Sign both builds with
   the same container and CloudKit environment.
4. Build with both signing inputs explicitly supplied:

   ```sh
   CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" \
   ICLOUD_PROVISION_PROFILE="/absolute/path/XPastepal.provisionprofile" \
   ICLOUD_CONTAINER_ID="iCloud.milu.pastepal" \
   ICLOUD_ENVIRONMENT="Development" \
   ./scripts/build.sh
   ```

   The script verifies the profile's platform, expiration, explicit App ID,
   container, service, and environment; embeds the profile; and checks that the
   actual signing certificate is present in the profile. It never substitutes a
   different app's profile. Supplying only one signing input fails the build.
5. Launch the signed app, sign in to the same iCloud account on both Macs, and
   enable synchronization in the app. Device-specific preferences are local.

The source entitlements file is a template. The build script derives application
and team identity from the validated profile, selects the authorized container
and environment, and writes the container identifier into the built Info.plist.
Do not manually add CloudKit entitlements to an ad-hoc build.

## Database and conflict behavior

- Database: the current user's private CloudKit database.
- Custom zone: `XPastepal`.
- Record type: `SyncEntry`.
- Record fields: `schemaVersion` (`Int64`, currently `1`) and `payload` (`Asset`).
- Record names: entity kind, a hyphen, and the entity UUID.
- Payloads contain the item's or collection's synchronization stamp and value.
  Deleted entities remain as tombstones so an offline device cannot reintroduce
  an old copy merely by reconnecting.
- The first round fetches the whole zone, starting from a nil change token and
  following every page. Later rounds use an in-memory token and complete snapshot
  to download only changes while still returning the complete remote library for
  merging. Snapshot and token advance together only after all pages succeed.
  Neither is persisted; an app restart or expired token starts a fresh full fetch.
- Uploads use the fetched record's change tag and
  `ifServerRecordUnchanged`, with at most 100 records per atomic batch.
  A concurrent server update fails the upload, requiring a fresh fetch and merge;
  the transport never silently overwrites the server.
- CloudKit errors are preserved for the coordinator, including retry-after
  information. A corrupt or unsupported payload fails the round instead of
  pretending that record is absent.
- Safety limits are 256 MiB for the complete encoded remote library and 100,000
  records. JSON base64 encoding makes embedded images larger than their original
  files. Temporary upload and downloaded asset files are removed after use.

File clipboard entries remain local because their paths are specific to a Mac.
Images embedded in clipboard entries are included in the JSON asset. This does
not provide a general iCloud Drive file mirror.

CloudKit changes are eventually consistent. This implementation checks for changes
every minute while the app runs and supports manual synchronization; it does not
install a background push subscription.
Devices must run XPastepal to exchange changes. Network failures leave the local
library available.

## Production deployment

Development and Production are separate CloudKit databases. Test data does not
move between them automatically.

After a Development build creates the `SyncEntry` record type and its fields,
inspect them in CloudKit Console. Deploy that schema to Production before
distributing a Production build. No query indexes are required by the zone-change
fetch API used here. Use a distribution signing identity and a compatible macOS
profile with `ICLOUD_ENVIRONMENT=Production`. Sign and notarize a distributed
Developer ID build according to Apple's distribution requirements; this script
does not notarize or submit an app.

## Two-Mac acceptance checklist

Use a small disposable library and keep a local backup before testing:

1. Confirm an ad-hoc app cannot enable iCloud and remains usable locally.
2. On Mac A, add text and an image, create a collection, assign the item, and pin
   it. Synchronize A, then B; compare the values and image content.
3. Edit the same item independently while the Macs are offline. Reconnect and
   synchronize both repeatedly. Confirm both converge and no items disappear.
4. Delete an item on A while B is offline. Synchronize A, then B, then A again.
   The old item must not reappear.
5. Interrupt an upload or disconnect the network. Confirm the error is visible,
   local capture still works, and retry converges without duplicate UUIDs.
6. Change or sign out of the iCloud account. Confirm the app detects the account
   boundary and does not silently upload the previous account's library.
7. Restore a local backup, synchronize, and inspect the result on both devices.
8. Repeat with a Production build after schema deployment.

Local compilation, unsigned-mode checks, and simulated transport tests do not
prove Apple account access or cross-device convergence. Complete this checklist
with valid signing and real devices before claiming iCloud validation.

## Apple references

- [Enabling CloudKit in your app](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app)
- [Fetching record zone changes](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation)
- [Saving only when the server record is unchanged](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/ifserverrecordunchanged)
- [Deploying the schema to production](https://developer.apple.com/documentation/cloudkit/deploying-the-schema-to-production)
