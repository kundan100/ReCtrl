#Requires AutoHotkey v2

; Desktop-app window discovery / activation by appIdentifier + optional filters.
; JSON fields (same shape as browserActions):
;   appIdentifier       — app family (e.g. "Cursor", "Microsoft Teams")
;   multiWinIdentifier  — variant / instance hint (e.g. "ide", "agent")
;   fileTitle           — optional extra WinTitle substring
class DesktopAppWindows {
    ; Returns HWNDs matching app + variant + optional title filter.
    static ListByApp(appIdentifier, multiWinIdentifier := "", fileTitle := "") {
        out := []
        exeFilter := DesktopAppWindows.ExeFilterForApp(appIdentifier)
        if (exeFilter = "")
            return out

        for hwnd in WinGetList("ahk_exe " exeFilter) {
            if !DllCall("IsWindow", "Ptr", hwnd)
                continue
            try {
                title := WinGetTitle(hwnd)
            } catch {
                continue
            }
            if (Trim(title) = "")
                continue
            if !DesktopAppWindows.MatchesVariant(appIdentifier, multiWinIdentifier, title)
                continue
            if (Trim(fileTitle) != "" && !InStr(title, Trim(fileTitle), false))
                continue
            out.Push(hwnd)
        }
        return out
    }

    ; Focus first matching window. Returns true if activated.
    static Focus(appIdentifier, multiWinIdentifier := "", fileTitle := "") {
        for hwnd in DesktopAppWindows.ListByApp(appIdentifier, multiWinIdentifier, fileTitle) {
            DesktopAppWindows.Activate(hwnd)
            return true
        }
        return false
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

    ; Known app → process name (extend as Teams / Outlook / etc. are added).
    static ExeFilterForApp(appIdentifier) {
        switch Trim(appIdentifier) {
            case "Cursor":
                return "Cursor.exe"
            case "Microsoft Teams", "Teams":
                return "ms-teams.exe"
            case "Outlook", "Microsoft Outlook":
                return "OUTLOOK.EXE"
            default:
                ; Allow raw exe name in JSON: "appIdentifier": "notepad.exe"
                name := Trim(appIdentifier)
                if (name != "" && RegExMatch(name, "i)\.exe$"))
                    return name
                return ""
        }
    }

    ; Variant rules for same exe / many windows. Unknown variant = title contains that string.
    static MatchesVariant(appIdentifier, multiWinIdentifier, title) {
        variant := StrLower(Trim(multiWinIdentifier))
        if (variant = "")
            return true

        app := Trim(appIdentifier)
        if (app = "Cursor") {
            hasAgent := InStr(title, "Agent", false)
            switch variant {
                case "ide", "editor", "main":
                    return !hasAgent
                case "agent":
                    return !!hasAgent
            }
        }

        ; Generic: multiWinIdentifier is a title substring (like a soft fileTitle).
        return InStr(title, Trim(multiWinIdentifier), false)
    }
}
