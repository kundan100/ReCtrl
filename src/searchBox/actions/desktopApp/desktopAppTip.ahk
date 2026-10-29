#Requires AutoHotkey v2

; Tip orchestrator (desktopAppActions operation: showTip).
; Collects via DesktopAppDetails + BrowserDetails; shows via CustomPopup.
class DesktopAppTip {
    ; Entry for operation "showTip". Returns Map: ok, silent.
    static Show(ownerHwnd := 0) {
        appDetails := DesktopAppDetails.Collect(ownerHwnd)
        browserExtra := ""
        if (appDetails.Has("ok") && appDetails["ok"]
            && DesktopAppDetails.IsBrowserExe(DesktopAppDetails.StrOr(appDetails, "exe", "")))
            browserExtra := DesktopAppTip.CollectBrowserExtra(appDetails, ownerHwnd)

        text := DesktopAppTip.FormatDetails(appDetails, browserExtra)
        CustomPopup.Show(text, ConfigAppSettings.APP_NAME " — Tip", ownerHwnd)
        return Map("ok", !!(appDetails.Has("ok") && appDetails["ok"]), "silent", true)
    }

    ; Assemble: App details sections + optional browser-only sections.
    static FormatDetails(appDetails, browserExtra := unset) {
        if !IsObject(appDetails)
            return "No details available."

        if !(appDetails.Has("ok") && appDetails["ok"]) {
            err := appDetails.Has("error") ? Trim(String(appDetails["error"])) : ""
            return err != "" ? err : "No details available."
        }

        ; Prefer richer browser collect map for app/window fields when present.
        appMap := appDetails
        if IsSet(browserExtra) && IsObject(browserExtra)
            && browserExtra.Has("ok") && browserExtra["ok"]
            appMap := browserExtra

        lines := []
        lines.Push("# App details")
        DesktopAppDetails.AppendAppWindowSections(lines, appMap)

        if IsSet(browserExtra) && IsObject(browserExtra) {
            lines.Push("")
            lines.Push("# Additional details (browser)")
            lines.Push("")
            BrowserDetails.AppendBrowserOnlySections(lines, browserExtra)
        }

        return DesktopAppDetails.JoinLines(lines)
    }

    ; Seed AppContext for BrowserDetails.CollectBrowserDetails, then restore.
    static CollectBrowserExtra(appDetails, ownerHwnd := 0) {
        hwnd := appDetails.Has("hwnd") ? appDetails["hwnd"] : 0
        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd)
            return Map("ok", false, "error", "Browser window handle is no longer valid.")

        prevLast := AppContext.last
        AppContext.last := Map(
            "hwnd", hwnd,
            "exe", appDetails.Has("exe") ? appDetails["exe"] : "",
            "title", appDetails.Has("title") ? appDetails["title"] : "",
            "class", appDetails.Has("class") ? appDetails["class"] : "",
            "kind", "browser",
            "appIdentifier", "",
            "multiWinIdentifier", ""
        )
        try {
            return BrowserDetails.CollectBrowserDetails(ownerHwnd)
        } finally {
            AppContext.last := prevLast
        }
    }
}
