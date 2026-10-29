#Requires AutoHotkey v2

; App/window details API (any desktop app under ReCtrl).
; Collect + append window sections. Browser-only fields live in BrowserDetails.
class DesktopAppDetails {
    static GW_HWNDNEXT := 2
    static GW_OWNER := 4
    static WS_EX_TOOLWINDOW := 0x00000080
    static WS_EX_NOACTIVATE := 0x08000000

    ; Resolve window under ReCtrl and gather app/window fields.
    static Collect(ownerHwnd := 0) {
        info := Map("ok", false)
        targetHwnd := DesktopAppDetails.ResolveTargetHwnd(ownerHwnd)
        info["targetHwnd"] := targetHwnd
        info["ownerHwnd"] := ownerHwnd

        if !targetHwnd {
            info["error"] := "No app window found under " ConfigAppSettings.APP_NAME "."
            return info
        }
        if !DllCall("IsWindow", "Ptr", targetHwnd) {
            info["error"] := "Target window handle is no longer valid."
            info["windowValid"] := false
            return info
        }

        info["ok"] := true
        info["windowValid"] := true
        info["hwnd"] := targetHwnd

        try info["title"] := WinGetTitle(targetHwnd)
        catch
            info["title"] := ""

        try info["class"] := WinGetClass(targetHwnd)
        catch
            info["class"] := ""

        try info["exe"] := WinGetProcessName(targetHwnd)
        catch
            info["exe"] := ""

        try info["processPath"] := WinGetProcessPath(targetHwnd)
        catch
            info["processPath"] := ""

        try info["pid"] := WinGetPID(targetHwnd)
        catch
            info["pid"] := ""

        try {
            mm := WinGetMinMax(targetHwnd)
            info["minMax"] := mm
            info["minMaxLabel"] := DesktopAppDetails.MinMaxLabel(mm)
        } catch {
            info["minMax"] := ""
            info["minMaxLabel"] := ""
        }

        try info["style"] := Format("0x{:08X}", WinGetStyle(targetHwnd))
        catch
            info["style"] := ""

        try info["exStyle"] := Format("0x{:08X}", WinGetExStyle(targetHwnd))
        catch
            info["exStyle"] := ""

        try info["transparent"] := WinGetTransparent(targetHwnd)
        catch
            info["transparent"] := ""

        try info["isVisible"] := !!DllCall("IsWindowVisible", "Ptr", targetHwnd)
        catch
            info["isVisible"] := ""

        try info["isMinimized"] := !!DllCall("IsIconic", "Ptr", targetHwnd)
        catch
            info["isMinimized"] := ""

        try info["isZoomed"] := !!DllCall("IsZoomed", "Ptr", targetHwnd)
        catch
            info["isZoomed"] := ""

        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " targetHwnd)
            info["x"] := x
            info["y"] := y
            info["width"] := w
            info["height"] := h
        } catch {
            info["x"] := ""
            info["y"] := ""
            info["width"] := ""
            info["height"] := ""
        }

        try {
            WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " targetHwnd)
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

        try info["controlCount"] := WinGetControlsHwnd(targetHwnd).Length
        catch
            info["controlCount"] := ""

        try {
            focused := ControlGetFocus("ahk_id " targetHwnd)
            info["activeControl"] := focused ? focused : ""
        } catch {
            info["activeControl"] := ""
        }

        return info
    }

    static IsBrowserExe(exeName) {
        switch StrLower(Trim(exeName)) {
            case "chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe", "vivaldi.exe":
                return true
            default:
                return false
        }
    }

    ; Tip "App details": target / identity / state / geometry / controls (no URL).
    static AppendAppWindowSections(lines, details) {
        DesktopAppDetails.AppendTargetWindowSection(lines, details)
        DesktopAppDetails.AppendIdentitySection(lines, details)
        DesktopAppDetails.AppendWindowStateSection(lines, details)
        DesktopAppDetails.AppendGeometrySection(lines, details)
        DesktopAppDetails.AppendControlsSection(lines, details)
    }

    static AppendSectionHeader(lines, title) {
        lines.Push("")
        lines.Push("--- " title " ---")
    }

    static AppendTargetWindowSection(lines, details) {
        DesktopAppDetails.AppendSectionHeader(lines, "Target window")
        lines.Push("Title: " DesktopAppDetails.StrOr(details, "titleLive", DesktopAppDetails.StrOr(details, "title")))
        lines.Push("HWND: " DesktopAppDetails.StrOr(details, "hwnd"))
        lines.Push("Window PID: " DesktopAppDetails.StrOr(details, "pid"))
    }

    static AppendIdentitySection(lines, details) {
        DesktopAppDetails.AppendSectionHeader(lines, "Identity")
        lines.Push("Exe: " DesktopAppDetails.StrOr(details, "exeLive", DesktopAppDetails.StrOr(details, "exe")))
        lines.Push("Path: " DesktopAppDetails.StrOr(details, "processPath"))
        lines.Push("Class: " DesktopAppDetails.StrOr(details, "classLive", DesktopAppDetails.StrOr(details, "class")))
    }

    static AppendWindowStateSection(lines, details) {
        DesktopAppDetails.AppendSectionHeader(lines, "Window state")
        lines.Push("Valid: " DesktopAppDetails.BoolStr(details, "windowValid"))
        lines.Push("Visible: " DesktopAppDetails.BoolStr(details, "isVisible"))
        lines.Push("Minimized: " DesktopAppDetails.BoolStr(details, "isMinimized"))
        lines.Push("Maximized: " DesktopAppDetails.BoolStr(details, "isZoomed"))
        lines.Push("MinMax: " DesktopAppDetails.StrOr(details, "minMax") " (" DesktopAppDetails.StrOr(details, "minMaxLabel") ")")
        lines.Push("Transparent: " DesktopAppDetails.StrOr(details, "transparent", "(opaque/default)"))
        lines.Push("Style: " DesktopAppDetails.StrOr(details, "style"))
        lines.Push("ExStyle: " DesktopAppDetails.StrOr(details, "exStyle"))
    }

    static AppendGeometrySection(lines, details) {
        DesktopAppDetails.AppendSectionHeader(lines, "Geometry")
        lines.Push("Pos: " DesktopAppDetails.StrOr(details, "x") ", " DesktopAppDetails.StrOr(details, "y"))
        lines.Push("Size: " DesktopAppDetails.StrOr(details, "width") " x " DesktopAppDetails.StrOr(details, "height"))
        lines.Push("Client pos: " DesktopAppDetails.StrOr(details, "clientX") ", " DesktopAppDetails.StrOr(details, "clientY"))
        lines.Push("Client size: " DesktopAppDetails.StrOr(details, "clientWidth") " x " DesktopAppDetails.StrOr(details, "clientHeight"))
    }

    static AppendControlsSection(lines, details) {
        DesktopAppDetails.AppendSectionHeader(lines, "Controls")
        lines.Push("Control count: " DesktopAppDetails.StrOr(details, "controlCount"))
        lines.Push("Active control: " DesktopAppDetails.StrOr(details, "activeControl", "(none)"))
    }

    static ResolveTargetHwnd(ownerHwnd := 0) {
        activeHwnd := WinExist("A")
        if activeHwnd && (!ownerHwnd || activeHwnd != ownerHwnd) {
            if DesktopAppDetails.IsCandidateWindow(activeHwnd, ownerHwnd)
                return activeHwnd
        }

        if ownerHwnd {
            hwnd := DllCall("GetWindow", "Ptr", ownerHwnd, "UInt", DesktopAppDetails.GW_HWNDNEXT, "Ptr")
            while hwnd {
                if DesktopAppDetails.IsCandidateWindow(hwnd, ownerHwnd)
                    return hwnd
                hwnd := DllCall("GetWindow", "Ptr", hwnd, "UInt", DesktopAppDetails.GW_HWNDNEXT, "Ptr")
            }
        }
        return 0
    }

    static IsCandidateWindow(hwnd, excludeHwnd := 0) {
        if !hwnd
            return false
        if excludeHwnd && (hwnd = excludeHwnd)
            return false
        if !DllCall("IsWindow", "Ptr", hwnd)
            return false
        if !DllCall("IsWindowVisible", "Ptr", hwnd)
            return false
        if DllCall("IsIconic", "Ptr", hwnd)
            return false

        try {
            title := Trim(WinGetTitle(hwnd))
        } catch {
            return false
        }
        if (title = "")
            return false

        exStyle := 0
        try exStyle := WinGetExStyle(hwnd)
        if (exStyle & DesktopAppDetails.WS_EX_TOOLWINDOW)
            return false
        if (exStyle & DesktopAppDetails.WS_EX_NOACTIVATE)
            return false

        owner := DllCall("GetWindow", "Ptr", hwnd, "UInt", DesktopAppDetails.GW_OWNER, "Ptr")
        if owner
            return false

        return true
    }

    static MinMaxLabel(minMax) {
        switch Integer(minMax) {
            case -1:
                return "minimized"
            case 1:
                return "maximized"
            case 0:
                return "normal"
            default:
                return String(minMax)
        }
    }

    static StrOr(details, key, fallback := "") {
        if !IsObject(details) || !details.Has(key) || details[key] = ""
            return fallback != "" ? fallback : "(n/a)"
        return String(details[key])
    }

    static BoolStr(details, key) {
        if !IsObject(details) || !details.Has(key) || details[key] = ""
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
}
