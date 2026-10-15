#Requires AutoHotkey v2

; High-level desktop-app API (actionType: desktopAppActions).
; Menu params come from searchActions.json → menuItem["action"].
; Same JSON field names as browserActions where possible:
;   appIdentifier, multiWinIdentifier, fileTitle, filePath
class DesktopAppActions {
    ; Entry from searchBoxHandler for actionType "desktopAppActions".
    static Run(menuItem, ownerHwnd := 0) {
        cfg := DesktopAppActions.GetActionConfig(menuItem)
        operation := cfg.Has("operation") ? Trim(String(cfg["operation"])) : ""

        switch operation {
            case "openOrFocus":
                appIdentifier := DesktopAppActions.CfgStr(cfg, "appIdentifier")
                multiWinIdentifier := DesktopAppActions.CfgStr(cfg, "multiWinIdentifier")
                fileTitle := DesktopAppActions.CfgStr(cfg, "fileTitle")
                filePath := DesktopAppActions.CfgStr(cfg, "filePath")

                if (appIdentifier = "")
                    throw Error("desktopAppActions openOrFocus requires action.appIdentifier.")

                result := DesktopAppActions.OpenOrFocus(appIdentifier, multiWinIdentifier, fileTitle, filePath)
                ; Handoff focus to the target app; handler must not FocusOwner afterward.
                result["silent"] := true
                result["handoffFocus"] := true
                return result

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
}
