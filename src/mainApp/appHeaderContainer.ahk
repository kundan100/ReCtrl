; ===== App Header Container =====
; Header section controls on the main app Gui

#Requires AutoHotkey v2

#Include ..\shared\dragWin.ahk

class AppHeaderContainer {
    static _ICON_SIZE := 16
    static _ICON_GAP := 6

    gui := ""
    onClose := ""
    headerBg := ""
    icon := ""
    titleText := ""
    closeBtn := ""

    __New(parentGui, onClose) {
        this.gui := parentGui
        this.onClose := onClose
        this.Build()
    }

    Build() {
        cfg := AppConfig.HEADER
        btnCfg := cfg.CLOSE_BTN
        w := AppConfig.WINDOW.WIDTH
        pad := cfg.PADDING_X
        btnY := (cfg.HEIGHT - btnCfg.HEIGHT) // 2
        contentX := pad
        closeX := w - btnCfg.WIDTH - pad

        this.headerBg := this.gui.Add("Text", "x" pad " y0 w" (w - 2 * pad) " h" cfg.HEIGHT " Background" cfg.BG_COLOR, "")

        iconPath := A_ScriptDir "\assets\appIcon\favicon_io\favicon.ico"
        if FileExist(iconPath) {
            iconY := (cfg.HEIGHT - AppHeaderContainer._ICON_SIZE) // 2
            this.icon := this.gui.Add("Picture",
                "x" pad " y" iconY " w" AppHeaderContainer._ICON_SIZE " h" AppHeaderContainer._ICON_SIZE,
                iconPath)
            contentX := pad + AppHeaderContainer._ICON_SIZE + AppHeaderContainer._ICON_GAP
        }

        maxTitleW := closeX - contentX
        if (maxTitleW < 0)
            maxTitleW := 0

        this.titleText := this.gui.Add("Text",
            "x" contentX " y0 w" maxTitleW " BackgroundTrans",
            AppConfig.WINDOW.TITLE)
        this.titleText.SetFont("s10", "Segoe UI")
        this.ApplyTitleLayout(contentX, maxTitleW, cfg.HEIGHT)

        this.closeBtn := this.gui.Add("Text",
            "x" closeX " y" btnY " w" btnCfg.WIDTH " h" btnCfg.HEIGHT " Border Center 0x200 Background" btnCfg.COLOR,
            btnCfg.TEXT)
        this.closeBtn.SetFont(btnCfg.FONT_SIZE)
        this.closeBtn.OnEvent("Click", (*) => this.onClose.Call())

        if this.icon
            DragWin.Enable(this.gui, this.headerBg, this.titleText, this.closeBtn, this.icon)
        else
            DragWin.Enable(this.gui, this.headerBg, this.titleText, this.closeBtn)
    }

    ApplyTitleLayout(x, w, headerHeight) {
        lineH := this.GetFontLineHeight(this.titleText.Hwnd)
        if (lineH <= 0 || lineH > headerHeight)
            lineH := headerHeight
        y := (headerHeight - lineH) // 2
        this.titleText.Move(x, y, w, lineH)
    }

    GetFontLineHeight(hwnd) {
        hFont := SendMessage(0x0031, 0, 0, hwnd)
        if !hFont
            return 0
        hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
        hOldFont := DllCall("SelectObject", "Ptr", hDC, "Ptr", hFont, "Ptr")
        metric := Buffer(64, 0)
        DllCall("GetTextMetrics", "Ptr", hDC, "Ptr", metric)
        DllCall("SelectObject", "Ptr", hDC, "Ptr", hOldFont)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
        return NumGet(metric, 0, "Int")
    }

    GetHeight() {
        return AppConfig.HEADER.HEIGHT
    }

    Reposition(clientW) {
        cfg := AppConfig.HEADER
        btnCfg := cfg.CLOSE_BTN
        pad := cfg.PADDING_X
        btnY := (cfg.HEIGHT - btnCfg.HEIGHT) // 2
        contentX := pad
        closeX := clientW - btnCfg.WIDTH - pad

        this.headerBg.Move(pad, , clientW - 2 * pad)

        if this.icon {
            iconY := (cfg.HEIGHT - AppHeaderContainer._ICON_SIZE) // 2
            this.icon.Move(pad, iconY)
            contentX := pad + AppHeaderContainer._ICON_SIZE + AppHeaderContainer._ICON_GAP
        }

        maxTitleW := closeX - contentX
        if (maxTitleW < 0)
            maxTitleW := 0
        this.ApplyTitleLayout(contentX, maxTitleW, cfg.HEIGHT)

        this.closeBtn.Move(closeX, btnY)
    }
}
