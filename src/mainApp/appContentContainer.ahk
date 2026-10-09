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

    __New(parentGui, headerHeight) {
        this.gui := parentGui
        this.headerHeight := headerHeight
        this.Build()
    }

    Build() {
        cfg := AppConfig.CONTENT
        w := AppConfig.WINDOW.WIDTH
        h := AppConfig.WINDOW.HEIGHT - this.headerHeight

        this.contentBg := this.gui.Add("Text",
            "x0 y" this.headerHeight " w" w " h" h " Background" cfg.BG_COLOR " Center",
            cfg.DUMMY_TEXT)

        searchW := Min(520, w - 40)
        searchX := Floor((w - searchW) / 2)
        topPad := NativeUiConfig.CONTENT_TOP_PADDING
        toggleH := ContextToggleControl.OccupiedHeight()

        toggleY := this.headerHeight + topPad
        this.contextToggle := ContextToggleControl(this.gui, searchX, toggleY, searchW)

        searchY := this.headerHeight + topPad + toggleH
        this.searchBox := SearchBox(this.gui, searchX, searchY, searchW, NativeUiConfig.SEARCH_INPUT_HEIGHT)
    }

    Reposition(clientW, clientH) {
        contentH := clientH - this.headerHeight
        this.contentBg.Move(, this.headerHeight, clientW, contentH)

        searchW := Min(520, clientW - 40)
        searchX := Floor((clientW - searchW) / 2)
        topPad := NativeUiConfig.CONTENT_TOP_PADDING
        toggleH := ContextToggleControl.OccupiedHeight()

        if this.contextToggle
            this.contextToggle.Reposition(searchX, this.headerHeight + topPad, searchW)

        searchY := this.headerHeight + topPad + toggleH
        this.searchBox.Reposition(searchX, searchY, searchW, NativeUiConfig.SEARCH_INPUT_HEIGHT)
    }

    FocusSearchBox() {
        this.searchBox.Focus()
    }

    DismissSuggestionsIfVisible() {
        return this.searchBox.DismissSuggestionsIfVisible()
    }

    HideTransientUi() {
        this.searchBox.Hide()
    }

    ; Preferred content height for collapsed window (header excluded).
    static PreferredContentHeight() {
        return NativeUiConfig.CONTENT_TOP_PADDING
            + ContextToggleControl.OccupiedHeight()
            + NativeUiConfig.SEARCH_INPUT_HEIGHT
            + NativeUiConfig.CONTENT_BOTTOM_PADDING
    }
}
