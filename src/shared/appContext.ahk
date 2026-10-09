#Requires AutoHotkey v2

; Tracks the app currently under ReCtrl for context-aware menus.
; CONTEXT_ENABLED starts from searchActions.json and can be toggled for this session only.
class AppContext {
    static last := ""
    static enabled := true
    static enabledListeners := []
    static GW_HWNDNEXT := 2

    ; Apply launch default from searchConfig (fresh each script start).
    static ApplySearchConfig(searchConfig) {
        if IsObject(searchConfig) && searchConfig.Has("CONTEXT_ENABLED") {
            AppContext.SetEnabled(!!searchConfig["CONTEXT_ENABLED"])
        }
    }

    static IsEnabled() {
        return AppContext.enabled
    }

    ; Current captured kind (browser, notepad, terminal, ...), or "" if none.
    static GetCurrentKind() {
        if !IsObject(AppContext.last)
            return ""
        if !AppContext.last.Has("kind")
            return ""
        return AppContext.last["kind"]
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
            AppContext.last := Map(
                "hwnd", hwnd,
                "exe", exeName,
                "title", title,
                "class", className,
                "kind", AppContext.GuessKind(exeName)
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
        currentText := AppContext.enabled ? "true" : "false"
        nextText := AppContext.enabled ? "false" : "true"
        prompt :=
            "CONTEXT_ENABLED: " currentText "`n`n"
            . "Set it to " nextText " for this session?`n"
            . "(Resets to config/searchActions.json when you relaunch " ConfigApp.APP_NAME ".)"

        options := "YesNo"
        if ownerHwnd
            options .= " Owner" ownerHwnd

        answer := MsgBox(prompt, ConfigApp.APP_NAME " — Context", options)
        if (answer = "Yes") {
            AppContext.SetEnabled(!AppContext.enabled)
            return Map(
                "ok", true,
                "title", ConfigApp.APP_NAME " — Context",
                "message", "CONTEXT_ENABLED is now " (AppContext.enabled ? "true" : "false")
                    . "`n`nThis lasts until you relaunch " ConfigApp.APP_NAME "."
            )
        }

        return Map(
            "ok", true,
            "title", ConfigApp.APP_NAME " — Context",
            "message", "CONTEXT_ENABLED left as " currentText
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

        text :=
            "App currently under " ConfigApp.APP_NAME ":`n`n"
            . kindLine
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
