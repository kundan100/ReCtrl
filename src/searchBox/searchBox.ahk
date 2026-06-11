#Requires AutoHotkey v2

#Include configSearchBox.ahk
#Include searchActionsConfig.ahk
#Include guiNative\searchBoxGuiNative.ahk
#Include searchBoxHandler.ahk

global gSearchBoxHotkeyTarget := ""

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
        global gSearchBoxHotkeyTarget
        gSearchBoxHotkeyTarget := this
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

    IsInputFocused() {
        return this.gui.IsInputFocused()
    }

    SelectRelative(step) {
        return this.handler.MoveSelection(step)
    }

    SubmitCurrent() {
        this.handler.SubmitCurrent()
    }

    ActivateCurrentOption() {
        this.handler.ActivateSelectedOption()
    }

    IsQueryBlank() {
        return Trim(this.gui.GetSearchText()) = ""
    }

    OnEmptyEraseKey() {
        this.handler.OnEmptyEraseKey()
    }
}

SearchBox_IsInputFocused() {
    global gSearchBoxHotkeyTarget, mainAppInstance

    ; Extra guard: do not evaluate search-box focus unless MainApp is visible.
    if !IsObject(mainAppInstance) || !IsObject(mainAppInstance.container) {
        return false
    }
    try {
        if !mainAppInstance.container.IsVisible() {
            return false
        }
    } catch {
        return false
    }

    if !IsObject(gSearchBoxHotkeyTarget) {
        return false
    }
    try {
        return gSearchBoxHotkeyTarget.IsInputFocused()
    } catch {
        return false
    }
}

SearchBox_IsInputFocusedAndBlank() {
    global gSearchBoxHotkeyTarget
    if !SearchBox_IsInputFocused() {
        return false
    }
    if !IsObject(gSearchBoxHotkeyTarget) {
        return false
    }
    try {
        return gSearchBoxHotkeyTarget.IsQueryBlank()
    } catch {
        return false
    }
}

#HotIf SearchBox_IsInputFocused()
Up:: {
    global gSearchBoxHotkeyTarget
    gSearchBoxHotkeyTarget.SelectRelative(-1)
}

Down:: {
    global gSearchBoxHotkeyTarget
    gSearchBoxHotkeyTarget.SelectRelative(1)
}

Enter:: {
    global gSearchBoxHotkeyTarget
    gSearchBoxHotkeyTarget.SubmitCurrent()
}
#HotIf

#HotIf SearchBox_IsInputFocusedAndBlank()
Backspace:: {
    global gSearchBoxHotkeyTarget
    gSearchBoxHotkeyTarget.OnEmptyEraseKey()
}

Delete:: {
    global gSearchBoxHotkeyTarget
    gSearchBoxHotkeyTarget.OnEmptyEraseKey()
}
#HotIf
