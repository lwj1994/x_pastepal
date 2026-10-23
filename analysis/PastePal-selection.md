# PastePal selection dispatch

Inspected on 2026-10-20, using the installed PastePal 2.19.6 executable.
Identity, commands, output hashes, and limitations are recorded in
[selection-evidence.json](rea/selection-evidence.json).

## Observed application code

Objective-C method metadata identifies `CollectionViewController.CustomCollectionView`
as an `NSCollectionView` subclass, and `BaseCell` as an `NSCollectionViewItem` subclass.
[Method mapping](rea/selection-methods.json) and [raw metadata](rea/selection-objc-metadata.txt).

| Entry | Observed sequence |
| --- | --- |
| `CustomCollectionView.mouseDown:` at `0x100179f54`, Swift body `0x100179cbc` | Calls `super.mouseDown(event)` first, then reads `event.clickCount`. Count 2 calls `0x10016583c`; count 1 resolves the item at the pointer and checks the Shift modifier. |
| `BaseCell.setSelected:` at `0x10015af14` | Calls the superclass setter, then synchronously calls `0x10015ab98` and `0x10015ac5c`. |
| Border update at `0x10015ab98` | Reads the selected state, chooses an `NSColor`, obtains its `CGColor`, and calls `setStrokeColor:` on the cell's border layer. |
| Double-click branch at `0x10016583c` | Checks settings, resolves the clicked item through the collection's diffable data source, and forwards an item action. The settings fields and final action enum are not fully recovered. |

The mouse handler and selected-state setter contain no application-level
single-versus-double-click timeout. AppKit owns the base collection selection;
the application adds its click-count-specific behavior afterward.

Sources: [mouse handler pseudocode](rea/selection-pseudocode/100179cbc.c),
[selected setter](rea/selection-pseudocode/10015af14.c),
[border update](rea/selection-pseudocode/10015ab98.c), and
[assembly](rea/selection-assembly.txt).

## XPastepal implementation

The previous card and list-row views stacked separate SwiftUI single- and
double-tap recognizers. Selection could wait for the double-tap recognizer to
fail. They now share one tap handler and read the current mouse-up event's
native `clickCount`: the first release selects, the second activates, and
additional clicks in the same sequence are ignored.

This borrows the observed native click-count routing, while retaining XPastepal's
SwiftUI layout and release-to-select behavior. SwiftUI still handles tap
cancellation, child buttons, and context menus. Non-mouse accessibility actions
fall back to selection. The second release does not repeat the selection toggle.

## Evidence limits

These are static observations of shipped code, not recovered original Swift
source or a runtime latency trace. The exact point inside AppKit's superclass
implementation when it changes selection is outside this analysis.

REA's `search_procedures` request timed out after 300 seconds; its session was
closed. The retained pseudocode was produced by **direct Ghidra 12.1.4** with
`-noanalysis -readOnly -deleteProject`, using
[SelectionDecompile.java](rea/SelectionDecompile.java). These outputs do not
have REA Evidence IDs. See [the headless log](rea/selection-headless.log).

## Implementation validation

- `swift test`: 53 tests passed; the existing opt-in compositor profile was skipped.
- `scripts/check-click-interactions.sh`: both actual views passed first-release
  selection, second-release activation without a repeated selection toggle,
  drag-out cancellation, and independent child-button activation. The fixture
  includes SwiftUI selection-state updates and the surrounding context menu.
- The final fixture run reported approximately 0.3 ms (card) and 0.4 ms (list)
  from posting mouse-up to the selection callback. These are local callback
  measurements, not GPU/display latency or a performance guarantee.
- A separately compiled baseline with the original stacked tap recognizers
  failed the first-release selection assertion in the same fixture.
- Release app build and local signature verification completed.

The standalone event loop is deliberate: nesting AppKit's run loop inside a
test executor can prevent SwiftUI's queued work from progressing normally.
The probe posts events only to its own application and does not use the real
clipboard.

## Reproduction

To reproduce the targeted decompilation:

```sh
. ./analysis/rea/env.sh
selection_project=$(mktemp -d /tmp/xpastepal-selection-ghidra.XXXXXX)
"$GHIDRA_INSTALL_DIR/support/analyzeHeadless" "$selection_project" pastepal-selection \
  -import /Users/luwenjie/.rea/targets/pastepal-ecc6c102/PastePal.arm64 \
  -noanalysis -readOnly -deleteProject \
  -scriptPath "$PWD/analysis/rea" \
  -postScript SelectionDecompile.java "$PWD/analysis/rea/selection-pseudocode"
```
