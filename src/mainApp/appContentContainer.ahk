; ===== App Content Container =====
; Content section controls on the main app Gui

#Requires AutoHotkey v2

class AppContentContainer {
    gui := ""
    headerHeight := 0
    contentBg := ""

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
    }

    Reposition(clientW, clientH) {
        contentH := clientH - this.headerHeight
        this.contentBg.Move(, this.headerHeight, clientW, contentH)
    }
}
