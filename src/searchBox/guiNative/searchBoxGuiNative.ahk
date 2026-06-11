#Requires AutoHotkey v2

class SearchBoxGuiNative {
    parentGui := ""
    gui := ""
    searchEdit := ""
    submitBtn := ""
    submitCallback := ""
    queryChangeCallback := ""
    inputFocusCallback := ""
    optionActivateCallback := ""
    isEmbedded := false
    showSubmitButton := false
    submitBtnWidth := 0
    suggestionsList := ""
    suggestionsPopupGui := ""
    suggestionCount := 0
    inputX := 0
    inputY := 0
    inputW := 0
    inputH := 0
    popupTrackTimer := ""
    isPopupTracking := false

    __New(parentGui := "", x := 20, y := 20, w := 500, h := 30) {
        this.CreateGui(parentGui, x, y, w, h)
    }

    CreateGui(parentGui, x, y, w, h) {
        if IsObject(parentGui) {
            this.isEmbedded := true
            this.parentGui := parentGui
            hostGui := this.parentGui
        } else {
            this.gui := Gui("+AlwaysOnTop +Border", "ReCtrl Search")
            this.gui.Name := "ReCtrlSearchBox"
            this.gui.MarginX := 16
            this.gui.MarginY := 16
            hostGui := this.gui
        }

        this.showSubmitButton := NativeUiConfig.SHOW_SUBMIT_BUTTON
        hostGui.SetFont("s10", "Segoe UI")
        inputH := (h > 0) ? h : NativeUiConfig.SEARCH_INPUT_HEIGHT

        btnGap := NativeUiConfig.SUBMIT_BUTTON_GAP
        if this.showSubmitButton {
            this.submitBtn := hostGui.Add("Button", "x0 y0 h" inputH " Default", NativeUiConfig.SUBMIT_BUTTON_TEXT)
            this.submitBtn.GetPos(, , &measuredBtnW)
            this.submitBtnWidth := Max(NativeUiConfig.SUBMIT_BUTTON_MIN_WIDTH, measuredBtnW)
        }

        btnW := this.showSubmitButton ? this.submitBtnWidth : 0
        editW := this.showSubmitButton ? Max(120, w - btnW - btnGap) : w
        this.searchEdit := hostGui.Add("Edit", "x" x " y" y " w" editW " h" inputH)
        this.searchEdit.SetFont("s12", "Segoe UI")
        this.ApplySearchPlaceholder()
        this.searchEdit.OnEvent("Change", (*) => this.OnQueryChange())
        this.searchEdit.OnEvent("Focus", (*) => this.OnInputFocus())

        if this.showSubmitButton {
            btnX := x + editW + btnGap
            this.submitBtn.Move(btnX, y, btnW, inputH)
        } else {
            ; Hidden default button lets Enter trigger submission from the edit control.
            this.submitBtn := hostGui.Add("Button", "x0 y0 w0 h0 Hidden Default", NativeUiConfig.SUBMIT_BUTTON_TEXT)
        }
        this.submitBtn.OnEvent("Click", (*) => this.OnSubmit())

        listY := y + inputH + NativeUiConfig.SUGGESTION_LIST_GAP
        if this.isEmbedded {
            this.suggestionsPopupGui := Gui("+AlwaysOnTop -Caption +Border +ToolWindow", "ReCtrlSearchSuggestions")
            this.suggestionsPopupGui.Opt("+Owner" this.parentGui.Hwnd)
            this.suggestionsPopupGui.MarginX := 0
            this.suggestionsPopupGui.MarginY := 0
            this.suggestionsPopupGui.SetFont("s10", "Segoe UI")
            this.suggestionsList := this.suggestionsPopupGui.Add("ListBox",
                "x0 y0 w" w " h" NativeUiConfig.SUGGESTION_LIST_HEIGHT " Hidden")
        } else {
            this.suggestionsList := hostGui.Add("ListBox",
                "x" x " y" listY " w" w " h" NativeUiConfig.SUGGESTION_LIST_HEIGHT " Hidden")
        }
        this.suggestionsList.OnEvent("DoubleClick", (*) => this.OnOptionActivate())
        this.suggestionsList.OnEvent("Change", (*) => this.OnSuggestionChange())

        if !this.isEmbedded {
            this.gui.OnEvent("Escape", (*) => this.Hide())
        }

        this.inputX := x
        this.inputY := y
        this.inputW := w
        this.inputH := inputH
    }

    SetSubmitCallback(callbackFunc) {
        this.submitCallback := callbackFunc
    }

    SetQueryChangeCallback(callbackFunc) {
        this.queryChangeCallback := callbackFunc
    }

    SetInputFocusCallback(callbackFunc) {
        this.inputFocusCallback := callbackFunc
    }

    SetOptionActivateCallback(callbackFunc) {
        this.optionActivateCallback := callbackFunc
    }

    OnSubmit() {
        if (this.submitCallback) {
            this.submitCallback.Call(this.GetSearchText())
        }
    }

    OnQueryChange() {
        if (this.queryChangeCallback) {
            this.queryChangeCallback.Call(this.GetSearchText())
        }
    }

    OnInputFocus() {
        if (this.inputFocusCallback) {
            this.inputFocusCallback.Call(this.GetSearchText())
        }
    }

    OnOptionActivate() {
        if (this.optionActivateCallback) {
            this.optionActivateCallback.Call(this.GetSelectedIndex())
        }
    }

    OnSuggestionChange() {
        ; ListBox has no "Click" event in AHK v2.
        ; Trigger activation only for mouse selection changes.
        if GetKeyState("LButton", "P") {
            this.OnOptionActivate()
        }
    }

    ApplySearchPlaceholder() {
        static EM_SETCUEBANNER := 0x1501

        placeholder := NativeUiConfig.SEARCH_PLACEHOLDER_TEXT
        if (placeholder = "") {
            return
        }
        drawWhenFocused := NativeUiConfig.SEARCH_PLACEHOLDER_SHOW_WHEN_FOCUSED ? 1 : 0
        SendMessage(
            EM_SETCUEBANNER,
            drawWhenFocused,
            StrPtr(placeholder),
            this.searchEdit
        )
    }

    GetSearchText() {
        return this.searchEdit.Value
    }

    GetOwnerHwnd() {
        if this.isEmbedded {
            return this.parentGui.Hwnd
        }
        return this.gui.Hwnd
    }

    ClearSearch() {
        this.searchEdit.Value := ""
        this.SetSuggestionOptions([])
    }

    Show() {
        if this.isEmbedded {
            this.searchEdit.Visible := true
            this.searchEdit.Enabled := true
            return this.Focus()
        }
        this.gui.Show("AutoSize Center")
        this.searchEdit.Focus()
    }

    Focus() {
        this.searchEdit.Focus()
    }

    IsInputFocused() {
        if this.IsControlFocusedInWindow(this.searchEdit, this.GetOwnerHwnd()) {
            return true
        }
        if this.IsControlFocusedInWindow(this.suggestionsList, this.GetSuggestionHostHwnd()) {
            return true
        }
        return false
    }

    IsControlFocusedInWindow(ctrl, windowHwnd) {
        if !windowHwnd || !ctrl {
            return false
        }
        if !WinExist("ahk_id " windowHwnd) {
            return false
        }

        focusedClassNN := ""
        try focusedClassNN := ControlGetFocus("ahk_id " windowHwnd)
        catch {
            return false
        }
        if (focusedClassNN = "") {
            return false
        }
        focusedHwnd := 0
        try focusedHwnd := ControlGetHwnd(focusedClassNN, "ahk_id " windowHwnd)
        catch {
            return false
        }
        return focusedHwnd = ctrl.Hwnd
    }

    GetSuggestionHostHwnd() {
        if this.isEmbedded {
            return this.suggestionsPopupGui ? this.suggestionsPopupGui.Hwnd : 0
        }
        return this.GetOwnerHwnd()
    }

    Hide() {
        if this.isEmbedded {
            this.HideSuggestionPopup()
            return
        }
        this.suggestionsList.Visible := false
        this.gui.Hide()
    }

    Reposition(x, y, w, h) {
        inputH := (h > 0) ? h : this.inputH
        if this.showSubmitButton {
            btnGap := NativeUiConfig.SUBMIT_BUTTON_GAP
            btnW := this.submitBtnWidth
            editW := Max(120, w - btnW - btnGap)
            this.searchEdit.Move(x, y, editW, inputH)
            this.submitBtn.Move(x + editW + btnGap, y, btnW, inputH)
        } else {
            this.searchEdit.Move(x, y, w, inputH)
        }

        listY := y + inputH + NativeUiConfig.SUGGESTION_LIST_GAP
        if this.isEmbedded {
            this.suggestionsList.Move(0, 0, w, NativeUiConfig.SUGGESTION_LIST_HEIGHT)
            if (this.suggestionsPopupGui && this.suggestionCount > 0) {
                this.PositionSuggestionPopup()
            }
        } else {
            this.suggestionsList.Move(x, listY, w, NativeUiConfig.SUGGESTION_LIST_HEIGHT)
        }
        this.inputX := x
        this.inputY := y
        this.inputW := w
        this.inputH := inputH
    }

    SetSuggestionOptions(optionLabels, selectedIndex := 1) {
        this.suggestionsList.Delete()
        this.suggestionCount := optionLabels.Length
        if (this.suggestionCount = 0) {
            this.HideSuggestionPopup()
            return
        }

        for label in optionLabels {
            this.suggestionsList.Add([label])
        }
        maxVisible := Min(this.suggestionCount, NativeUiConfig.SUGGESTION_MAX_VISIBLE_COUNT)
        listH := (maxVisible * NativeUiConfig.SUGGESTION_ITEM_HEIGHT) + 6
        if (listH < NativeUiConfig.SUGGESTION_ITEM_HEIGHT + 4)
            listH := NativeUiConfig.SUGGESTION_ITEM_HEIGHT + 4
        this.suggestionsList.Move(, , this.inputW, listH)
        this.ShowSuggestionPopup(listH)

        if (selectedIndex < 1)
            selectedIndex := 1
        if (selectedIndex > this.suggestionCount)
            selectedIndex := this.suggestionCount
        this.suggestionsList.Choose(selectedIndex)
    }

    ShowSuggestionPopup(listH) {
        if this.isEmbedded {
            this.PositionSuggestionPopup(listH)
            this.suggestionsPopupGui.Show("NoActivate")
            this.suggestionsList.Visible := true
            this.StartPopupTracking()
            return
        }
        this.suggestionsList.Visible := true
    }

    HideSuggestionPopup() {
        if this.isEmbedded {
            this.StopPopupTracking()
            if this.suggestionsList
                this.suggestionsList.Visible := false
            if this.suggestionsPopupGui
                this.suggestionsPopupGui.Hide()
            return
        }
        if this.suggestionsList
            this.suggestionsList.Visible := false
    }

    PositionSuggestionPopup(listH := 0) {
        if !this.isEmbedded || !this.suggestionsPopupGui {
            return
        }
        if (listH <= 0) {
            this.suggestionsList.GetPos(, , , &listH)
            if (listH <= 0)
                listH := NativeUiConfig.SUGGESTION_LIST_HEIGHT
        }

        this.searchEdit.GetPos(&editX, &editY)
        popupX := editX
        popupY := editY + this.inputH + NativeUiConfig.SUGGESTION_LIST_GAP
        pt := Buffer(8, 0)
        NumPut("Int", popupX, pt, 0)
        NumPut("Int", popupY, pt, 4)
        DllCall("ClientToScreen", "Ptr", this.GetOwnerHwnd(), "Ptr", pt)
        popupScreenX := NumGet(pt, 0, "Int")
        popupScreenY := NumGet(pt, 4, "Int")
        this.suggestionsPopupGui.Show("x" popupScreenX " y" popupScreenY " w" this.inputW " h" listH " NoActivate")
    }

    StartPopupTracking() {
        if !this.isEmbedded || !this.suggestionsPopupGui || this.isPopupTracking {
            return
        }
        this.popupTrackTimer := ObjBindMethod(this, "TrackPopupPosition")
        SetTimer(this.popupTrackTimer, 30)
        this.isPopupTracking := true
    }

    StopPopupTracking() {
        if !this.isPopupTracking {
            return
        }
        SetTimer(this.popupTrackTimer, 0)
        this.isPopupTracking := false
    }

    TrackPopupPosition() {
        if !this.suggestionCount {
            return
        }
        this.PositionSuggestionPopup()
    }

    GetSelectedIndex() {
        if !this.suggestionCount
            return 0
        idx := this.suggestionsList.Value
        return idx ? idx : 1
    }

    MoveSelection(step) {
        if !this.suggestionCount
            return false
        idx := this.GetSelectedIndex() + step
        if (idx < 1)
            idx := 1
        if (idx > this.suggestionCount)
            idx := this.suggestionCount
        this.suggestionsList.Choose(idx)
        return true
    }

    Toggle() {
        if this.isEmbedded {
            return this.Focus()
        }
        if this.IsVisible() {
            this.Hide()
        } else {
            this.Show()
        }
    }

    IsVisible() {
        if this.isEmbedded {
            return true
        }
        return this.gui.Hwnd && DllCall("IsWindowVisible", "Ptr", this.gui.Hwnd)
    }
}
