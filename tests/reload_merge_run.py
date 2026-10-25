"""Check saved draft/step identities across fresh Lua runtimes, as on UI reload."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    for name in ("tests/stubs.lua", "locales/enUS.lua", "utils/Utils.lua", "utils/LuaData.lua",
                 "core/RouteManagement.lua", "core/RouteDefinition.lua", "core/APRIntegration.lua",
                 "commands/Registry.lua", "commands/Schema.lua", "recording/Session.lua"):
        lua.execute((ROOT / name).read_text(encoding="utf-8"))
    for path in sorted((ROOT / "commands/options").glob("*.lua")):
        lua.execute(path.read_text(encoding="utf-8"))
    for name in ("ui/editor/Merge.lua", "ui/editor/Model.lua"):
        lua.execute((ROOT / name).read_text(encoding="utf-8"))
    lua.execute("APRData = { CustomRoute = {} }; APR.RouteQuestStepList = {}")
    return lua


def run():
    run_login_drafts()
    first = runtime()
    saved = first.execute('''
        local route = { name = "2393-Reload recovery", steps = {
            { Note = "Original" }, { Waypoint = 42 } } }
        AprRCData = { CurrentRoute = route, Routes = { route }, QuestLookup = {} }
        local session = AprRC.editorModel:Open(route)
        session.draft.steps[1].Note = "Manual correction"; session:Snapshot()
        route.steps[1].Note = "Recorded correction"
        route.steps[2].Range = 7
        AprRC:NewStep({ Note = "Last hour A" })
        AprRC:NewStep({ Note = "Last hour B" })
        -- PLAYER_LOGOUT persists the final identities before SavedVariables.
        AprRC.editorModel:SourceIDs(route); session:Persist()
        return AprRC:SerializeData(AprRCData)
    ''')
    second = runtime()
    second.globals().SerializedState = saved
    rebased = second.execute('''
        AprRCData = assert(AprRC:ParseLuaData(SerializedState))
        local Model = AprRC.editorModel
        local live = AprRCData.CurrentRoute
        local session = Model:Open(live)
        local plan = assert(session:MergePlan())
        assert(#plan.conflicts == 1 and plan.conflicts[1].path == "route.steps[1].Note")
        assert(session:ApplyMerge(plan, { "left" }, true))
        live = AprRCData.CurrentRoute
        assert(#live.steps == 4 and live.steps[1].Note == "Manual correction")
        assert(live.steps[2].Range == 7 and live.steps[4].Note == "Last hour B")
        TestRunTimers()
        local exported = APRData.CustomRoute[AprRCData.APRRouteKeys[live.name]]
        for _, step in ipairs(exported.steps) do
            for key in pairs(step) do assert(not tostring(key):find("EditorStep", 1, true)) end
        end
        session.draft.steps[1].Note = "Rebased and not yet saved"; session:Snapshot()
        AprRC:NewStep({ Note = "Last hour C" })
        assert(session:ApplyMerge(assert(session:MergePlan()), {}, false))
        assert(session:IsDirty() and not session:IsStale())
        Model:SourceIDs(live); session:Persist()
        return AprRC:SerializeData(AprRCData)
    ''')
    third = runtime()
    third.globals().SerializedState = rebased
    third.execute('''
        AprRCData = assert(AprRC:ParseLuaData(SerializedState))
        local session = AprRC.editorModel:Open(AprRCData.CurrentRoute)
        assert(session:IsDirty() and not session:IsStale())
        AprRC:NewStep({ Note = "Capture after second reload" })
        local plan = assert(session:MergePlan())
        assert(#plan.conflicts == 0 and session:ApplyMerge(plan, {}, true))
        local live = AprRCData.CurrentRoute
        assert(#live.steps == 6 and live.steps[1].Note == "Rebased and not yet saved")
        assert(live.steps[6].Note == "Capture after second reload")
        assert(#AprRC.editorModel:History(live.name) > 0)
    ''')
    commented = first.execute('''
        local route = { name = "2393-Reload comments", steps = { { Note = "Saved" } } }
        AprRCData = { CurrentRoute = route, Routes = { route }, QuestLookup = {} }
        local session = AprRC.editorModel:Open(route)
        session.raw = "--saved µ\\n" .. AprRC.editorModel:RouteText(session.draft)
        assert(session:Save())
        return AprRC:SerializeData(AprRCData)
    ''')
    fourth = runtime()
    fourth.globals().SerializedState = commented
    fourth.execute('''
        AprRCData = assert(AprRC:ParseLuaData(SerializedState))
        local session = AprRC.editorModel:Open(AprRCData.CurrentRoute)
        assert(not session:IsDirty() and not session:IsStale())
        assert(AprRC.editorModel:RouteText(session.draft):find("--saved µ", 1, true))
        assert(session:Save())
        assert(AprRC.editorModel:RouteText(session.draft):find("--saved µ", 1, true))
    ''')
    print("Fresh-runtime reloads: draft conflicts, recorded tails, rebased identities and recovery history passed.")


def run_login_drafts():
    """A restored draft is pending work only when it still differs from saved data."""
    for case in ("legacy_base", "saved_elsewhere", "raw_saved_elsewhere", "unchanged_with_capture",
                 "real_edit", "legacy_real_edit", "invalid_lua", "comment_edit"):
        first = runtime()
        first.globals().LoginDraftCase = case
        saved = first.execute('''
            local Model = AprRC.editorModel
            local route = { name = "2393-Login draft", conditions = { Class = 9 },
                steps = { { Note = "Original" } } }
            AprRCData = { CurrentRoute = route, Routes = { route }, QuestLookup = {} }
            local session = Model:Open(route)
            if LoginDraftCase == "legacy_base" or LoginDraftCase == "unchanged_with_capture" or LoginDraftCase == "legacy_real_edit" then
                -- Older builds stored literal values/order instead of the current
                -- formatted APR constants. These bases represent the same data.
                local baseline = AprRC:CopyData(session.draft); baseline.name = nil
                session.base = AprRC:SerializeData(baseline)
                session:Snapshot()
                if LoginDraftCase == "unchanged_with_capture" then
                    route.steps[2] = { Note = "Captured after the no-op draft" }
                elseif LoginDraftCase == "legacy_real_edit" then
                    session.draft.steps[1].Note = "Manual edit"; session:Snapshot()
                    route.steps[2] = { Note = "Concurrent capture" }
                end
            elseif LoginDraftCase == "comment_edit" then
                session:SetRaw("--keep this note\\n" .. Model:RouteText(session.draft))
                session:Persist()
            else
                session.draft.steps[1].Note = "Manual edit"; session:Snapshot()
                if LoginDraftCase == "saved_elsewhere" or LoginDraftCase == "raw_saved_elsewhere" then
                    route.steps[1].Note = "Manual edit"
                    if LoginDraftCase == "raw_saved_elsewhere" then
                        session:SetRaw(Model:RouteText(session.draft) .. "\\n")
                        session:Persist()
                    end
                elseif LoginDraftCase == "invalid_lua" then
                    route.steps[1].Note = "Manual edit"
                    session:SetRaw("{ steps = { -- unfinished"); session:Persist()
                else route.steps[2] = { Note = "Concurrent capture" } end
            end
            assert(AprRCData.EditorDrafts[route.name], "The fixture must persist a draft")
            return AprRC:SerializeData(AprRCData)
        ''')
        second = runtime()
        second.globals().SerializedState = saved
        second.globals().LoginDraftCase = case
        second.execute('''
            AprRCData = assert(AprRC:ParseLuaData(SerializedState))
            local Model, route = AprRC.editorModel, AprRCData.CurrentRoute
            local before = Model:RouteText(route)
            local session = Model:Open(route)
            local realEdit = LoginDraftCase == "real_edit" or LoginDraftCase == "legacy_real_edit"
            if realEdit or LoginDraftCase == "invalid_lua" or LoginDraftCase == "comment_edit" then
                assert(session:IsDirty() and AprRCData.EditorDrafts[route.name],
                    "Login must retain real edits: " .. LoginDraftCase)
                if realEdit then
                    assert(session.draft.steps[1].Note == "Manual edit" and session:IsStale())
                    local plan = assert(session:MergePlan())
                    assert(#plan.conflicts == 0 and session:ApplyMerge(plan, {}, true))
                    assert(AprRCData.CurrentRoute.steps[1].Note == "Manual edit")
                    assert(AprRCData.CurrentRoute.steps[2].Note == "Concurrent capture")
                elseif LoginDraftCase == "invalid_lua" then assert(not session:Read())
                else assert(session.raw:find("--keep this note", 1, true)) end
            else
                assert(not session:IsDirty(), "No-op restored draft would cause a login warning: " .. LoginDraftCase)
                assert(not session:IsStale() and not AprRCData.EditorDrafts[route.name])
                if LoginDraftCase == "unchanged_with_capture" then
                    assert(session.draft.steps[2].Note == "Captured after the no-op draft")
                end
            end
            if not realEdit then
                assert(Model:RouteText(route) == before, "Reconciling login drafts must not mutate saved routes")
            end
        ''')
    print("Login drafts: legacy baselines, already saved data, captures, real edits, comments and invalid Lua passed.")


if __name__ == "__main__":
    run()
