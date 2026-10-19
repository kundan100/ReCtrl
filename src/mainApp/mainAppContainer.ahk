; ===== Main App Container =====
; Owns the main application Gui window

#Requires AutoHotkey v2

#Include ..\shared\windowDropShadow.ahk
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
        if (ConfigAppSettings.WINDOW.ALWAYS_ON_TOP)
            options .= " +AlwaysOnTop"
        if !ConfigAppSettings.WINDOW.USE_NATIVE_TITLE_BAR
            options .= " -Caption"
        this.gui := Gui(options, ConfigAppSettings.WINDOW.TITLE)
        this.gui.Opt("+OwnDialogs")
        this.gui.Name := "ReCtrlMainApp"
        this.gui.BackColor := ConfigAppSettings.WINDOW.BG_COLOR
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        this.gui.OnEvent("Escape", (*) => this.OnEscapePressed())
        this.gui.OnEvent("Size", (g, minMax, w, h, *) => this.OnSize(w, h))

        headerHeight := ConfigAppSettings.AppHeaderHeight()
        if ConfigAppSettings.ShouldShowCustomHeader()
            this.header := AppHeaderContainer(this.gui, ObjBindMethod(this, "Hide"))
        this.content := AppContentContainer(this.gui, headerHeight)
    }

    OnSize(clientW, clientH) {
        if this.header
            this.header.Reposition(clientW)
        this.content.Reposition(clientW, clientH)
    }

    Show() {
        ; Capture the app underneath before this window takes focus.
        this.CaptureUnderlyingContext()
        w := ConfigAppSettings.WINDOW.WIDTH
        h := ConfigAppSettings.AppHeaderHeight() + AppContentContainer.PreferredContentHeight()
        this.gui.Show("w" w " h" h " Center")
        WindowDropShadow.Apply(this.GetHwnd())
        this.gui.GetClientPos(, , &clientW, &clientH)
        this.OnSize(clientW, clientH)
        this.content.FocusSearchBox()
        this.ApplyTransparencyForCurrentFocus()
    }

    Hide() {
        this.content.HideTransientUi()
        WindowDropShadow.Hide()
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
        ; Always try to remember the focused app before ReCtrl steals focus.
        this.CaptureUnderlyingContext()

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

    CaptureUnderlyingContext() {
        ; Prefer live window under ReCtrl (skips minimized / closed apps).
        AppContext.RefreshUnderlying(this.GetHwnd())
    }

    GetHwnd() {
        return this.gui.Hwnd
    }

    SetupTransparencyController() {
        cfg := ConfigAppSettings.WINDOW.TRANSPARENCY
        if !cfg.ENABLED
            return

        if (cfg.CHECK_INTERVAL_MS < 50)
            cfg.CHECK_INTERVAL_MS := 50

        this.transparencyTimer := ObjBindMethod(this, "ApplyTransparencyForCurrentFocus")
        SetTimer(this.transparencyTimer, cfg.CHECK_INTERVAL_MS)
    }

    ApplyTransparencyForCurrentFocus(*) {
        cfg := ConfigAppSettings.WINDOW.TRANSPARENCY
        if !cfg.ENABLED
            return

        if !this.IsVisible()
            return

        activeAlpha := this.ClampAlpha(cfg.ACTIVE_ALPHA)
        inactiveAlpha := this.ClampAlpha(cfg.INACTIVE_ALPHA)
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
        if (alpha >= 255) {
            try WinSetTransparent("Off", "ahk_id " hwnd)
            return
        }
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
