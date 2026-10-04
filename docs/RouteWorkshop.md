# Route workshop

The workshop replaces the export-first workflow with a route list and a selected-step inspector. It uses bundled AceGUI controls, WoW textures, gold headings and colored action icons. English and French labels are included. No additional library or artwork is required.

The reference was [Alenya's Guides Writer](https://www.curseforge.com/wow/addons/alenyas-guides-writer): the numbered route, readable action descriptions, and explicit step-editing controls inspired the workflow. Its code and assets were not copied.

## Existing feature locations

| Existing capability | Access after the redesign |
| --- | --- |
| Start / stop recording, resume or create routes | Workshop header |
| Open workshop and move its launcher | Single recorder button; drag to move, position is saved, red indicator while recording |
| Full route and legacy step-table editing | Lua editor tab |
| Lua copy/paste, indentation, undo / redo | Lua editor tab; keyboard shortcuts and footer buttons |
| Route selection, step count, live refresh | Header and Follow recording; refresh pauses during editing or focused input |
| Save route and backup of previous steps | Save; `/aprrc backup` remains available |
| Publish saved routes to APR, immediately and after reload | Automatic; Save commits editor drafts |
| Import an APR route as an editable copy | Import from APR; searchable by label or route key |
| Extra-line-text export, save and reset | Tools → Extra line texts (existing dialog) |
| Custom command bar, orientation, ordering and reset | Commands tab; favorite controls and inline Bar settings |
| Quest, achievement and text autocomplete; reputation and objective dialogs | Existing commands and Tools → Actions |
| Coordinate frame | Tools → Coordinates; `/aprrc coordframe` |
| All automatic recording hooks | Unchanged recording modules |
| Route metadata, conditions and numbered helper texts | Route / Steps forms and full Lua editor |
| Parallel groups, their conditions and steps | Parallel steps tab; full Lua editor |
| Settings, profiles, quest ID display, addon toggle and reset | Tools → Settings, `/aprrc settings`, existing settings button and minimap right-click |

The visual editor exposes automatically recorded fields as editable properties too. A form edits the selected step; recording commands still edit the last recorded step. These are separate contexts and the Tools tab labels that distinction.

## Lua editing tools

`Ctrl+S` saves the selected route from the workshop and its input fields, using
the same conflict resolution as the Save button. In Lua, `Ctrl+L` selects the
whole source line, including its newline; repeated presses extend the selection.
`Ctrl+K Ctrl+L` continues to toggle folding.

Syntax and APR field errors update after the existing **400 ms input pause**.
The footer reports their line and column; click its message or a red gutter
marker to reveal the source. `F8` / `Shift+F8` move between errors. Diagnostics
never save data, reposition the caret during input or execute Lua.

The route header and Lua tools each occupy one compact row; hover an icon for
its action and shortcut. APR completion appears inline at the caret after a pause
while entering a field or an ID. **Tab** accepts the suggestion; **Escape** hides
it. Arrow keys navigate the source and **Enter** inserts a line normally.
`Ctrl+Space` or the **APR completion** icon opens the alternatives at the caret;
use **Alt+Up/Down** to choose, then Tab or a click to accept. Fields come from the APR schemas;
quest suggestions use the route and journal, spell suggestions the route,
grimoire, professions and recent choices, and items the route, bags and recent
choices. Search a known name or type an ID. Completion inserts data without
dispatching recording commands.

`Ctrl+F` searches and `Ctrl+H` opens replacement. **Aa** controls case matching;
**[ab]** restricts matches to whole words. Search and replacement are literal,
including pattern characters and `%1`. **Replace** uses the current result;
**Replace all** replaces all matching source ranges as one undo action, including
folded data.

**Format Lua** / `Shift+Alt+F` expands route/step containers and applies indentation and whitespace formatting to
valid Lua data. Strings, comments, constants, values and field order are retained;
invalid input remains intact. The searchable **Step outline** / `Ctrl+Shift+O`
lists main and parallel steps with source lines and titles. Selecting an entry
unfolds and centers its source. Only 80 menu results are rendered at a time;
filter by step number, group or title to reach later steps. Formatting, replacement
and accepted completions can all be undone with `Ctrl+Z`.

Closing a saved route does not prompt because of drafts belonging to other routes;
those drafts remain persisted. Only pending changes in the displayed route show
**Save**, **Keep draft**, **Discard changes**, and **Cancel**. Discard closes the
editor and removes the displayed route's draft while keeping its latest saved
version, including background recording changes. Drafts of other routes remain
available. Cancel returns to editing. Confirmation dialogs contain just the
message and actions. Undoing to the saved source clears its draft, and whitespace-only
edits are reconciled after the input pause. Repeated reminders, saves and closes
do not add identical recovery versions under different reason labels.

The **Delete route** trash button in the workshop footer asks for confirmation,
including the selected route's name. Confirming removes the saved route, its
draft and the recorder's published APR copy. Deleting the route being recorded
also stops recording. Route deletion cannot be undone; cancel leaves it intact.

Money, VendorMoney and LootMoney use three editable **gold**, **silver** and **copper** fields
with coin icons, including nested conditions and recording command dialogs.
Values are stored as copper (`gold * 10000 + silver * 100 + copper`).
VendorMoney filters a step using current cash plus the vendor value of bag items
and optionally equipped gear. Select equipment slots or enable `includeEquipped`
for all equipment; the comparison defaults to `>=`. For example,
`/aprrc vendormoney { copper = 102, equippedSlots = { 16 } }` requires at least
102 copper including the main-hand weapon. This condition also works in nested
and parallel step conditions. It estimates resale value and does not sell items.
Step subtitles show coin amounts, item names and icons for item actions and
conditions, and skill names and icons. Item lists wrap to remain visible; names
not yet cached by the game initially show their ID and refresh when available.

Step rows show class and race condition icons at the top right, including nested
conditions and conditions inherited from a parallel group. A red cross marks an
exclusion. Hovering an icon shows its condition paths, preserving the distinction
between AnyOf, AllOf and Not. Repeated filters share an icon; when space is limited,
a **+N** counter exposes the remaining filters on hover without increasing row height.

Hold **Ctrl** over a step to expand its tooltip with all condition values. The
details update immediately on press and release, preserving nested AnyOf, AllOf
and Not branches and separating inherited parallel-group conditions. Sections use
Diogenator's cyan headings, blue labels, white values and thin blue-gray divider.

The inspector places single-line values and their search/remove buttons on the
same row, without repeating the field title in a surrounding frame. Position
combines **X**, **Y** and **map ID** on one line; its remove button clears both
coordinates and zone, and Undo restores them together. Class, excluded class,
race and equipped-slot lists use checkbox dropdowns that stay open while choosing
multiple values. Existing scalar/list values and class tokens are preserved until
edited. Route conditions also accept class and race lists, as APR does.

The **Route** tab shows compact metadata and clickable summaries for conditions,
next routes, presets and scenarios. Open a summary to edit that block at full
width. The breadcrumb, back arrow and **Route overview** button replace nested
frames, including deeply nested **AnyOf**, **AllOf** and **Not** conditions; their
logical structure is preserved.

Equivalent data formats share one form: text/list fields use one entry per line,
class/race selections write lists, and next routes always show a route name and
conditions. Numeric presets use the same index/conditions form as conditional
presets. XP consumables use one dropdown containing **Disabled** and the available
profiles. Opening these forms preserves legacy values; editing writes the unified
representation. Level requirements retain meaningful choices (number, profile,
level + XP), without numbered format labels.

The **Parallel steps** tab selects a parallel group and uses the same step list,
search, filters, pagination and inspector as **Steps**. Add, duplicate, reorder or
delete groups from the top toolbar; **Group conditions** edits when that group's
steps apply. Within a group, add, duplicate, move, delete and edit steps, including
their coordinates and individual conditions. Undo / redo, drafts, Save and Lua
editing include both the groups and their steps. Main and parallel step selections
are separate, and following recording does not move the parallel selection.

Parallel step details and group conditions display their fields directly in open
cards, one per outer condition block. Dividers and headings distinguish nested
conditions within each card without accumulating borders or indentation;
remove actions sit on the right of each heading. Values, selectors and
checkboxes can be edited immediately, using the same controls as ordinary steps.
Undo and Save continue to operate on the complete draft.

For **Equipped item stat**, **Pass when the stat is unavailable** controls the
result when APR cannot read the selected stat (for example, an empty equipment
slot or unavailable item data). Checked makes that condition pass; unchecked makes
it fail. When APR can read the value, the comparison and threshold still apply.
The checkbox tooltip explains both cases without adding another form row.

**Sell items** supports gray items, selected item IDs and equipped slots together.
For example, `/aprrc sellitems { junk = true, equippedSlots = { 16 } }` adds a sale
of gray items and the weapon currently in the main hand. The slot picker uses
equipment names and saves their numbers (16 for main hand, 18 for ranged).
During APR playback, the player first moves the selected equipped item into
their bags; APR then sells that item at the merchant. Add a **Vendor money**
condition with the same slots when the sale should only appear if it can fund
the following purchase.

The Commands tab launches recording commands directly from labeled buttons. Search
matches translated labels and slash command names, including unpinned commands.
The catalog follows the editor's actions, navigation, display, conditions and route
metadata groups. Favorites can be added, removed and moved up or down. Bar settings
share this tab: visibility, optional button labels, orientation, row size and reset.
The floating bar uses a wrapping grid, reuses its buttons and paginates oversized
lists. Drag its header to move it. An empty favorites list stays empty until changed
or reset; saved custom commands and their order are preserved.

Use **Compact mode** in the workshop header to halve its current width (1120 to
560 pixels by default). The Steps and Parallel steps tabs then show one pane at a time: select a step
to open the inspector, or use **Back to steps** to return to the list. **Full width**
restores the previous editing width. Recording controls, Commands and other tabs
remain accessible in both modes. Width, height and compact mode are saved across
reopening and reloads; switching modes preserves unsaved and incomplete Lua drafts.

Drafts are detached from recorded routes and stored in `AprRCData.EditorDrafts`,
including incomplete Lua. Starting recording from the workshop requires a saved
draft. Recording can continue while an already open route is being edited.

**Save** validates the complete draft and performs a three-way merge against the
version from the start of editing and the latest recorded route. Compatible
changes are retained automatically, including new recorded steps. Conflicts open
a comparison of the common ancestor, the **draft on the left**, and the
**recorded route on the right**, with Lua syntax colors and red/green backgrounds
for changed lines. The **Merge result (editable)** panel at the top immediately
shows the selected value. Correct it directly if needed; edits are kept when
navigating between conflicts. Use `nil` to delete a field. Invalid Lua prevents
applying the merge, and the complete route is validated before saving or rebasing.
Choose each conflicting value, then **Merge and save**. Concurrent insertions offer **Keep both (left, then right)**. Structural
edits that cannot be safely aligned require a choice for the affected block.
Shift, Ctrl and Alt no longer bypass conflict resolution. If recording or the
draft changes during review, applying the choices refreshes the comparison and
requires reviewing its updated conflicts.

The **Versions** tab also provides **Rebase draft**: apply the draft's changes
on top of the latest recording without committing them. Review the result and
Save later. Undo after a rebase returns to that latest recording. The tab remains
accessible when Lua is incomplete; merging still requires valid data.

**Compare versions**, available in the Lua and Versions tabs, opens a side-by-side
comparison. Select the saved route, current Lua draft, common ancestor or any
archived version on either side. **Compare with draft** on a history entry opens
that version directly. The views show syntax colors, original line numbers, red
deletions, green additions, stronger highlights within modified lines and hatched
padding where one side has no corresponding line. Scrolling is synchronized;
**Previous change** / **Next change**, or **Shift+F7** / **F7** while a pane has
focus, center the selected change. Both panes are read-only, and comparisons
accept incomplete Lua without applying, saving or replacing either version.

Recovery stores the latest 40 full versions per route in `AprRCData.RouteHistory`,
including metadata, parallel steps and raw Lua. Versions are captured before
save, merge, rebase, route reload, backup restoration and confirmed draft closure,
and at incoming-change/idle checkpoints. Opening another route does not replace
them or the legacy step backup. **Recover a copy** opens a separate route and
detached draft; it preserves the active recording target and the original route.
Internal step identities are persisted beside routes and are never exported to
APR or added to route syntax.

When recording changes a route with an unsaved draft, a chat/on-screen warning
and an amber workshop status appear. The immediate warning is coalesced until
the versions are reconciled. After two minutes without editor activity, a chat/
on-screen reminder repeats every two minutes. Recording events do not postpone
the reminder. Monitoring continues with the workshop closed and restores
persisted drafts after login. Closing the workshop, including its native close
button, asks to **Save and close**, **Close and keep draft**, or cancel whenever
unsaved drafts remain. Invalid Lua cannot be saved but can still be kept.

These versions and drafts use WoW SavedVariables: their contents reach disk on
UI reload/logout, not on each in-memory editor Save. They protect against route
replacement and draft discard; a client crash before disk persistence can still
lose changes since the last successful UI reload/logout.

## APR integration

**Follow recording** selects the latest step only while capture is active and
the recorded route is open. Selecting steps, changing tabs or pages, typing,
and scrolling suspend it for five seconds after the last interaction. Focused
inputs, open dialogs and unsaved drafts keep it paused. Stopping capture preserves
the selected step and Lua cursor. Explicit commands that add steps still reveal
their result, including with automatic follow disabled.

Enable **Follow APR** in the workshop footer to select APR's current playback
step when the same route is open in the recorder. Matching uses the exact route
key or that route's published recorder copy, rather than its display label.
Main and inserted parallel steps select the appropriate tab, group and page.
The preference is saved across reopening and UI reloads. Following pauses for
unsaved drafts and focused editing controls. In the Lua editor, the cursor and
viewport follow the actual main or parallel step without changing the text or
undo history. Other tabs stay open. When both
follow options are enabled for the same route, APR playback takes precedence
over following the latest recording.

The Lua editor uses a dark syntax palette for fields, strings, numbers, keywords
and comments, plus colored nested brackets. Line numbers and **+ / -** controls
fold multiline tables, long strings, block comments and `-- #region` /
`-- #endregion` sections without changing their source or undo history.
**Shift+click** a fold control to include its nested blocks. Searching inside a
folded table reveals it; **Ctrl+A** unfolds all blocks to copy the complete source.
Use the bottom scrollbar or **Shift+mouse wheel** to scroll horizontally.
The gutter, diff backgrounds and search centering use the rendered font's line
height. The editor keeps native line spacing so mouse selection and the cursor
stay aligned with the visible code, including after changing fonts.

The folding toolbar provides **Fold all**, **Unfold all** and shortcut help.
Keyboard chords use the [VS Code folding bindings](https://code.visualstudio.com/docs/editing/codebasics#_folding):
press the first combination, release it, then press the second within three seconds.
The code pane or Lua search field must have keyboard focus. The shortcut-help
button displays **Ctrl+K …** while waiting for the second combination. Ctrl may
be held or released between steps. Folding levels also accept the numeric
keypad and the unshifted number-row characters on French AZERTY keyboards.
Moving focus out of the editor, pressing Esc or waiting three seconds cancels
the pending sequence. Handled commands do not reach the game's key bindings.

| Action | Shortcut |
| --- | --- |
| Fold / unfold current block | Ctrl+Shift+[ / Ctrl+Shift+] |
| Fold / unfold current block and its children | Ctrl+K, Ctrl+[ / Ctrl+K, Ctrl+] |
| Toggle current block | Ctrl+K, Ctrl+L |
| Fold / unfold all | Ctrl+K, Ctrl+0 / Ctrl+K, Ctrl+J |
| Fold level 1–7, keeping the block containing the cursor open | Ctrl+K, Ctrl+1–7 |
| Fold / unfold marked regions | Ctrl+K, Ctrl+8 / Ctrl+K, Ctrl+9 |
| Fold block comments | Ctrl+K, Ctrl+/ |

In the Lua editor, **Ctrl+F** opens a literal, case-insensitive text search with
highlighted matches and a match counter. Each result is centered vertically and
its horizontal position is brought into view, within the document's scroll limits.
**Enter** finds the next match,
**Shift+Enter** the previous one; both wrap at the ends. The arrow buttons also
navigate matches; **Esc** closes the search. Search also works on incomplete Lua drafts and
pauses APR following until closed.

The recorder remains the source of its saved routes. Every saved route is automatically copied to `APRData.CustomRoute` and APR's live catalog on startup, creation, import, recording changes and editor saves. Updates are coalesced until the next frame and unchanged definitions are not republished. Pending changes are flushed on logout. Opening the workshop is not required. Drafts are published only after **Save**.

Copies appear in APR's **Custom** tab under their recorder name with ` - Custom`. Their stable keys are stored in `AprRCData.APRRouteKeys`. An existing route with that key, including an old manual export, is preserved; the new copy receives a numbered Recorder suffix. Saved copies remain available when the recorder is disabled or reset. Resetting the recorder does not delete APR's existing copies.

**Import from APR** searches the definitions currently loaded by APR. Importing creates a detached copy, including route metadata, parallel steps and delve scenarios, without changing the original or switching the current recording target. Repeated imports receive distinct names. The recorder's own published copies are excluded from this picker; edit their existing recorder routes instead. Original route links are retained. Delve scenario blocks are editable through the route's `scenarios` field. Unchanged legacy values and unknown metadata can round-trip; new or modified values are validated against the recorder's schema.

The companion APR change adds `APR:RegisterCustomRoute(name, definition)`, preserves complete metadata when loading custom routes, invalidates the effective-step cache and separates saved data from runtime playback. Catalog refreshes do not restart navigation unless the active route changed. Install both updated addons for this behavior. Older APR versions still receive automatic copies through the compatibility path, but retain their older loading and refresh behavior.

## Recent items and spells

Item and spell selectors in commands and the workshop show **Recent items** or
**Recent spells** first, newest first, followed by the other results. Searches
filter both sections and an ID appears only once. Recent entries remain available
even when an item has been consumed or a spell is absent from the spellbook.

The history includes confirmed selector choices (including typed IDs) and successful
player casts while the addon is enabled, even when recording is paused. Item use is
matched to the item's spell using the bags and equipment at cast start. If several
different items share that spell, the recorder does not guess which item was used.
Restricted game values are ignored; uncached names display the ID instead.

`AprRCRecentChoices` is saved per character and stores only IDs and timestamps:
at most **20 items and 20 spells**, without duplicates. Entries expire **7 days**
after their last use or selection. Cleanup runs at login, logout and whenever the
history is read or updated. **Clear recent history** clears the current selector's
item or spell history; `/aprrc forcereset` clears both with the recorder data.

## Verification

`python tests/run.py` covers recording regressions, route round trips, draft restoration, metadata retention, undo branches, step ordering, concurrent recording changes, and Lua 5.1 syntax. It also loads the bundled AceGUI implementation against native-frame stubs to exercise window pooling, all registered field examples, editing callbacks, tab switching, invalid Lua, exports, recording controls, pagination, and layout allocation at 880×560, 1120×780 and 1400×900.

The native stubs do not render WoW textures, fonts, clipping, or protected game state. Complete these checks in the game client:

1. Open `/aprrc` on an empty profile and on an existing route. Verify the main window fits the screen at the intended UI scale and remains usable when resized.
2. Record quest pickup, objectives and turn-in; check titles, locations, conditions and live-follow behavior. Keep a text field focused while recording another step; input should remain intact.
3. Import an APR route, including parallel steps and multiple class/race conditions. Edit and Save, reload the UI, and verify the Custom copy in APR. Confirm that the original route and an unsaved draft stay unchanged. Record with the workshop closed and verify automatic publication.
4. Switch between visual and Lua editing; test invalid Lua, copy/paste, indentation and Ctrl+Z / Ctrl+Y. Close/reopen and `/reload` with a draft.
5. Modify a draft while recording adds steps; verify Save retains both changes. Edit the same field on both sides, choose left/right, and record another step while reviewing; applying must refresh the comparison. Rebase without committing, then recover a version as a separate copy. Check the immediate warning, two-minute idle reminders with the workshop closed, and all close-confirmation choices.
6. Open legacy command and extra-line-text dialogs, close them, then reopen the workshop. Check the status bar, Lua key handlers and recorder controls still work.
7. Check recording of flights, portals and quests in combat with the workshop open. Drag the recorder launcher, reload, and verify its position and recording indicator.
8. Cast a spell and consume the last copy of a usable quest item, then check their recent sections in the Use, Button and Trigger selectors. Confirm a choice, reopen, search by name and ID, then clear the history. Reload and switch characters to check persistence and isolation.
9. In Parallel steps, add a group, set its conditions and edit its steps. Duplicate, reorder and delete groups and steps; undo and redo, then Save. Check full and compact layouts and confirm APR receives the group conditions and step order.
10. In a long Lua draft, search for a field in a collapsed table and check that it unfolds and appears in the middle of the viewport. Verify the selected value and line number after several hundred lines, then replace it and check that only that value changes. Repeat with a different font and UI scale. Exercise folding shortcuts and Shift+click, including nested tables, block comments and marked regions; text and undo history must remain intact. Type continuously with search open, then press Enter, Backspace and Delete: the caret and source must stay together. Colors and folds refresh after 400 ms without input; source and draft persistence update immediately. A pause must preserve mouse/Shift selections and scroll position. Saving invalid data reports its line and column and selects the error in the editor.
11. Compare two archived versions with insertions, deletions and modified strings. Check line alignment, colors, hatching, horizontal scrolling, synchronized vertical scrolling after resizing and F7 / Shift+F7 navigation. Switch both selectors to the same version, then compare an incomplete draft. Neither saved routes nor drafts should change.

`python tests/apr_compatibility_run.py [path/to/azeroth-pilot-reloaded]` additionally exercises real APR definitions and its registration/loading API from a neighboring checkout, including the Midnight Speedrun route and delve scenarios. Coordinate conversion is stubbed; playback still requires the in-game checks above.
