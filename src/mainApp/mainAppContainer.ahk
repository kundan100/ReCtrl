; ===== Main App Container =====
; Owns the main application Gui window

#Requires AutoHotkey v2

#Include appHeaderContainer.ahk
#Include appContentContainer.ahk

class MainAppContainer {
    gui := ""
    header := ""
    content := ""
    transparencyTimer := ""

    __New() {
        this.CreateGui()
        this.SetupTransparencyController()
    }

    CreateGui() {
        options := "+Border"
        if (AppConfig.WINDOW.ALWAYS_ON_TOP)
            options .= " +AlwaysOnTop"
        if !AppConfig.WINDOW.SHOW_TITLE_BAR
            options .= " -Caption"
        this.gui := Gui(options, AppConfig.WINDOW.TITLE)
        this.gui.Opt("+OwnDialogs")
        this.gui.Name := "ReCtrlMainApp"
        this.gui.BackColor := AppConfig.WINDOW.BG_COLOR
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        this.gui.OnEvent("Escape", (*) => this.OnEscapePressed())
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
        this.ApplyTransparencyForCurrentFocus()
    }

    Hide() {
        this.content.HideTransientUi()
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

    Summon() {
        if !this.IsVisible() {
            this.Show()
            return
        }

        hwnd := this.GetHwnd()
        if hwnd {
            ; If visible but not focused, bring to foreground.
            if !WinActive("ahk_id " hwnd) {
                WinActivate("ahk_id " hwnd)
            }
            this.content.FocusSearchBox()
        }
    }

    GetHwnd() {
        return this.gui.Hwnd
    }

    SetupTransparencyController() {
        if !AppConfig.TRANSPARENCY.ENABLED
            return

        if (AppConfig.TRANSPARENCY.CHECK_INTERVAL_MS < 50)
            AppConfig.TRANSPARENCY.CHECK_INTERVAL_MS := 50

        this.transparencyTimer := ObjBindMethod(this, "ApplyTransparencyForCurrentFocus")
        SetTimer(this.transparencyTimer, AppConfig.TRANSPARENCY.CHECK_INTERVAL_MS)
    }

    ApplyTransparencyForCurrentFocus(*) {
        if !AppConfig.TRANSPARENCY.ENABLED
            return

        if !this.IsVisible()
            return

        activeAlpha := this.ClampAlpha(AppConfig.TRANSPARENCY.ACTIVE_ALPHA)
        inactiveAlpha := this.ClampAlpha(AppConfig.TRANSPARENCY.INACTIVE_ALPHA)
        hwnd := this.GetHwnd()
        if !hwnd
            return
        targetAlpha := WinActive("ahk_id " hwnd) ? activeAlpha : inactiveAlpha

        ; Main app window
        this.ApplyTransparencyToWindow(hwnd, targetAlpha)
    }

    ClampAlpha(alpha) {
        if (alpha < 0)
            return 0
        if (alpha > 255)
            return 255
        return alpha
    }

    ApplyTransparencyToWindow(hwnd, alpha) {
        if !hwnd
            return
        if !DllCall("IsWindowVisible", "Ptr", hwnd)
            return
        try WinSetTransparent(alpha, "ahk_id " hwnd)
    }

    OnEscapePressed() {
        ; ESC behavior:
        ; 1) if suggestions are visible -> dismiss suggestions only
        ; 2) otherwise -> hide app window
        if this.content.DismissSuggestionsIfVisible() {
            this.content.FocusSearchBox()
            return
        }
        this.Hide()
    }
}
