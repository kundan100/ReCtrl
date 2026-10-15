#Requires AutoHotkey v2

; Tracks the app currently under ReCtrl for context-aware menus.
; searchConfig flags start from searchActions.json and can be toggled for this session only.
class AppContext {
    static last := ""
    static enabled := true
    static typingRespectsContext := true
    static recentsRespectsContext := true
    static focusOverrideAllowedByIndividualTask := false
    static enabledListeners := []
    static GW_HWNDNEXT := 2

    ; Apply launch defaults from searchConfig (fresh each script start).
    static ApplySearchConfig(searchConfig) {
        if !IsObject(searchConfig)
            return
        if searchConfig.Has("CONTEXT_ENABLED")
            AppContext.SetEnabled(!!searchConfig["CONTEXT_ENABLED"])
        if searchConfig.Has("TYPING_RESPECTS_CONTEXT")
            AppContext.typingRespectsContext := !!searchConfig["TYPING_RESPECTS_CONTEXT"]
        if searchConfig.Has("RECENTS_RESPECTS_CONTEXT")
            AppContext.recentsRespectsContext := !!searchConfig["RECENTS_RESPECTS_CONTEXT"]
        if searchConfig.Has("FOCUS_OVERRIDE_ALLOWED_BY_INDIVIDUAL_TASK")
            AppContext.focusOverrideAllowedByIndividualTask := !!searchConfig["FOCUS_OVERRIDE_ALLOWED_BY_INDIVIDUAL_TASK"]
    }

    static IsEnabled() {
        return AppContext.enabled
    }

    ; Session flag for searchConfig booleans (CONTEXT_ENABLED, TYPING_…, FOCUS_OVERRIDE_…).
    static GetSearchConfigFlag(key) {
        switch Trim(String(key)) {
            case "CONTEXT_ENABLED":
                return AppContext.IsEnabled()
            case "TYPING_RESPECTS_CONTEXT":
                return AppContext.typingRespectsContext
            case "RECENTS_RESPECTS_CONTEXT":
                return AppContext.recentsRespectsContext
            case "FOCUS_OVERRIDE_ALLOWED_BY_INDIVIDUAL_TASK":
                return AppContext.focusOverrideAllowedByIndividualTask
            default:
                throw Error("Unknown searchConfig flag: " key)
        }
    }

    static SetSearchConfigFlag(key, value) {
        switch Trim(String(key)) {
            case "CONTEXT_ENABLED":
                AppContext.SetEnabled(!!value)
            case "TYPING_RESPECTS_CONTEXT":
                AppContext.typingRespectsContext := !!value
            case "RECENTS_RESPECTS_CONTEXT":
                AppContext.recentsRespectsContext := !!value
            case "FOCUS_OVERRIDE_ALLOWED_BY_INDIVIDUAL_TASK":
                AppContext.focusOverrideAllowedByIndividualTask := !!value
            default:
                throw Error("Unknown searchConfig flag: " key)
        }
    }

    ; Current captured kind (browser, notepad, terminal, ...), or "" if none.
    static GetCurrentKind() {
        if !IsObject(AppContext.last)
            return ""
        if !AppContext.last.Has("kind")
            return ""
        return AppContext.last["kind"]
    }

    ; Browser display name (e.g. "Google Chrome"), or "".
    static GetCurrentAppIdentifier() {
        if !IsObject(AppContext.last) || !AppContext.last.Has("appIdentifier")
            return ""
        return AppContext.last["appIdentifier"]
    }

    ; Primary label / signed-in account for current browser profile, or "".
    static GetCurrentMultiWinIdentifier() {
        if !IsObject(AppContext.last) || !AppContext.last.Has("multiWinIdentifier")
            return ""
        return AppContext.last["multiWinIdentifier"]
    }

    static SetEnabled(enabled) {
        next := !!enabled
        if (AppContext.enabled = next)
            return
        AppContext.enabled := next
        for callback in AppContext.enabledListeners {
            try callback.Call(AppContext.enabled)
        }
    }

    static OnEnabledChanged(callback) {
        if callback
            AppContext.enabledListeners.Push(callback)
    }

    static Clear() {
        AppContext.last := ""
    }

    static CaptureFromHwnd(hwnd) {
        if !AppContext.enabled
            return false
        if !hwnd
            return false
        try {
            if !DllCall("IsWindow", "Ptr", hwnd)
                return false
            exeName := WinGetProcessName(hwnd)
            title := WinGetTitle(hwnd)
            className := WinGetClass(hwnd)
            kind := AppContext.GuessKind(exeName)
            processPath := ""
            try processPath := WinGetProcessPath(hwnd)
            pid := 0
            try pid := WinGetPID(hwnd)

            appIdentifier := ""
            multiWinIdentifier := ""
            if (kind = "browser") {
                try {
                    appIdentifier := BrowserProfile.GuessBrowserName(exeName, processPath)
                    profile := BrowserProfile.CollectBrowserProfile(pid, exeName, processPath, hwnd)
                    multiWinIdentifier := profile.Has("profileDisplayName") ? profile["profileDisplayName"] : ""
                    if (multiWinIdentifier = "" && profile.Has("profileAccount"))
                        multiWinIdentifier := profile["profileAccount"]
                } catch {
                    ; BrowserProfile may be unavailable; keep coarse kind only.
                }
            }

            AppContext.last := Map(
                "hwnd", hwnd,
                "exe", exeName,
                "title", title,
                "class", className,
                "kind", kind,
                "appIdentifier", appIdentifier,
                "multiWinIdentifier", multiWinIdentifier
            )
            return true
        } catch {
            return false
        }
    }

    ; Refresh context for menu filtering: prefer real foreground, else window under ReCtrl.
    ; Skips minimized / tool / shell windows so closed/minimized apps do not stick.
    static RefreshUnderlying(excludeHwnd := 0) {
        if !AppContext.enabled {
            return false
        }

        activeHwnd := WinExist("A")
        if activeHwnd && (!excludeHwnd || activeHwnd != excludeHwnd) {
            if AppContext.IsCandidateWindow(activeHwnd) {
                return AppContext.CaptureFromHwnd(activeHwnd)
            }
        }

        if excludeHwnd && AppContext.CaptureWindowUnder(excludeHwnd)
            return true

        AppContext.Clear()
        return false
    }

    ; Walk Z-order below excludeHwnd to find the next suitable app window.
    static CaptureWindowUnder(excludeHwnd) {
        if !excludeHwnd
            return false

        hwnd := DllCall("GetWindow", "Ptr", excludeHwnd, "UInt", AppContext.GW_HWNDNEXT, "Ptr")
        while hwnd {
            if AppContext.IsCandidateWindow(hwnd) {
                return AppContext.CaptureFromHwnd(hwnd)
            }
            hwnd := DllCall("GetWindow", "Ptr", hwnd, "UInt", AppContext.GW_HWNDNEXT, "Ptr")
        }
        return false
    }

    ; For browser actions: prefer the topmost *browser* under excludeHwnd (skip other apps in between).
    static CaptureBrowserUnder(excludeHwnd) {
        if !excludeHwnd
            return false

        hwnd := DllCall("GetWindow", "Ptr", excludeHwnd, "UInt", AppContext.GW_HWNDNEXT, "Ptr")
        while hwnd {
            if AppContext.IsCandidateWindow(hwnd) {
                try {
                    exeName := WinGetProcessName(hwnd)
                    if (AppContext.GuessKind(exeName) = "browser")
                        return AppContext.CaptureFromHwnd(hwnd)
                } catch {
                    ; keep walking
                }
            }
            hwnd := DllCall("GetWindow", "Ptr", hwnd, "UInt", AppContext.GW_HWNDNEXT, "Ptr")
        }
        return false
    }

    static IsCandidateWindow(hwnd) {
        if !hwnd
            return false
        try {
            if !DllCall("IsWindow", "Ptr", hwnd)
                return false
            if !DllCall("IsWindowVisible", "Ptr", hwnd)
                return false
            ; Minimized windows are not "under" ReCtrl for context purposes.
            if DllCall("IsIconic", "Ptr", hwnd)
                return false

            exStyle := WinGetExStyle(hwnd)
            if (exStyle & 0x80) ; WS_EX_TOOLWINDOW
                return false

            className := WinGetClass(hwnd)
            switch className {
                case "Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "DV2ControlHost", "Windows.UI.Core.CoreWindow":
                    return false
            }

            ; Skip untitled utility windows that are usually not the user's app.
            title := WinGetTitle(hwnd)
            if (Trim(title) = "" && className != "CabinetWClass")
                return false

            return true
        } catch {
            return false
        }
    }

    static GuessKind(exeName) {
        e := StrLower(exeName)
        switch e {
            case "chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe", "vivaldi.exe":
                return "browser"
            case "notepad.exe", "notepad++.exe":
                return "notepad"
            case "code.exe", "cursor.exe", "devenv.exe":
                return "editor"
            case "explorer.exe":
                return "file explorer"
            case "windowsterminal.exe", "cmd.exe", "powershell.exe", "pwsh.exe":
                return "terminal"
            default:
                return ""
        }
    }

    ; Context menu: show CONTEXT_ENABLED and offer to flip for this session only.
    static PromptToggleEnabled(ownerHwnd := 0) {
        return AppContext.PromptToggleSearchConfigFlag("CONTEXT_ENABLED", ownerHwnd)
    }

    ; Toggle a searchConfig session flag (does not write JSON; resets on relaunch).
    ; Yes/No confirm is gated by NotifyConfig.PROMPT_BEFORE_TOGGLE (code kept when false).
    static PromptToggleSearchConfigFlag(key, ownerHwnd := 0) {
        key := Trim(String(key))
        current := AppContext.GetSearchConfigFlag(key)
        currentText := current ? "true" : "false"
        nextText := current ? "false" : "true"

        if NotifyConfig.PROMPT_BEFORE_TOGGLE {
            prompt :=
                key ": " currentText "`n`n"
                . "Set it to " nextText " for this session?`n"
                . "(Resets to config/searchActions.json when you relaunch " ConfigApp.APP_NAME ".)"

            options := "YesNo"
            if ownerHwnd
                options .= " Owner" ownerHwnd

            answer := MsgBox(prompt, ConfigApp.APP_NAME " — Settings", options)
            if (answer = "Yes") {
                AppContext.SetSearchConfigFlag(key, !current)
                return Map(
                    "ok", true,
                    "title", ConfigApp.APP_NAME " — Settings",
                    "message", key " is now " (AppContext.GetSearchConfigFlag(key) ? "true" : "false")
                        . "`n`nThis lasts until you relaunch " ConfigApp.APP_NAME "."
                )
            }

            return Map(
                "ok", true,
                "title", ConfigApp.APP_NAME " — Settings",
                "message", key " left as " currentText
            )
        }

        ; Confirm gate off: flip immediately, then let caller show result feedback.
        AppContext.SetSearchConfigFlag(key, !current)
        return Map(
            "ok", true,
            "title", ConfigApp.APP_NAME " — Settings",
            "message", key " is now " (AppContext.GetSearchConfigFlag(key) ? "true" : "false")
                . "`n`nThis lasts until you relaunch " ConfigApp.APP_NAME "."
        )
    }

    static ShowContextResult() {
        if !AppContext.enabled {
            return Map(
                "ok", false,
                "title", ConfigApp.APP_NAME " — Context",
                "message", "CONTEXT_ENABLED is false.`nContext capture is off for this session."
            )
        }
        if !IsObject(AppContext.last) {
            return Map(
                "ok", false,
                "title", ConfigApp.APP_NAME " — Context",
                "message", "No context captured yet.`n`nFocus another app, then open " ConfigApp.APP_NAME " with double-Ctrl."
            )
        }

        info := AppContext.last
        kindLine := ""
        if (info.Has("kind") && info["kind"] != "")
            kindLine := "Kind: " info["kind"] "`n"
        appLine := ""
        if (info.Has("appIdentifier") && info["appIdentifier"] != "")
            appLine := "App: " info["appIdentifier"] "`n"
        profileLine := ""
        if (info.Has("multiWinIdentifier") && info["multiWinIdentifier"] != "")
            profileLine := "Primary label: " info["multiWinIdentifier"] "`n"

        text :=
            "App currently under " ConfigApp.APP_NAME ":`n`n"
            . kindLine
            . appLine
            . profileLine
            . "Exe: " info["exe"] "`n"
            . "Title: " info["title"] "`n"
            . "Class: " info["class"]

        return Map(
            "ok", true,
            "title", ConfigApp.APP_NAME " — Context",
            "message", text
        )
    }
}
