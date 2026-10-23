# PastePal local persistence, backup, and iCloud synchronization

Investigation date: 2026-10-20, Asia/Taipei. Target: the installed PastePal 2.19.6 (214), bundle identifier `com.onmyway133.PastePal`. This is a read-only investigation of the shipped application and official documentation. No user clipboard database was opened, no target process was launched or injected, and no iCloud account data was changed.

## Result

The original uses a local Core Data store and optional Core Data/CloudKit mirroring for history. Copied image payloads have a separate iCloud Drive path and preference. Public documentation describes manual CSV export. This investigation does **not** establish that PastePal provides scheduled, versioned local backup archives.

The compatible product strategy is therefore: local operation first, optional account synchronization, separate treatment of image payloads, visible synchronization state, and explicit export/recovery. Scheduled local snapshots would be an independently designed addition, not a verified reproduction of PastePal behavior.

## Evidence and identity

| Evidence | Source and boundary |
| --- | --- |
| Original executable | `/Applications/PastePal.app/Contents/MacOS/PastePal`; SHA-256 `ecc6c102b1b66b89ce70e649e682fd2c0c0041207281b4c047faaf4b8771e547` |
| Existing arm64 analysis target | `/Users/luwenjie/.rea/targets/pastepal-ecc6c102/PastePal.arm64`; SHA-256 `7ee43a4a8437e805cfd1ddd7a6ce2242532fb9944e796997401864004185f317` |
| Prior REA Mach-O inventory | `rea/macho.json`, Evidence `ev_e8520b0ce545592ed3607df12023ba9c6e110cea4c142615001c2a20392f3589` |
| Current REA signature inspection | `rea/backup-sync-signature.json`, Evidence `ev_2d5aad556ee24b552b434df6e70bd90e92cffacdeaec12e32f40cea1559383d2` |
| REA/Ghidra container initialization | `rea/backup-sync-container-pseudocode.json`, function `0x10017d170`, Evidence `ev_c1b28c0c647177c32b64cd598f18269784e6fc48f9dc3c067e44a981ffbdab2a` |
| REA/Ghidra context initialization | `rea/backup-sync-context-pseudocode.json`, function `0x10017cec8`, Evidence `ev_a4e2b3426cf447dbc9ce170aab31bf75909cef5a858702c9f48d44a99e224f19` |
| Packaged model and preference evidence | `rea/backup-sync-resource-evidence.json`; `plistlib` parses the model's keyed archive without instantiating classes; `plutil` reads localization |
| Focused call sites | `rea/backup-sync-callsite-evidence.json`; Apple `otool` assembly and `dyld_info -fixups`, plus bounded selector-reference decoding. These are direct Apple-tool observations, not REA Evidence records |

The signature inspection confirms the original application's own `iCloud.com.onmyway133.PastePal` container, CloudKit and CloudDocuments entitlements, and production push environment. Its original container is an identity and architecture observation, not configuration to copy into XPastepal.

The prior REA snapshot was reused. A new broad Ghidra string search hit the client's 300-second tool timeout; no string-search result is treated as evidence. Ghidra subsequently completed initialization and returned both focused functions above. Its pseudocode is derived machine-code output, not the original Swift source; Apple-tool assembly corroborates the branch and arguments. The native session was closed successfully with six evidence records saved in `rea/backup-sync-snapshot.json` (135,458 bytes).

## Local persistence and cloud mirroring — answered statically

The packaged Core Data model is `Contents/Resources/PastePal2.momd/Butter.mom`. The model contains:

- `CDClipboardItem`: UUID `id`, `createdAt`, type/text fields, `device`/`deviceId`, application metadata, UUID `collectionId`, lock/name state, rich text data, image/file URLs and bookmarks, `markedDelete`, and a `blob` relationship.
- `CDCollection`: UUID `id`, creation date, name, icon, and color.
- `CDClipboardApp`: name, bundle identifier, and URL.
- `CDBlob`: binary data and inverse item relationship.

No business-level `modifiedAt` or `deletedAt` attribute appears in this model. This is a bounded observation of this one model, not evidence that the framework has no modification or deletion metadata.

The function beginning at `0x10017cec8` passes the short-string value `PastePal2` and a Boolean to the helper at `0x10017d170`. The helper:

1. Selects `NSPersistentCloudKitContainer` when the Boolean is set, otherwise `NSPersistentContainer` (`0x10017d194`–`0x10017d1b0`; class references resolved by dyld fixups).
2. Constructs it with `initWithName:` and accesses the first persistent store description.
3. Sets `NSPersistentHistoryTrackingKey` and `NSPersistentStoreRemoteChangeNotificationPostOptionKey` to true (`0x10017d290`–`0x10017d2e8`).
4. In the CloudKit-container branch, constructs `NSPersistentCloudKitContainerOptions` with the original container identifier and assigns it to the store description (`0x10017d388`–`0x10017d3e8`).
5. Calls `loadPersistentStoresWithCompletionHandler:` (`0x10017d4b4`–`0x10017d4c0`).

This establishes a real Core Data/CloudKit initialization path; it is stronger evidence than merely finding CloudKit imports. It does not establish the current user's enabled preference or that any synchronization completed.

Apple describes this container as mirroring selected local stores to a CloudKit private database. Local saves remain local transactions; the system later exports changes and imports remote changes. Synchronization timing is controlled by the system and can be delayed or throttled. [Apple API reference](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/), [Apple TN3163](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer), [Apple TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer).

## Images use iCloud Drive — answered with static and product evidence

The binary has `CloudDriveService` and `CloudDriveManager` types. The former has `ubiquityUrl` and `storage` fields. The localized sync settings distinguish ordinary iCloud synchronization from image synchronization.

At `0x100195ef4`–`0x1001960ec`, the code checks the ubiquity identity, obtains the default ubiquity container through `URLForUbiquityContainerIdentifier:nil`, appends `Documents`, and configures storage with the short-string name `Images`. This establishes a Drive-storage initialization path. The precise eventual image filename, retention, retry behavior, and garbage-collection rules were not traced.

The author's public implementation article demonstrates the same container/Documents/EasyStash pattern, but is supporting design context rather than proof that the 2026 binary exactly matches that sample. [Author's iCloud Drive article](https://github.com/onmyway133/blog/issues/937).

Official product documentation says that image synchronization must be enabled separately and covers copied image data, not image files copied from Finder. It also says devices must use the same iCloud account and have synchronization enabled; synchronization is asynchronous. [PastePal iCloud Drive](https://docs.indiegoodies.com/pastepal/Mac/features/icloud-drive), [PastePal iCloud Sync](https://docs.indiegoodies.com/pastepal/Mac/icloud-sync).

## Deletion and conflicts — partially answered

The model contains a non-optional Boolean `markedDelete`. The item-to-blob relationship has delete rule `2` (cascade); the inverse has rule `1` (nullify). Official documentation describes a trash stage before automatic cleanup, with an option to skip trash. Cleanup preserves clips in a collection, locked clips, and named clips. [PastePal Trash](https://docs.indiegoodies.com/pastepal/Mac/features/trash), [PastePal History Cleanup](https://docs.indiegoodies.com/pastepal/Mac/features/history-cleanup).

These findings support a soft-deletion state and final removal of associated local blobs. They do not prove how a concurrent remote edit versus delete is resolved, or when Drive image files are purged.

The container setup sets `viewContext.automaticallyMergesChangesFromParent` to false (`0x10017cf00`–`0x10017cf28`). A newly created background context gets automatic parent merging enabled and `NSMergeByPropertyObjectTrumpMergePolicy` (`0x10017cf64`–`0x10017cf9c`); undo managers are disabled in these paths.

That context policy favors changed in-memory properties over conflicting store properties. It is not, by itself, a complete cross-device conflict algorithm. Apple separately describes CloudKit-container conflict handling as last-writer-wins. Applying that framework description to PastePal is a reasonable inference from its initialized container, not an observed two-device experiment. [Apple merge policy reference](https://developer.apple.com/documentation/coredata/nsmergepolicy/mergebypropertyobjecttrump), [Apple WWDC19 session 202](https://developer.apple.com/videos/play/wwdc2019/202/).

## Local backup trigger and format — only manual export established

Official export documentation describes CSV, with content-type and collection filters. Localized resources include export/import success and failure messages and export view/service names. The complete CSV schema, attachment fidelity, import deduplication, and full round-trip recovery were not verified. [PastePal Export](https://docs.indiegoodies.com/pastepal/Mac/features/export).

A bounded search found a `Backup` type and SQLite backup C APIs, but those names are associated with the bundled SQLite library. Their presence is **not** evidence of a scheduled user backup feature. No backup schedule, version-retention policy, backup directory, or automatic restore trigger was established by the inspected resources and call sites.

## Independent implementation guidance for XPastepal

1. Preserve an authoritative local store that remains usable without iCloud. Keep a verified local recovery snapshot before migration and before applying imported/remote state.
2. For the closest architecture match, use an independently modeled `NSPersistentCloudKitContainer` with XPastepal's own registered container and signing entitlements. Porting the original model or container identifier is unnecessary.
3. If retaining the existing JSON store, record-level synchronization is an independent implementation choice. Add stable IDs, revision information, explicit deletion tombstones, durable pending operations, deterministic conflict handling, and account separation. Sharing one mutable `history.json` through Drive is not equivalent to the observed design.
4. Separate database records from image bytes. Use stable content-addressed or UUID attachment keys. A remote item must remain representable while its image downloads. Do not treat local Finder URLs or security-scoped bookmarks as portable file contents.
5. Keep snapshots distinct from synchronization. A synchronized deletion may spread to every device; a dated backup is a recovery point. Define local backup cadence, retention, atomic writing, validation, and restore semantics explicitly as XPastepal behavior.
6. Show disabled/unavailable/pending/syncing/error states. Require verified remote completion before showing success; a successful local save is not proof of another device receiving the data.
7. Validate at least two independently signed instances: create/update/delete, offline divergence, reconnection, image download, duplicate handling, account change, quota/network failure, and recovery from a local backup. Static evidence and one-machine tests cannot establish end-to-end iCloud correctness.

## Remaining unknowns

- Exact local SQLite filename/location and model configuration at runtime; no user database was opened.
- Original image file naming, Drive retries, download coordination, and orphan cleanup.
- Application-specific concurrent-edit and edit-versus-delete behavior.
- Original initial-sync migration, account-switch policy, and full history import deduplication.
- Any automatic archive-backup feature beyond the verified manual CSV export.
- End-to-end sync latency and correctness on the user's devices.
