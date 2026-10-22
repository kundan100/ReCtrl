#Requires AutoHotkey v2

; High-level browser API (actionType: browserActions).
; Menu params come from searchActions.json → menuItem["action"].
; Implementations live in sibling modules: browserDetails / browserTabs / browserLaunch / etc.
class BrowserActions {
    ; Entry from searchBoxHandler for actionType "browserActions".
    static Run(menuItem, ownerHwnd := 0) {
        cfg := BrowserActions.GetActionConfig(menuItem)
        operation := cfg.Has("operation") ? Trim(String(cfg["operation"])) : "showTip"

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
