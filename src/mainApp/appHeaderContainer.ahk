; ===== App Header Container =====
; Header section controls on the main app Gui

#Requires AutoHotkey v2

#Include ..\shared\dragWin.ahk

class AppHeaderContainer {
    gui := ""
    onClose := ""
    headerBg := ""
    icon := ""
    titleText := ""
    closeBtn := ""
    iconCfg := ""
    titleCfg := ""
    closeCfg := ""

    __New(parentGui, onClose) {
        this.gui := parentGui
        this.onClose := onClose
        this.Build()
    }

    Build() {
        cfg := ConfigAppSettings.HEADER
        this.iconCfg := cfg.ICON
        this.titleCfg := cfg.TITLE
        this.closeCfg := cfg.CLOSE_BTN
        w := ConfigAppSettings.WINDOW.WIDTH
        padX := cfg.PADDING_X
        padY := cfg.PADDING_Y
        innerH := Max(0, cfg.HEIGHT - 2 * padY)
        contentX := padX
        closeW := this.closeCfg.SHOW ? this.closeCfg.WIDTH : 0
        closeX := w - closeW - padX

        this.headerBg := this.gui.Add("Text",
            "x" padX " y" padY " w" (w - 2 * padX) " h" innerH " Background" cfg.BG_COLOR, "")

        if this.iconCfg.SHOW {
            iconPath := ConfigAppSettings.ResolveAssetPath(this.iconCfg.PATH)
            if FileExist(iconPath) {
                iconY := padY + (innerH - this.iconCfg.HEIGHT) // 2
                this.icon := this.gui.Add("Picture",
                    "x" padX " y" iconY " w" this.iconCfg.WIDTH " h" this.iconCfg.HEIGHT,
                    iconPath)
                contentX := padX + this.iconCfg.WIDTH + this.iconCfg.GAP
            }
        }

        if this.titleCfg.SHOW {
            maxTitleW := closeX - contentX
            if (maxTitleW < 0)
                maxTitleW := 0

            titleOpts := "x" contentX " y" padY " w" maxTitleW " BackgroundTrans"
            if Trim(String(this.titleCfg.COLOR)) != ""
                titleOpts .= " c" this.titleCfg.COLOR

            this.titleText := this.gui.Add("Text", titleOpts, ConfigAppSettings.HeaderTitleText())
            this.titleText.SetFont(this.titleCfg.FONT, this.titleCfg.FONT_NAME)
            this.ApplyTitleLayout(contentX, maxTitleW, padY, innerH)
        }

        if this.closeCfg.SHOW {
            btnY := padY + (innerH - this.closeCfg.HEIGHT) // 2
            this.closeBtn := this.gui.Add("Text",
                "x" closeX " y" btnY " w" this.closeCfg.WIDTH " h" this.closeCfg.HEIGHT
                    . " Border Center 0x200 Background" this.closeCfg.COLOR,
                this.closeCfg.TEXT)
            this.closeBtn.SetFont(this.closeCfg.FONT_SIZE)
            this.closeBtn.OnEvent("Click", (*) => this.onClose.Call())
        }

        dragArgs := [this.gui, this.headerBg]
        if this.closeBtn
            dragArgs.Push(this.closeBtn)
        if this.icon
            dragArgs.Push(this.icon)
        DragWin.Enable(dragArgs*)
    }

    ApplyTitleLayout(x, w, padY, innerH) {
        if !this.titleText
            return
        lineH := this.GetFontLineHeight(this.titleText.Hwnd)
        if (lineH <= 0 || lineH > innerH)
            lineH := innerH
        y := padY + (innerH - lineH) // 2
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
        return ConfigAppSettings.HEADER.HEIGHT
    }

    SetVisible(show) {
        show := !!show
        if this.headerBg
            this.headerBg.Visible := show
        if this.icon
            this.icon.Visible := show
        if this.titleText
            this.titleText.Visible := show
        if this.closeBtn
            this.closeBtn.Visible := show
    }

    Reposition(clientW) {
        cfg := ConfigAppSettings.HEADER
        padX := cfg.PADDING_X
        padY := cfg.PADDING_Y
        innerH := Max(0, cfg.HEIGHT - 2 * padY)
        contentX := padX
        closeW := this.closeCfg.SHOW && this.closeBtn ? this.closeCfg.WIDTH : 0
        closeX := clientW - closeW - padX

        this.headerBg.Move(padX, padY, clientW - 2 * padX, innerH)

        if this.icon {
            iconY := padY + (innerH - this.iconCfg.HEIGHT) // 2
            this.icon.Move(padX, iconY)
            contentX := padX + this.iconCfg.WIDTH + this.iconCfg.GAP
        }

        if this.titleText {
            maxTitleW := closeX - contentX
            if (maxTitleW < 0)
                maxTitleW := 0
            this.ApplyTitleLayout(contentX, maxTitleW, padY, innerH)
        }

        if this.closeBtn {
            btnY := padY + (innerH - this.closeCfg.HEIGHT) // 2
            this.closeBtn.Move(closeX, btnY)
        }
    }
}
