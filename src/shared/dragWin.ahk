; ===== Drag Window =====
; WM_NCHITTEST-based dragging for borderless Gui windows

#Requires AutoHotkey v2

DragWin_OnNcHitTest(wParam, lParam, msg, msgHwnd) {
    ; WM_NCHITTEST is evaluated for the top-level window.
    ; Use msgHwnd directly so child-control messages don't break lookup.
    entry := DragWin.GetByHwnd(msgHwnd)
    if !entry
        return

    sx := lParam & 0xFFFF
    sy := (lParam >> 16) & 0xFFFF
    if (sx > 0x7FFF)
        sx -= 0x10000
    if (sy > 0x7FFF)
        sy -= 0x10000

    DragWin.ScreenToClient(msgHwnd, sx, sy, &cx, &cy)
    if !DragWin.PointInRect(entry.drag, cx, cy)
        return
    if DragWin.PointInAny(entry.exclude, cx, cy)
        return

    ; HTCAPTION makes Windows drag on mouse-down.
    return 2
}

class DragWin {
    static _entries := Map()

    static Enable(gui, dragRegion, excludeControls*) {
        excludes := []
        for ctrl in excludeControls {
            if ctrl
                excludes.Push(ctrl)
        }
        DragWin._entries[gui.Hwnd] := { gui: gui, drag: dragRegion, exclude: excludes }
        if (DragWin._entries.Count = 1)
            OnMessage(0x84, DragWin_OnNcHitTest) ; WM_NCHITTEST
    }

    static Disable(gui) {
        if DragWin._entries.Has(gui.Hwnd)
            DragWin._entries.Delete(gui.Hwnd)
        if (DragWin._entries.Count = 0)
            OnMessage(0x84, DragWin_OnNcHitTest, 0)
    }

    static GetByHwnd(hwnd) {
        return DragWin._entries.Has(hwnd) ? DragWin._entries[hwnd] : ""
    }

    static ScreenToClient(hwnd, sx, sy, &cx, &cy) {
        pt := Buffer(8, 0)
        NumPut("Int", sx, pt, 0)
        NumPut("Int", sy, pt, 4)
        DllCall("ScreenToClient", "Ptr", hwnd, "Ptr", pt)
        cx := NumGet(pt, 0, "Int")
        cy := NumGet(pt, 4, "Int")
    }

    static PointInRect(ctrl, cx, cy) {
        ctrl.GetPos(&x, &y, &w, &h)
        return cx >= x && cy >= y && cx < x + w && cy < y + h
    }

    static PointInAny(controls, cx, cy) {
        for ctrl in controls {
            if DragWin.PointInRect(ctrl, cx, cy)
                return true
        }
        return false
    }
}
