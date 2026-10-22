#Requires AutoHotkey v2

; High-level desktop-app API (actionType: desktopAppActions).
; Menu params come from searchActions.json → menuItem["action"].
; action.operation: string or array of strings (run in order).
; Same JSON field names as browserActions where possible:
;   appIdentifier, multiWinIdentifier, fileTitle, filePath
; openOrFocus: filePath = app exe (optional if known default).
; openFile:    filePath = document path (opened with appIdentifier, e.g. Notepad++).
class DesktopAppActions {
    ; Entry from searchBoxHandler for actionType "desktopAppActions".
    static Run(menuItem, ownerHwnd := 0) {
        cfg := DesktopAppActions.GetActionConfig(menuItem)
        ops := DesktopAppActions.NormalizeOperations(cfg, "")
        if (ops.Length = 0)
            throw Error("desktopAppActions requires a non-empty action.operation.")

        last := Map("ok", true, "silent", true)
        for op in ops {
            last := DesktopAppActions.RunOne(op, cfg, ownerHwnd)
        }
        if !last.Has("silent")
            last["silent"] := true
        return last
    }

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

    static RunOne(operation, cfg, ownerHwnd := 0) {
        switch operation {
            case "openOrFocus":
                appIdentifier := DesktopAppActions.CfgStr(cfg, "appIdentifier")
                multiWinIdentifier := DesktopAppActions.CfgStr(cfg, "multiWinIdentifier")
                fileTitle := DesktopAppActions.CfgStr(cfg, "fileTitle")
                filePath := DesktopAppActions.CfgStr(cfg, "filePath")

                if (appIdentifier = "")
                    throw Error("desktopAppActions openOrFocus requires action.appIdentifier.")

                result := DesktopAppActions.OpenOrFocus(appIdentifier, multiWinIdentifier, fileTitle, filePath)
                result["silent"] := true
                return result

            case "openFile":
                appIdentifier := DesktopAppActions.CfgStr(cfg, "appIdentifier")
                fileTitle := DesktopAppActions.CfgStr(cfg, "fileTitle")
                filePath := DesktopAppActions.CfgStr(cfg, "filePath")

                if (appIdentifier = "")
                    throw Error("desktopAppActions openFile requires action.appIdentifier.")
                if (filePath = "")
                    throw Error("desktopAppActions openFile requires action.filePath (document path).")

                return DesktopAppActions.OpenOrFocusFile(appIdentifier, filePath, fileTitle)

            default:
                throw Error("Unknown desktopAppActions operation: " operation)
        }
    }

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

    ; Focus matching window; if none, launch filePath (or known default for app).
    ; Returns Map: ok, focused, opened.
    static OpenOrFocus(appIdentifier, multiWinIdentifier := "", fileTitle := "", filePath := "") {
        if DesktopAppWindows.Focus(appIdentifier, multiWinIdentifier, fileTitle)
            return Map("ok", true, "focused", true, "opened", false)

        DesktopAppLaunch.Open(appIdentifier, filePath)
        return Map("ok", true, "focused", false, "opened", true)
    }

    ; Focus app window whose title contains fileTitle (or document filename);
    ; if none, open documentPath with that app.
    ; If exe missing → error notification: "Error: {appIdentifier} not found".
    static OpenOrFocusFile(appIdentifier, documentPath, fileTitle := "") {
        if (DesktopAppLaunch.ResolveExe(appIdentifier, "") = "") {
            return Map(
                "ok", false,
                "focused", false,
                "opened", false,
                "silent", false,
                "type", "error",
                "title", ConfigAppSettings.APP_NAME,
                "message", "Error: " appIdentifier " not found"
            )
        }

        title := Trim(fileTitle)
        if (title = "") {
            resolved := DesktopAppLaunch.ResolveDocumentPath(documentPath)
            SplitPath(resolved, &name)
            title := name
        }

        if (title != "" && DesktopAppWindows.Focus(appIdentifier, "", title))
            return Map("ok", true, "focused", true, "opened", false, "silent", true)

        DesktopAppLaunch.OpenDocument(appIdentifier, documentPath)
        return Map("ok", true, "focused", false, "opened", true, "silent", true)
    }
}
