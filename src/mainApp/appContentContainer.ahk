; ===== App Content Container =====
; Content section controls on the main app Gui

#Requires AutoHotkey v2

#Include ..\searchBox\searchBox.ahk

class AppContentContainer {
    gui := ""
    headerHeight := 0
    contentBg := ""
    chipBar := ""
    searchBox := ""
    cfg := ""

    __New(parentGui, headerHeight) {
        this.gui := parentGui
        this.headerHeight := headerHeight
        this.SyncCfg()
        this.Build()
    }

    ; Preset/toggle replace ConfigAppSettings.CONTENT — keep local alias current.
    SyncCfg() {
        this.cfg := ConfigAppSettings.CONTENT
    }

    Build() {
        this.SyncCfg()
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
        this.CalcVerticalFlow(this.headerHeight, &chipBarY, &searchY)

        if this.cfg.CHIP_BAR.SHOW {
            this.chipBar := ChipBarControl(this.gui, searchX, chipBarY, searchW)
        }

        if searchCfg.SHOW {
            this.searchBox := SearchBox(this.gui, searchX, searchY, searchW, searchCfg.HEIGHT)
        }
    }

    Reposition(clientW, clientH) {
        this.SyncCfg()
        if !this.cfg.SHOW
            return

        padX := this.cfg.PADDING_X
        contentH := clientH - this.headerHeight
        if this.contentBg
            this.contentBg.Move(, this.headerHeight, clientW, contentH)

        searchCfg := this.cfg.SEARCH_BOX
        this.CalcSearchLayout(clientW, padX, searchCfg, &searchX, &searchW)
        this.CalcVerticalFlow(this.headerHeight, &chipBarY, &searchY)

        if this.chipBar
            this.chipBar.Reposition(searchX, chipBarY, searchW)

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

    ; Create / show / hide chip bar when VIEW_PRESETS (or toggles) change SHOW.
    ApplyChipBarVisibility() {
        this.SyncCfg()
        want := !!this.cfg.CHIP_BAR.SHOW
        if want {
            if !this.chipBar || !this.chipBar.HasControls() {
                this.gui.GetClientPos(, , &clientW, )
                padX := this.cfg.PADDING_X
                searchCfg := this.cfg.SEARCH_BOX
                this.CalcSearchLayout(clientW, padX, searchCfg, &searchX, &searchW)
                this.CalcVerticalFlow(this.headerHeight, &chipBarY, &searchY)
                this.chipBar := ChipBarControl(this.gui, searchX, chipBarY, searchW)
            }
            this.chipBar.Show()
        } else if this.chipBar {
            this.chipBar.Hide()
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
    CalcVerticalFlow(headerHeight, &chipBarY, &searchY) {
        cfg := this.cfg
        y := headerHeight + cfg.PADDING_Y
        chipBarY := y
        searchY := y

        if cfg.CHIP_BAR.SHOW {
            y += cfg.CHIP_BAR.MARGIN_TOP
            chipBarY := y
            y += cfg.CHIP_BAR.HEIGHT
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
        if cfg.CHIP_BAR.SHOW
            h += cfg.CHIP_BAR.MARGIN_TOP + cfg.CHIP_BAR.HEIGHT
        if cfg.SEARCH_BOX.SHOW
            h += cfg.SEARCH_BOX.MARGIN_TOP + cfg.SEARCH_BOX.HEIGHT
        h += cfg.PADDING_Y
        return h
    }
}
