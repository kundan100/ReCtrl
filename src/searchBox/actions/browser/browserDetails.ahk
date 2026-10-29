#Requires AutoHotkey v2

; Browser details helpers: collect details, read URL, format text, show message.
class BrowserDetails {
    ; Gather all readable details about the current browser context window.
    static CollectBrowserDetails(restoreHwnd := 0) {
        info := Map(
            "ok", false,
            "kind", AppContext.GetCurrentKind(),
            "contextEnabled", AppContext.IsEnabled()
        )

        if !IsObject(AppContext.last) {
            info["error"] := "No browser context captured."
            return info
        }

        hwnd := AppContext.last.Has("hwnd") ? AppContext.last["hwnd"] : 0
        info["hwnd"] := hwnd
        info["exe"] := AppContext.last.Has("exe") ? AppContext.last["exe"] : ""
        info["title"] := AppContext.last.Has("title") ? AppContext.last["title"] : ""
        info["class"] := AppContext.last.Has("class") ? AppContext.last["class"] : ""
        info["kind"] := AppContext.last.Has("kind") ? AppContext.last["kind"] : ""

        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd) {
            info["error"] := "Browser window handle is no longer valid."
            info["windowValid"] := false
            return info
        }

        info["windowValid"] := true
        info["ok"] := true

        try {
            info["pid"] := WinGetPID(hwnd)
        } catch {
            info["pid"] := ""
        }

        try {
            info["processPath"] := WinGetProcessPath(hwnd)
        } catch {
            info["processPath"] := ""
        }

        try {
            info["minMax"] := WinGetMinMax(hwnd)  ; -1 minimized, 0 normal, 1 maximized
        } catch {
            info["minMax"] := ""
        }

        try {
            info["transparent"] := WinGetTransparent(hwnd)
        } catch {
            info["transparent"] := ""
        }

        try {
            info["style"] := Format("0x{:08X}", WinGetStyle(hwnd))
        } catch {
            info["style"] := ""
        }

        try {
            info["exStyle"] := Format("0x{:08X}", WinGetExStyle(hwnd))
        } catch {
            info["exStyle"] := ""
        }

        try {
            info["isVisible"] := !!DllCall("IsWindowVisible", "Ptr", hwnd)
        } catch {
            info["isVisible"] := ""
        }

        try {
            info["isMinimized"] := !!DllCall("IsIconic", "Ptr", hwnd)
        } catch {
            info["isMinimized"] := ""
        }

        try {
            info["isZoomed"] := !!DllCall("IsZoomed", "Ptr", hwnd)
        } catch {
            info["isZoomed"] := ""
        }

        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            info["x"] := wx
            info["y"] := wy
            info["width"] := ww
            info["height"] := wh
        } catch {
            info["x"] := ""
            info["y"] := ""
            info["width"] := ""
            info["height"] := ""
        }

        try {
            WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
            info["clientX"] := cx
            info["clientY"] := cy
            info["clientWidth"] := cw
            info["clientHeight"] := ch
        } catch {
            info["clientX"] := ""
            info["clientY"] := ""
            info["clientWidth"] := ""
            info["clientHeight"] := ""
        }

        try {
            info["controlCount"] := WinGetControlsHwnd(hwnd).Length
        } catch {
            info["controlCount"] := ""
        }

        try {
            focused := ControlGetFocus("ahk_id " hwnd)
            info["activeControl"] := focused ? focused : ""
        } catch {
            info["activeControl"] := ""
        }

        try {
            info["titleLive"] := WinGetTitle(hwnd)
        } catch {
            info["titleLive"] := info["title"]
        }

        try {
            info["classLive"] := WinGetClass(hwnd)
        } catch {
            info["classLive"] := info["class"]
        }

        try {
            info["exeLive"] := WinGetProcessName(hwnd)
        } catch {
            info["exeLive"] := info["exe"]
        }

        try {
            info["minMaxLabel"] := BrowserDetails.MinMaxLabel(info["minMax"])
        } catch {
            info["minMaxLabel"] := ""
        }

        exeForProfile := info["exeLive"] != "" ? info["exeLive"] : info["exe"]
        pathForProfile := info.Has("processPath") ? info["processPath"] : ""
        info["browserName"] := BrowserProfile.GuessBrowserName(exeForProfile, pathForProfile)

        profileInfo := BrowserProfile.CollectBrowserProfile(info["pid"], exeForProfile, pathForProfile, hwnd)
        info["profileDirectory"] := profileInfo["profileDirectory"]
        info["profileName"] := profileInfo["profileName"]
        info["profileAccount"] := profileInfo["profileAccount"]
        info["profileSignedIn"] := profileInfo["profileSignedIn"]
        info["profileDisplayName"] := profileInfo["profileDisplayName"]
        info["profileGaiaName"] := profileInfo["profileGaiaName"]
        info["profileUserName"] := profileInfo["profileUserName"]
        info["userDataDir"] := profileInfo["userDataDir"]
        info["profilePath"] := profileInfo["profilePath"]
        info["profileCommandLine"] := profileInfo["commandLine"]
        info["profileMainPid"] := profileInfo["mainPid"]
        info["profileSource"] := profileInfo["source"]
        info["profileAppId"] := profileInfo["appId"]
        info["profileNote"] := profileInfo["note"]

        urlInfo := BrowserDetails.CollectBrowserUrl(hwnd, restoreHwnd)
        info["url"] := urlInfo["url"]
        info["urlSource"] := urlInfo["source"]
        info["urlNote"] := urlInfo["note"]

        return info
    }

    ; Prefer quiet UIA Value read (document / omnibox); fall back to Ctrl+L / Ctrl+C.
    static CollectBrowserUrl(hwnd, restoreHwnd := 0) {
        result := Map(
            "url", "",
            "source", "",
            "note", ""
        )
        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd) {
            result["note"] := "No valid browser window for URL lookup."
            return result
        }

        try {
            uiaUrl := BrowserTabs.ReadActiveUrlViaUia(hwnd)
            if (uiaUrl != "") {
                result["url"] := uiaUrl
                result["source"] := "uia (document/omnibox Value)"
                result["note"] := ""
                return result
            }
        } catch {
            ; fall through to clipboard path
        }

        clipSaved := ClipboardAll()
        A_Clipboard := ""

        try {
            WinActivate("ahk_id " hwnd)
            if !WinWaitActive("ahk_id " hwnd, , 1.5) {
                result["note"] := "Could not activate browser to read URL (UIA empty)."
                return result
            }

            Sleep(100)
            SendInput("^l")   ; focus address / omnibox
            Sleep(150)
            SendInput("^c")   ; copy URL
            if !ClipWait(1.2) {
                result["note"] := "Timed out waiting for URL from address bar."
                return result
            }

            url := Trim(A_Clipboard)
            SendInput("{Esc}")  ; leave address bar selection

            if (url = "") {
                result["note"] := "Address bar copy returned empty."
                return result
            }

            result["url"] := url
            result["source"] := "address-bar (Ctrl+L, Ctrl+C)"
            result["note"] := ""
        } catch as err {
            result["note"] := "URL read failed: " err.Message
        } finally {
            try A_Clipboard := clipSaved
            if restoreHwnd && DllCall("IsWindow", "Ptr", restoreHwnd) {
                WinActivate("ahk_id " restoreHwnd)
                WinWaitActive("ahk_id " restoreHwnd, , 1)
            }
        }

        return result
    }

    ; Full text for standalone browser tip (all sections).
    static FormatBrowserDetails(details) {
        if !IsObject(details) {
            return "Unable to collect browser details."
        }

        lines := []
        lines.Push("Browser details")
        lines.Push("")
        lines.Push("Context enabled: " (details.Has("contextEnabled") && details["contextEnabled"] ? "true" : "false"))
        lines.Push("Kind: " BrowserDetails.StrOr(details, "kind", "(none)"))
        lines.Push("Browser: " BrowserDetails.StrOr(details, "browserName", "(unknown)"))

        if details.Has("error") && details["error"] != "" {
            lines.Push("")
            lines.Push("Error: " details["error"])
            return BrowserDetails.JoinLines(lines)
        }

        ; Window sections from DesktopAppDetails; URL stays under Identity for this tip.
        DesktopAppDetails.AppendTargetWindowSection(lines, details)
        DesktopAppDetails.AppendIdentitySection(lines, details)
        BrowserDetails.AppendUrlLines(lines, details)
        BrowserDetails.AppendProfileSection(lines, details)
        DesktopAppDetails.AppendWindowStateSection(lines, details)
        DesktopAppDetails.AppendGeometrySection(lines, details)
        DesktopAppDetails.AppendControlsSection(lines, details)
        return BrowserDetails.JoinLines(lines)
    }

    ; Browser-only bits for Tip "Additional details (browser)".
    static AppendBrowserOnlySections(lines, details) {
        lines.Push("Browser: " BrowserDetails.StrOr(details, "browserName", "(unknown)"))
        BrowserDetails.AppendUrlSection(lines, details)
        BrowserDetails.AppendProfileSection(lines, details)
    }

    static AppendSectionHeader(lines, title) {
        lines.Push("")
        lines.Push("--- " title " ---")
    }

    static AppendUrlSection(lines, details) {
        BrowserDetails.AppendSectionHeader(lines, "URL")
        BrowserDetails.AppendUrlLines(lines, details)
    }

    static AppendUrlLines(lines, details) {
        urlText := details.Has("url") ? Trim(String(details["url"])) : ""
        lines.Push("URL: " (urlText != "" ? urlText : "(not available)"))
        if (urlText != "" && details.Has("urlSource") && details["urlSource"] != "")
            lines.Push("URL source: " details["urlSource"])
        if (urlText = "" && details.Has("urlNote") && details["urlNote"] != "")
            lines.Push("URL note: " details["urlNote"])
    }

    static AppendProfileSection(lines, details) {
        BrowserDetails.AppendSectionHeader(lines, "Profile")
        mainPid := BrowserDetails.StrOr(details, "profileMainPid", "")
        if (mainPid != "" && mainPid != BrowserDetails.StrOr(details, "pid"))
            lines.Push("Browser main PID: " mainPid)

        signedIn := details.Has("profileSignedIn") && details["profileSignedIn"]
        lines.Push("Signed in: " (signedIn ? "yes" : "no"))
        if signedIn {
            lines.Push("Account: " BrowserDetails.StrOr(details, "profileAccount", "(n/a)"))
            lines.Push("Profile name: " BrowserDetails.StrOr(details, "profileName", "(n/a)"))
        } else {
            lines.Push("Account: (not signed in)")
            lines.Push("Profile name: " BrowserDetails.StrOr(details, "profileName", BrowserDetails.StrOr(details, "profileDisplayName", "(n/a)")))
        }
        lines.Push("Primary label: " BrowserDetails.StrOr(details, "profileDisplayName", "(n/a)"))
        lines.Push("Directory: " BrowserDetails.StrOr(details, "profileDirectory", "(n/a)"))
        lines.Push("User data dir: " BrowserDetails.StrOr(details, "userDataDir", "(n/a)"))
        lines.Push("Profile path: " BrowserDetails.StrOr(details, "profilePath", "(n/a)"))
        lines.Push("Profile source: " BrowserDetails.StrOr(details, "profileSource", "(n/a)"))
        if details.Has("profileAppId") && details["profileAppId"] != ""
            lines.Push("AppUserModelID: " details["profileAppId"])
        if details.Has("profileNote") && details["profileNote"] != ""
            lines.Push("Profile note: " details["profileNote"])
        cmd := details.Has("profileCommandLine") ? String(details["profileCommandLine"]) : ""
        if (cmd != "")
            lines.Push("Profile switches: " BrowserProfile.SummarizeProfileSwitches(cmd))
        else
            lines.Push("Profile switches: (command line unavailable)")
    }

    static MinMaxLabel(minMax) {
        switch minMax {
            case -1:
                return "minimized"
            case 0:
                return "normal"
            case 1:
                return "maximized"
            default:
                return "unknown"
        }
    }

    static StrOr(details, key, fallback := "") {
        if !details.Has(key) || details[key] = ""
            return fallback != "" ? fallback : "(n/a)"
        return String(details[key])
    }

    static BoolStr(details, key) {
        if !details.Has(key) || details[key] = ""
            return "(n/a)"
        return details[key] ? "true" : "false"
    }

    static JoinLines(lines) {
        out := ""
        for i, line in lines {
            out .= (i > 1 ? "`n" : "") line
        }
        return out
    }

    static ShowOwnedMessage(text, title := unset, ownerHwnd := 0) {
        if !IsSet(title)
            title := ConfigAppSettings.APP_NAME
        if ownerHwnd {
            MsgBox(text, title, "Owner" ownerHwnd)
        } else {
            MsgBox(text, title)
        }
    }
}
