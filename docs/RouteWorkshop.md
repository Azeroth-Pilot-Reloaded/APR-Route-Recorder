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
| Export to APR, immediately and after reload | Export to APR |
| Extra-line-text export, save and reset | Tools → Extra line texts (existing dialog) |
| Custom command bar, orientation, ordering and reset | Commands tab; favorite controls and inline Bar settings |
| Quest, achievement and text autocomplete; reputation and objective dialogs | Existing commands and Tools → Actions |
| Coordinate frame | Tools → Coordinates; `/aprrc coordframe` |
| All automatic recording hooks | Unchanged recording modules |
| Route metadata, conditions, parallel steps and numbered helper texts | Route / Steps forms and full Lua editor |
| Settings, profiles, quest ID display, addon toggle and reset | Tools → Settings, `/aprrc settings`, existing settings button and minimap right-click |

The visual editor exposes automatically recorded fields as editable properties too. A form edits the selected step; recording commands still edit the last recorded step. These are separate contexts and the Tools tab labels that distinction.

The Commands tab launches recording commands directly from labeled buttons. Search
matches translated labels and slash command names, including unpinned commands.
The catalog follows the editor's actions, navigation, display, conditions and route
metadata groups. Favorites can be added, removed and moved up or down. Bar settings
share this tab: visibility, optional button labels, orientation, row size and reset.
The floating bar uses a wrapping grid, reuses its buttons and paginates oversized
lists. Drag its header to move it. An empty favorites list stays empty until changed
or reset; saved custom commands and their order are preserved.

Use **Compact mode** in the workshop header to halve its current width (1120 to
560 pixels by default). The Steps tab then shows one pane at a time: select a step
to open the inspector, or use **Back to steps** to return to the list. **Full width**
restores the previous editing width. Recording controls, Commands and other tabs
remain accessible in both modes. Width, height and compact mode are saved across
reopening and reloads; switching modes preserves unsaved and incomplete Lua drafts.

Drafts are detached from recorded routes and stored in `AprRCData.EditorDrafts`. Closing or switching routes preserves them, including incomplete Lua. Saving validates the entire definition through the existing data-only parser, checks that the recorded route has not changed, backs up the prior steps, and then replaces the saved route. A concurrent change requires saving a separate copy or explicitly discarding the draft. Starting recording from the workshop requires a saved draft.

## Verification

`python tests/run.py` covers recording regressions, route round trips, draft restoration, metadata retention, undo branches, step ordering, concurrent recording changes, and Lua 5.1 syntax. It also loads the bundled AceGUI implementation against native-frame stubs to exercise window pooling, all registered field examples, editing callbacks, tab switching, invalid Lua, exports, recording controls, pagination, and layout allocation at 880×560, 1120×780 and 1400×900.

The native stubs do not render WoW textures, fonts, clipping, or protected game state. Complete these checks in the game client:

1. Open `/aprrc` on an empty profile and on an existing route. Verify the main window fits the screen at the intended UI scale and remains usable when resized.
2. Record quest pickup, objectives and turn-in; check titles, locations, conditions and live-follow behavior. Keep a text field focused while recording another step; input should remain intact.
3. Edit an existing route, including parallel steps and multiple class/race conditions. Save, reload the UI and verify APR playback/export.
4. Switch between visual and Lua editing; test invalid Lua, copy/paste, indentation and Ctrl+Z / Ctrl+Y. Close/reopen and `/reload` with a draft.
5. Modify a draft while recording changes the source; verify Save refuses to overwrite it and Save a copy preserves both versions.
6. Open legacy command and extra-line-text dialogs, close them, then reopen the workshop. Check the status bar, Lua key handlers and recorder controls still work.
7. Check recording of flights, portals and quests in combat with the workshop open. Drag the recorder launcher, reload, and verify its position and recording indicator.
