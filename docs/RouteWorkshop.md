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

The **Parallel steps** tab selects a parallel group and uses the same step list,
search, filters, pagination and inspector as **Steps**. Add, duplicate, reorder or
delete groups from the top toolbar; **Group conditions** edits when that group's
steps apply. Within a group, add, duplicate, move, delete and edit steps, including
their coordinates and individual conditions. Undo / redo, drafts, Save and Lua
editing include both the groups and their steps. Main and parallel step selections
are separate, and following recording does not move the parallel selection.

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

Drafts are detached from recorded routes and stored in `AprRCData.EditorDrafts`. Closing or switching routes preserves them, including incomplete Lua. Saving validates the entire definition through the existing data-only parser, checks that the recorded route has not changed, backs up the prior steps, and then replaces the saved route. A concurrent change requires saving a separate copy or explicitly discarding the draft. Starting recording from the workshop requires a saved draft.

## APR integration

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
5. Modify a draft while recording changes the source; verify Save refuses to overwrite it and Save a copy preserves both versions.
6. Open legacy command and extra-line-text dialogs, close them, then reopen the workshop. Check the status bar, Lua key handlers and recorder controls still work.
7. Check recording of flights, portals and quests in combat with the workshop open. Drag the recorder launcher, reload, and verify its position and recording indicator.
8. Cast a spell and consume the last copy of a usable quest item, then check their recent sections in the Use, Button and Trigger selectors. Confirm a choice, reopen, search by name and ID, then clear the history. Reload and switch characters to check persistence and isolation.
9. In Parallel steps, add a group, set its conditions and edit its steps. Duplicate, reorder and delete groups and steps; undo and redo, then Save. Check full and compact layouts and confirm APR receives the group conditions and step order.

`python tests/apr_compatibility_run.py [path/to/azeroth-pilot-reloaded]` additionally exercises real APR definitions and its registration/loading API from a neighboring checkout, including the Midnight Speedrun route and delve scenarios. Coordinate conversion is stubbed; playback still requires the in-game checks above.
