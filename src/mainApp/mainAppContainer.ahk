; ===== Main App Container =====
; Owns the main application Gui window

#Requires AutoHotkey v2

#Include appHeaderContainer.ahk
#Include appContentContainer.ahk

class MainAppContainer {
    gui := ""
    header := ""
    content := ""

    __New() {
        this.CreateGui()
    }

    CreateGui() {
        options := "+Border"
        if (AppConfig.WINDOW.ALWAYS_ON_TOP)
            options .= " +AlwaysOnTop"
        if !AppConfig.WINDOW.SHOW_TITLE_BAR
            options .= " -Caption"
        this.gui := Gui(options, AppConfig.WINDOW.TITLE)
        this.gui.Name := "ReCtrlMainApp"
        this.gui.BackColor := AppConfig.WINDOW.BG_COLOR
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        this.gui.OnEvent("Escape", (*) => this.Hide())
        this.gui.OnEvent("Size", (g, minMax, w, h, *) => this.OnSize(w, h))

        headerHeight := AppConfig.AppHeaderHeight()
        if !AppConfig.WINDOW.SHOW_TITLE_BAR
            this.header := AppHeaderContainer(this.gui, ObjBindMethod(this, "Hide"))
        this.content := AppContentContainer(this.gui, headerHeight)
    }

    OnSize(clientW, clientH) {
        if this.header
            this.header.Reposition(clientW)
        this.content.Reposition(clientW, clientH)
    }

    Show() {
        w := AppConfig.WINDOW.WIDTH
        h := AppConfig.WINDOW.HEIGHT
        this.gui.Show("w" w " h" h " Center")
        this.gui.GetClientPos(, , &clientW, &clientH)
        this.OnSize(clientW, clientH)
        this.content.FocusSearchBox()
    }

    Hide() {
        this.gui.Hide()
    }

    IsVisible() {
        return this.gui.Hwnd && DllCall("IsWindowVisible", "Ptr", this.gui.Hwnd)
    }

    Toggle() {
        if this.IsVisible()
            this.Hide()
        else
            this.Show()
    }

    GetHwnd() {
        return this.gui.Hwnd
    }
}
