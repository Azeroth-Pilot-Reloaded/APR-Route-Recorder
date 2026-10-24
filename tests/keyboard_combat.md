# Keyboard combat regression (25 October 2026)

BugGrabber reported two blocked calls to `Frame:SetPropagateKeyboardInput()`
from `InstallSaveShortcut`, reached through the recorder launcher and
`Editor:Show`. The report does **not** establish whether the player was in combat.
The code nevertheless had unconditional propagation changes during installation,
key dispatch and close. The Steps listener and Lua command listener had the same
problem during creation, acquire, key dispatch and pool release.

Blizzard's [generated Frame API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
marks this method `HasRestrictions`. The [Ace3 implementation](https://github.com/WoWUIDev/Ace3/blob/master/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua)
also guards its propagation changes with `not InCombatLockdown()`. A plain,
non-secure frame does not exempt this particular call from combat restrictions.
The generated signature alone does not document all engine security checks;
this correction addresses the concrete unsafe combat paths, without claiming
that the report proves combat or rules out other taint interactions.

All three listeners now use `UI.SetKeyboardHandler`. It resets propagation
**before** enabling an out-of-combat listener and changes propagation only outside
combat. `PLAYER_REGEN_DISABLED` disables keyboard input even if the previous key
left propagation false. `PLAYER_REGEN_ENABLED` restores propagation and input only
for an attached, visible listener. Hide disables input; release removes the key
handler and both combat event subscriptions. A save or navigation callback that
closes/releases/replaces its listener cannot consume another key after cleanup.
These are ordinary editor frames, without secure templates or protected actions.
No errors are caught or suppressed to make forbidden calls appear to work.

While in combat the auxiliary keyboard listeners are suspended. The editor can
still open, switch views and close; its Save button remains available. Native
EditBox behavior remains in place. Outside combat, Ctrl/Cmd+S keeps the existing
save/merge workflow, works with focus inside the workshop or no focused input,
and passes through when another window owns keyboard focus. Other keys propagate
unless an existing Steps/Lua command handles them.

Automated verification: `python tests/run.py` (Python with `tests/requirements.txt`)
also runs a fresh Lua 5.1 UI runtime for `tests/keyboard_combat_smoke.lua`.
The native-frame stub rejects **every** propagation call in simulated combat,
including initialization and release. Tests cover the original launcher stack,
first construction in combat, Steps/Lua view creation and reuse, visible-window
reopening, Ctrl/Cmd+S, unrelated keys and external focus, combat after a consumed
key, close/reopen during combat, hidden listeners, dirty-close cancellation,
reentrant close from Save, and actual AceGUI lending/reuse of the native window.
The existing save/merge tests continue to exercise real workflow callbacks.

Required in-game checks on the affected Retail build:

1. Start with a fresh login/reload and BugGrabber/BugSack enabled. Enter combat
   **before the first opening**, then open the recorder editor from its button.
   Visit Steps, Parallel steps, Lua, and version/diff views; close and reopen in
   combat. Repeat with a window previously opened outside combat.
2. Outside combat, edit a route and save with Ctrl+S (Windows) or Cmd+S (macOS),
   from a form, Lua, search/replace input, and with no focused input. Verify saved
   content and conflict resolution. With chat or another window focused, verify
   the workshop does not save. Check movement, action bindings, chat, Escape and
   ordinary typing still receive their expected keys.
3. Immediately after saving or using a Steps/Lua command, enter combat before
   pressing another key. Check movement/action bindings throughout combat and
   after combat ends. Close during combat and verify the next key is not captured;
   leave combat while closed and verify no listener reactivates.
4. Repeat open/close and tab changes to exercise widget reuse, including another
   AceGUI dialog borrowing the frame. Cancel a dirty-close prompt, then close
   by keeping/discarding a draft. Verify shortcuts recover when appropriate.
5. Confirm no new `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` records and no
   taint-related symptoms. If the error reproduces outside combat, capture the
   client build, exact focus/opening sequence, addon list and taint log separately.

The tests run the bundled AceGUI and real addon callbacks, but the stub is not
the Retail engine: it does not reproduce secure execution/taint, native keyboard
routing and priority, inherited visibility events, hardware input, macOS modifier
mapping, or event timing at the combat boundary. Its combat rejection is an
explicit regression model, not independent proof of Blizzard's runtime rules.
Only the in-game checks can validate those behaviors on the affected build.
