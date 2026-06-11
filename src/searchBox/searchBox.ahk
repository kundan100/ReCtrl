#Requires AutoHotkey v2

#Include configSearchBox.ahk
#Include guiNative\searchBoxGuiNative.ahk
#Include searchBoxHandler.ahk

class SearchBox {
    gui := ""
    handler := ""
    isEmbedded := false

    __New(parentGui := "", x := 20, y := 20, w := 500, h := 30) {
        this.Initialize(parentGui, x, y, w, h)
    }

    Initialize(parentGui, x, y, w, h) {
        if (SearchBoxConfig.UI_MODE != "NATIVE") {
            throw Error("Only NATIVE UI_MODE is currently supported in searchBox module.")
        }

        this.isEmbedded := IsObject(parentGui)
        this.gui := SearchBoxGuiNative(parentGui, x, y, w, h)
        this.handler := SearchBoxHandler(this.gui)
    }

    Show() {
        this.gui.Show()
    }

    Hide() {
        this.gui.Hide()
    }

    Toggle() {
        this.gui.Toggle()
    }

    Reposition(x, y, w, h) {
        this.gui.Reposition(x, y, w, h)
    }

    Focus() {
        this.gui.Focus()
    }
}
