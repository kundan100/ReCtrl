#Requires AutoHotkey v2

; Browser window discovery / activation by browser name + primary label.
class BrowserWindows {
    ; Returns HWNDs for open windows matching browserName (+ optional primaryLabel).
    static ListByBrowserAndLabel(browserName, primaryLabel := "") {
        out := []
        exeFilter := BrowserWindows.ExeFilterForBrowserName(browserName)
        if (exeFilter = "")
            return out

        for hwnd in WinGetList("ahk_exe " exeFilter) {
            if !DllCall("IsWindow", "Ptr", hwnd)
                continue
            try {
                exeName := WinGetProcessName(hwnd)
                processPath := WinGetProcessPath(hwnd)
                pid := WinGetPID(hwnd)
            } catch {
                continue
            }
            if (BrowserProfile.GuessBrowserName(exeName, processPath) != browserName)
                continue
            if !BrowserWindows.WindowMatchesPrimaryLabel(hwnd, pid, exeName, processPath, primaryLabel)
                continue
            out.Push(hwnd)
        }
        return out
    }

    static WindowMatchesPrimaryLabel(hwnd, pid, exeName, processPath, primaryLabel) {
        wanted := Trim(primaryLabel)
        if (wanted = "")
            return true

        profile := BrowserProfile.CollectBrowserProfile(pid, exeName, processPath, hwnd)
        return BrowserProfile.LabelMatches(wanted
            , profile["profileDisplayName"]
            , profile["profileAccount"]
            , profile["profileName"])
    }

    static Activate(hwnd) {
        try {
            if (WinGetMinMax(hwnd) = -1)
                WinRestore(hwnd)
        } catch {
            ; ignore
        }
        WinActivate("ahk_id " hwnd)
        try WinWaitActive("ahk_id " hwnd, , 2)
    }

    static ExeFilterForBrowserName(browserName) {
        switch browserName {
            case "Google Chrome", "Google Chrome Canary", "Google Chrome Beta", "Google Chrome Dev":
                return "chrome.exe"
            case "Microsoft Edge", "Microsoft Edge Canary", "Microsoft Edge Beta", "Microsoft Edge Dev":
                return "msedge.exe"
            case "Brave":
                return "brave.exe"
            case "Opera":
                return "opera.exe"
            case "Vivaldi":
                return "vivaldi.exe"
            case "Mozilla Firefox":
                return "firefox.exe"
            default:
                return ""
        }
    }
}
