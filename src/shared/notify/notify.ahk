#Requires AutoHotkey v2

; Lightweight top-right toast notifications (Teams-like).
; Public API:
;   Notify.Show(title, message, type := "info", durationMs := unset)
;   Notify.Feedback(title, message, ownerHwnd := 0, type := "info")  ; respects FUNCTIONAL.NOTIFY.RESULT_FEEDBACK
; type: "info" | "error" | "success"
class Notify {
    static gui := ""
    static hideTimer := ""
    static titleCtrl := ""
    static bodyCtrl := ""
    static closeCtrl := ""
    static accentCtrl := ""

    ; Route message via ConfigAppSettings.FUNCTIONAL.NOTIFY.RESULT_FEEDBACK (toast vs MsgBox).
    ; ownerHwnd is used only for the popup path (owned dialog).
    static Feedback(title, message, ownerHwnd := 0, type := "info") {
        title := Trim(String(title))
        if (title = "")
            title := ConfigAppSettings.APP_NAME
        type := Notify.NormalizeType(type)
        mode := ""
        try mode := StrLower(Trim(String(ConfigAppSettings.FUNCTIONAL.NOTIFY.RESULT_FEEDBACK)))
        if (mode = "show-in-notification") {
            Notify.Show(title, message, type)
            return
        }
        iconOpt := Notify.MsgBoxIconOpt(type)
        if ownerHwnd
            MsgBox(message, title, iconOpt " Owner" ownerHwnd)
        else
            MsgBox(message, title, iconOpt)
    }

    ; Show a toast at the top-right of the primary work area.
    ; Does not activate/steal focus. Replaces any currently visible toast.
    static Show(title, message, type := "info", durationMs := unset) {
        if !IsSet(durationMs)
            durationMs := ConfigAppSettings.FUNCTIONAL.NOTIFY.TOAST_DURATION_MS
        if (durationMs < 0)
            durationMs := 0

        title := Trim(String(title))
        message := Trim(String(message))
        type := Notify.NormalizeType(type)
        if (title = "" && message = "")
            return

        Notify.Dismiss()
        Notify.CreateGui(title, message, type)
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
            Notify.accentCtrl := ""
        }
    }

    static CreateGui(title, message, type := "info") {
        cfg := ConfigAppSettings.FUNCTIONAL.NOTIFY.TOAST
        colors := Notify.TypeColors(type)
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", ConfigAppSettings.APP_NAME " — Notice")
        g.BackColor := cfg.BG_COLOR
        g.MarginX := cfg.PADDING
        g.MarginY := cfg.PADDING
        g.OnEvent("Close", (*) => Notify.Dismiss())

        accentW := 4
        closeW := 22
        contentX := cfg.PADDING + accentW + 6
        contentW := cfg.WIDTH - contentX - cfg.PADDING - closeW - 4

        ; Left accent strip encodes type (info / error / success).
        Notify.accentCtrl := g.AddProgress(
            "x0 y0 w" accentW " h" cfg.MIN_HEIGHT " -Smooth Background" colors.ACCENT
            . " c" colors.ACCENT,
            100
        )

        g.SetFont(cfg.TITLE_FONT, "Segoe UI")
        Notify.titleCtrl := g.AddText(
            "x" contentX " y" cfg.PADDING " w" contentW " c" colors.TITLE,
            title != "" ? title : ConfigAppSettings.APP_NAME
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
            "x" contentX " y" bodyY " w" (cfg.WIDTH - contentX - cfg.PADDING) " c" cfg.BODY_COLOR,
            message
        )

        ; Size height to content (with a minimum).
        Notify.bodyCtrl.GetPos(, , , &bodyH)
        totalH := bodyY + bodyH + cfg.PADDING
        if (totalH < cfg.MIN_HEIGHT)
            totalH := cfg.MIN_HEIGHT

        ; Stretch accent to final toast height.
        Notify.accentCtrl.Move(0, 0, accentW, totalH)

        g.Show("Hide w" cfg.WIDTH " h" totalH)
        Notify.gui := g
    }

    static PositionTopRight() {
        if !Notify.gui
            return
        cfg := ConfigAppSettings.FUNCTIONAL.NOTIFY.TOAST
        Notify.gui.GetPos(, , &w, &h)
        MonitorGetWorkArea(MonitorGetPrimary(), &waLeft, &waTop, &waRight, &waBottom)
        x := waRight - w - cfg.MARGIN
        y := waTop + cfg.MARGIN
        Notify.gui.Show("NoActivate x" x " y" y " w" w " h" h)
    }

    static NormalizeType(type) {
        t := StrLower(Trim(String(type)))
        if (t = "error" || t = "success" || t = "info")
            return t
        return "info"
    }

    static TypeColors(type) {
        switch Notify.NormalizeType(type) {
            case "error":
                ; Brighter reds read better on grey toast BG than deep 0xE81123.
                return { ACCENT: "0xFF5252", TITLE: "0xFF8A80" }
            case "success":
                return { ACCENT: "0xB4FFB4", TITLE: "0xB4FFB4" }
            default:
                return { ACCENT: "0x0078D4", TITLE: "0xFFFFFF" }
        }
    }

    static MsgBoxIconOpt(type) {
        switch Notify.NormalizeType(type) {
            case "error":
                return "Iconx"
            case "success":
                return "Iconi"
            default:
                return "Iconi"
        }
    }
}
