; ===== App Content Container =====
; Content section controls on the main app Gui

#Requires AutoHotkey v2

#Include ..\searchBox\searchBox.ahk

class AppContentContainer {
    gui := ""
    headerHeight := 0
    contentBg := ""
    contextToggle := ""
    searchBox := ""
    cfg := ""

    __New(parentGui, headerHeight) {
        this.gui := parentGui
        this.headerHeight := headerHeight
        this.cfg := ConfigAppSettings.CONTENT
        this.Build()
    }

    Build() {
        if !this.cfg.SHOW
            return

        w := ConfigAppSettings.WINDOW.WIDTH
        h := ConfigAppSettings.WINDOW.HEIGHT - this.headerHeight
        padX := this.cfg.PADDING_X

        this.contentBg := this.gui.Add("Text",
            "x0 y" this.headerHeight " w" w " h" h " Background" this.cfg.BG_COLOR " Center",
            this.cfg.DUMMY_TEXT)

        searchCfg := this.cfg.SEARCH_BOX
        this.CalcSearchLayout(w, padX, searchCfg, &searchX, &searchW)
        this.CalcVerticalFlow(this.headerHeight, &toggleY, &searchY)

        if this.cfg.CONTEXT_TOGGLE.SHOW {
            this.contextToggle := ContextToggleControl(this.gui, searchX, toggleY, searchW)
        }

        if searchCfg.SHOW {
            this.searchBox := SearchBox(this.gui, searchX, searchY, searchW, searchCfg.HEIGHT)
        }
    }

    Reposition(clientW, clientH) {
        if !this.cfg.SHOW
            return

        padX := this.cfg.PADDING_X
        contentH := clientH - this.headerHeight
        if this.contentBg
            this.contentBg.Move(, this.headerHeight, clientW, contentH)

        searchCfg := this.cfg.SEARCH_BOX
        this.CalcSearchLayout(clientW, padX, searchCfg, &searchX, &searchW)
        this.CalcVerticalFlow(this.headerHeight, &toggleY, &searchY)

        if this.contextToggle
            this.contextToggle.Reposition(searchX, toggleY, searchW)

        if this.searchBox
            this.searchBox.Reposition(searchX, searchY, searchW, searchCfg.HEIGHT)
    }

    ; Live header show/hide: shift content band and search UI.
    SetHeaderHeight(headerHeight) {
        this.headerHeight := Max(0, Integer(headerHeight))
        if !this.gui
            return
        this.gui.GetClientPos(, , &clientW, &clientH)
        this.Reposition(clientW, clientH)
        try {
            if this.searchBox && this.searchBox.gui
                this.searchBox.gui.embeddedBaseClientHeight := 0
        }
    }

    ; Inset by PADDING_X first, then fit/center SEARCH_BOX within that padded band.
    ; MAX_WIDTH <= 0 means fill the padded width (so PADDING_X is the visible side inset).
    CalcSearchLayout(clientW, padX, searchCfg, &searchX, &searchW) {
        innerLeft := padX
        innerW := Max(0, clientW - 2 * padX)
        maxW := searchCfg.MAX_WIDTH
        if (maxW <= 0 || maxW > innerW)
            searchW := innerW
        else
            searchW := maxW
        searchX := innerLeft + Floor((innerW - searchW) / 2)
    }

    ; Stack content children using each child's MARGIN_TOP from JSON.
    ; Flow: CONTENT.PADDING_Y → [child.MARGIN_TOP + child]… → CONTENT.PADDING_Y
    CalcVerticalFlow(headerHeight, &toggleY, &searchY) {
        cfg := this.cfg
        y := headerHeight + cfg.PADDING_Y
        toggleY := y
        searchY := y

        if cfg.CONTEXT_TOGGLE.SHOW {
            y += cfg.CONTEXT_TOGGLE.MARGIN_TOP
            toggleY := y
            y += cfg.CONTEXT_TOGGLE.HEIGHT
        }

        if cfg.SEARCH_BOX.SHOW {
            y += cfg.SEARCH_BOX.MARGIN_TOP
            searchY := y
        }
    }

    FocusSearchBox() {
        if this.searchBox
            this.searchBox.Focus()
    }

    DismissSuggestionsIfVisible() {
        if !this.searchBox
            return false
        return this.searchBox.DismissSuggestionsIfVisible()
    }

    HideTransientUi() {
        if this.searchBox
            this.searchBox.Hide()
    }

    ; Preferred content height for collapsed window (header excluded).
    static PreferredContentHeight() {
        cfg := ConfigAppSettings.CONTENT
        if !cfg.SHOW
            return 0

        h := cfg.PADDING_Y
        if cfg.CONTEXT_TOGGLE.SHOW
            h += cfg.CONTEXT_TOGGLE.MARGIN_TOP + cfg.CONTEXT_TOGGLE.HEIGHT
        if cfg.SEARCH_BOX.SHOW
            h += cfg.SEARCH_BOX.MARGIN_TOP + cfg.SEARCH_BOX.HEIGHT
        h += cfg.PADDING_Y
        return h
    }
}
