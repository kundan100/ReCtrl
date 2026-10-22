#Requires AutoHotkey v2

; Background/text colors for Edit controls.
; Opt "Background" does not work on Edit. Themed Edits also ignore WM_CTLCOLOREDIT
; unless SetWindowTheme is cleared for that hwnd.
class EditControlColors {
    static entries := Map()
    static hooked := false

    ; bgRgb / fgRgb: 0xRRGGBB or "RRGGBB" / "0xRRGGBB"
    static Apply(editHwnd, bgRgb, fgRgb := 0x000000) {
        editHwnd := Integer(editHwnd)
        if !editHwnd
            return

        if !EditControlColors.hooked {
            ; Fat-arrow keeps a reliable return of the brush HBRUSH to DefWindowProc.
            OnMessage(0x133, (wParam, lParam, msg, hwnd)
                => EditControlColors.OnCtlColorEdit(wParam, lParam, msg, hwnd))
            EditControlColors.hooked := true
        }

        ; Required on Win10/11 — visual styles otherwise paint the system Edit chrome.
        try DllCall("uxtheme\SetWindowTheme", "Ptr", editHwnd, "WStr", "", "WStr", "")

        bgBgr := EditControlColors.RgbToBgr(bgRgb)
        fgBgr := EditControlColors.RgbToBgr(fgRgb)

        if EditControlColors.entries.Has(editHwnd) {
            try DllCall("DeleteObject", "Ptr", EditControlColors.entries[editHwnd].brush)
        }

        brush := DllCall("CreateSolidBrush", "UInt", bgBgr, "Ptr")
        if !brush
            return

        EditControlColors.entries[editHwnd] := { bg: bgBgr, fg: fgBgr, brush: brush }

        ; Force a full repaint after theme + brush change.
        try DllCall("RedrawWindow", "Ptr", editHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0579)
    }

    static Clear(editHwnd) {
        editHwnd := Integer(editHwnd)
        if !editHwnd || !EditControlColors.entries.Has(editHwnd)
            return
        try DllCall("DeleteObject", "Ptr", EditControlColors.entries[editHwnd].brush)
        EditControlColors.entries.Delete(editHwnd)
        try DllCall("InvalidateRect", "Ptr", editHwnd, "Ptr", 0, "Int", 1)
    }

    static OnCtlColorEdit(wParam, lParam, *) {
        editHwnd := Integer(lParam)
        if !EditControlColors.entries.Has(editHwnd)
            return 0
        entry := EditControlColors.entries[editHwnd]
        DllCall("SetBkColor", "Ptr", wParam, "UInt", entry.bg)
        DllCall("SetTextColor", "Ptr", wParam, "UInt", entry.fg)
        DllCall("SetBkMode", "Ptr", wParam, "Int", 2) ; OPAQUE
        return entry.brush
    }

    static ParseRgb(color) {
        hex := StrUpper(Trim(String(color)))
        hex := RegExReplace(hex, "^0X", "")
        hex := RegExReplace(hex, "^#", "")
        if !RegExMatch(hex, "^[0-9A-F]{6}$")
            return 0xFFFFFF
        return Integer("0x" hex)
    }

    ; GDI brushes use COLORREF = 0x00BBGGRR
    static RgbToBgr(rgb) {
        rgb := Integer(rgb) & 0xFFFFFF
        return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
    }
}
