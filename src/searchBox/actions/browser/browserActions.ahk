#Requires AutoHotkey v2

; High-level browser API (actionType: browserActions).
; Menu params come from searchActions.json → menuItem["action"].
; action.operation: string or array of strings (run in order).
;   Builtin: showTip | openOrFocusByTitle | openOrFocusByTitleAndUrl | login
;   Reusable: "reusable__…" → look up searchActions.reusables[id] (loginSteps etc.).
;   Caller action id is kept for LOGIN_DEPENDENCY_PATH lookup (env-specific creds).
; Implementations live in sibling modules: browserDetails / browserTabs / browserLaunch / etc.
class BrowserActions {
    ; Entry from searchBoxHandler for actionType "browserActions".
    static Run(menuItem, ownerHwnd := 0) {
        cfg := BrowserActions.GetActionConfig(menuItem)
        actionId := (IsObject(menuItem) && menuItem.Has("id")) ? Trim(String(menuItem["id"])) : ""
        ops := BrowserActions.NormalizeOperations(cfg, "showTip")
        if (ops.Length = 0)
            throw Error("browserActions requires a non-empty action.operation.")

        last := Map("ok", true, "silent", true)
        for op in ops {
            last := BrowserActions.RunOperation(op, cfg, ownerHwnd, actionId)
        }
        if !last.Has("silent")
            last["silent"] := true
        return last
    }

    ; string → [string]; array → trimmed non-empty strings; missing → [defaultOp].
    static NormalizeOperations(cfg, defaultOp := "") {
        if !IsObject(cfg) || !cfg.Has("operation") {
            if (defaultOp != "")
                return [defaultOp]
            return []
        }

        raw := cfg["operation"]
        ops := []
        if (raw is Array) {
            for item in raw {
                op := Trim(String(item))
                if (op != "")
                    ops.Push(op)
            }
            return ops
        }

        op := Trim(String(raw))
        if (op != "")
            return [op]
        if (defaultOp != "")
            return [defaultOp]
        return []
    }

    ; Builtin op or reusable__* expansion. actionId always stays the calling menu item id.
    static RunOperation(operation, cfg, ownerHwnd := 0, actionId := "") {
        if BrowserActions.IsReusableId(operation)
            return BrowserActions.RunReusable(operation, cfg, ownerHwnd, actionId)
        return BrowserActions.RunOne(operation, cfg, ownerHwnd, actionId)
    }

    static IsReusableId(operation) {
        return (SubStr(Trim(operation), 1, 10) = "reusable__")
    }

    ; Merge reusable fields (except operation) onto caller cfg; run reusable's operation(s).
    static RunReusable(reusableId, callerCfg, ownerHwnd := 0, actionId := "") {
        reusableId := Trim(reusableId)
        reusables := SearchActionsConfig.Reusables
        if !(reusables is Map) || !reusables.Has(reusableId) || !(reusables[reusableId] is Map)
            throw Error("browserActions: unknown reusable '" reusableId "'.")

        reusable := reusables[reusableId]
        runCfg := BrowserActions.MergeReusableCfg(callerCfg, reusable)
        ops := BrowserActions.NormalizeOperations(reusable)
        if (ops.Length = 0)
            throw Error("browserActions reusable '" reusableId "' requires a non-empty operation.")

        last := Map("ok", true, "silent", true)
        for op in ops {
            if BrowserActions.IsReusableId(op)
                throw Error("browserActions: nested reusables are not supported ('" op "' inside '" reusableId "').")
            last := BrowserActions.RunOne(op, runCfg, ownerHwnd, actionId)
        }
        if !last.Has("silent")
            last["silent"] := true
        return last
    }

    ; Caller wins on shared keys except reusable-owned fields are copied when set on reusable.
    ; operation is never copied onto runCfg (driven only by NormalizeOperations on reusable).
    static MergeReusableCfg(callerCfg, reusable) {
        runCfg := Map()
        if (callerCfg is Map) {
            for key, value in callerCfg
                runCfg[key] := value
        }
        if (reusable is Map) {
            for key, value in reusable {
                if (key = "operation")
                    continue
                runCfg[key] := value
            }
        }
        return runCfg
    }

    static RunOne(operation, cfg, ownerHwnd := 0, actionId := "") {
        switch operation {
            case "showTip":
                BrowserActions.ShowBrowserTip(ownerHwnd)
                return Map("ok", true, "silent", true)

            case "openOrFocusByTitle":
                result := BrowserActions.RunOpenOrFocus(cfg, false)
                result["silent"] := true
                return result

            case "openOrFocusByTitleAndUrl":
                result := BrowserActions.RunOpenOrFocus(cfg, true)
                result["silent"] := true
                return result

            case "login":
                return BrowserLogin.Run(cfg, actionId)

            default:
                throw Error("Unknown browserActions operation: " operation)
        }
    }

    ; Shared open/focus for title-only vs title+URL operations.
    ; matchUrl=true → focus confirms with filePath via UIA; both fileTitle and filePath required.
    static RunOpenOrFocus(cfg, matchUrl) {
        opName := matchUrl ? "openOrFocusByTitleAndUrl" : "openOrFocusByTitle"
        browserName := BrowserActions.CfgStr(cfg, "appIdentifier")
        primaryLabel := BrowserActions.CfgStr(cfg, "multiWinIdentifier")
        tabTitle := BrowserActions.CfgStr(cfg, "fileTitle")
        filePath := BrowserActions.CfgStr(cfg, "filePath")

        if (browserName = "")
            throw Error("browserActions " opName " requires action.appIdentifier.")

        if matchUrl {
            if (tabTitle = "")
                throw Error("browserActions " opName " requires action.fileTitle.")
            if (filePath = "")
                throw Error("browserActions " opName " requires action.filePath.")
        } else if (tabTitle = "" && filePath = "") {
            throw Error("browserActions " opName " requires action.fileTitle and/or action.filePath.")
        }

        return BrowserActions.OpenOrFocus(tabTitle, filePath, browserName, primaryLabel, matchUrl)
    }

    ; Nested action object from JSON, or empty Map.
    static GetActionConfig(menuItem) {
        if IsObject(menuItem) && menuItem.Has("action") && IsObject(menuItem["action"])
            return menuItem["action"]
        return Map()
    }

    static CfgStr(cfg, key) {
        if !IsObject(cfg) || !cfg.Has(key)
            return ""
        return Trim(String(cfg[key]))
    }

    ; Show inspect tip for the browser under ReCtrl.
    static ShowBrowserTip(ownerHwnd := 0) {
        if !(ownerHwnd && AppContext.CaptureBrowserUnder(ownerHwnd))
            AppContext.RefreshUnderlying(ownerHwnd)

        details := BrowserDetails.CollectBrowserDetails(ownerHwnd)
        text := BrowserDetails.FormatBrowserDetails(details)
        BrowserDetails.ShowOwnedMessage(text, ConfigAppSettings.APP_NAME " — Browser", ownerHwnd)
    }

    ; Focus an open tab whose title contains tabTitle (target browser + optional primary label).
    static FocusTabByTitle(tabTitle, browserName, primaryLabel := "") {
        return BrowserTabs.FocusByTitle(tabTitle, browserName, primaryLabel)
    }

    ; Open url/path in the target browser + optional primary-label profile.
    static OpenUrl(url, browserName, primaryLabel := "") {
        BrowserLaunch.OpenUrl(url, browserName, primaryLabel)
    }

    ; Focus by title; if matchUrl, also require URL match (UIA). Else open url.
    ; Returns Map: ok, focused (bool), opened (bool).
    static OpenOrFocus(tabTitle, url, browserName, primaryLabel := "", matchUrl := false) {
        urlNeedle := matchUrl ? url : ""
        if (tabTitle != "" && BrowserTabs.FocusByTitle(tabTitle, browserName, primaryLabel, urlNeedle))
            return Map("ok", true, "focused", true, "opened", false)

        if (url = "")
            throw Error("Tab not found and action.filePath is empty; nothing to open.")

        BrowserActions.OpenUrl(url, browserName, primaryLabel)
        return Map("ok", true, "focused", false, "opened", true)
    }

    ; Title-only focus, then open. Kept for callers / readability.
    static OpenOrFocusByTitle(tabTitle, url, browserName, primaryLabel := "") {
        return BrowserActions.OpenOrFocus(tabTitle, url, browserName, primaryLabel, false)
    }

    ; Title + URL focus, then open.
    static OpenOrFocusByTitleAndUrl(tabTitle, url, browserName, primaryLabel := "") {
        return BrowserActions.OpenOrFocus(tabTitle, url, browserName, primaryLabel, true)
    }
}
