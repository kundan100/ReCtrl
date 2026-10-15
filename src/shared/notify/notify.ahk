#Requires AutoHotkey v2

; Lightweight top-right toast notifications (Teams-like).
; Public API:
;   Notify.Show(title, message, durationMs := unset)
;   Notify.Feedback(title, message, ownerHwnd := 0)  ; respects NotifyConfig.RESULT_FEEDBACK
class Notify {
    static gui := ""
    static hideTimer := ""
    static titleCtrl := ""
    static bodyCtrl := ""
    static closeCtrl := ""

    ; Route message via NotifyConfig.RESULT_FEEDBACK (toast vs MsgBox).
    ; ownerHwnd is used only for the popup path (owned dialog).
    static Feedback(title, message, ownerHwnd := 0) {
        title := Trim(String(title))
        if (title = "")
            title := ConfigApp.APP_NAME
        mode := ""
        try mode := StrLower(Trim(String(NotifyConfig.RESULT_FEEDBACK)))
        if (mode = "show-in-notification") {
            Notify.Show(title, message)
            return
        }
        if ownerHwnd
            MsgBox(message, title, "Owner" ownerHwnd)
        else
            MsgBox(message, title)
    }

    ; Show a toast at the top-right of the primary work area.
    ; Does not activate/steal focus. Replaces any currently visible toast.
    static Show(title, message, durationMs := unset) {
        if !IsSet(durationMs)
            durationMs := NotifyConfig.TOAST_DURATION_MS
        if (durationMs < 0)
            durationMs := 0

        title := Trim(String(title))
        message := Trim(String(message))
        if (title = "" && message = "")
            return

        Notify.Dismiss()
        Notify.CreateGui(title, message)
        Notify.PositionTopRight()
        Notify.gui.Show("NoActivate Hide")
        Notify.gui.Show("NoActivate")

        if (durationMs > 0) {
            Notify.hideTimer := ObjBindMethod(Notify, "Dismiss")
            SetTimer(Notify.hideTimer, -durationMs)
        }
    }

    static Dismiss(*) {
        if Notify.hideTimer {
            try SetTimer(Notify.hideTimer, 0)
            Notify.hideTimer := ""
        }
        if Notify.gui {
            try Notify.gui.Destroy()
            Notify.gui := ""
            Notify.titleCtrl := ""
            Notify.bodyCtrl := ""
            Notify.closeCtrl := ""
        }
    }

    static CreateGui(title, message) {
        cfg := NotifyConfig.TOAST
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", ConfigApp.APP_NAME " — Notice")
        g.BackColor := cfg.BG_COLOR
        g.MarginX := cfg.PADDING
        g.MarginY := cfg.PADDING
        g.OnEvent("Close", (*) => Notify.Dismiss())

        closeW := 22
        contentW := cfg.WIDTH - (cfg.PADDING * 2) - closeW - 4

        g.SetFont(cfg.TITLE_FONT, "Segoe UI")
        Notify.titleCtrl := g.AddText(
            "x" cfg.PADDING " y" cfg.PADDING " w" contentW " c" cfg.TITLE_COLOR,
            title != "" ? title : ConfigApp.APP_NAME
        )

        g.SetFont(cfg.CLOSE_FONT, "Segoe UI")
        Notify.closeCtrl := g.AddText(
            "x" (cfg.WIDTH - cfg.PADDING - closeW) " y" cfg.PADDING " w" closeW " h" closeW
            . " Center c" cfg.CLOSE_COLOR,
            "✕"
        )
        Notify.closeCtrl.OnEvent("Click", (*) => Notify.Dismiss())

        bodyY := cfg.PADDING + 22
        g.SetFont(cfg.BODY_FONT, "Segoe UI")
        Notify.bodyCtrl := g.AddText(
            "x" cfg.PADDING " y" bodyY " w" (cfg.WIDTH - cfg.PADDING * 2) " c" cfg.BODY_COLOR,
            message
        )

        ; Size height to content (with a minimum).
        Notify.bodyCtrl.GetPos(, , , &bodyH)
        totalH := bodyY + bodyH + cfg.PADDING
        if (totalH < cfg.MIN_HEIGHT)
            totalH := cfg.MIN_HEIGHT

        g.Show("Hide w" cfg.WIDTH " h" totalH)
        Notify.gui := g
    }

    static PositionTopRight() {
        if !Notify.gui
            return
        cfg := NotifyConfig.TOAST
        Notify.gui.GetPos(, , &w, &h)
        MonitorGetWorkArea(MonitorGetPrimary(), &waLeft, &waTop, &waRight, &waBottom)
        x := waRight - w - cfg.MARGIN
        y := waTop + cfg.MARGIN
        Notify.gui.Show("NoActivate x" x " y" y " w" w " h" h)
    }
}
