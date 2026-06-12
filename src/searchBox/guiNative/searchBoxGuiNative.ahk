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
    suggestionCount := 0
    inputX := 0
    inputY := 0
    inputW := 0
    inputH := 0
    embeddedBaseClientHeight := 0

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
        defaultListH := this.CalculateSuggestionListHeight(1)
        this.suggestionsList := hostGui.Add("ListBox",
            "x" x " y" listY " w" w " h" defaultListH " Hidden")
        this.suggestionsList.OnEvent("DoubleClick", (*) => this.OnOptionActivate())
        this.suggestionsList.OnEvent("Change", (*) => this.OnSuggestionChange())

        if !this.isEmbedded {
            this.gui.OnEvent("Escape", (*) => this.Hide())
        }

        this.inputX := x
        this.inputY := y
        this.inputW := w
        this.inputH := inputH
        this.CaptureEmbeddedBaseClientHeight()
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
        visibleOptionCount := this.suggestionCount > 0 ? this.suggestionCount : 1
        listH := this.CalculateSuggestionListHeight(visibleOptionCount)
        this.suggestionsList.Move(x, listY, w, listH)
        this.inputX := x
        this.inputY := y
        this.inputW := w
        this.inputH := inputH

        if this.suggestionCount > 0 {
            this.UpdateEmbeddedHostHeight(true, listH)
        }
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
        listH := this.CalculateSuggestionListHeight(this.suggestionCount)
        listY := this.inputY + this.inputH + NativeUiConfig.SUGGESTION_LIST_GAP
        this.suggestionsList.Move(this.inputX, listY, this.inputW, listH)
        this.ShowSuggestionPopup(listH)

        if (selectedIndex < 1)
            selectedIndex := 1
        if (selectedIndex > this.suggestionCount)
            selectedIndex := this.suggestionCount
        this.suggestionsList.Choose(selectedIndex)
    }

    ShowSuggestionPopup(listH) {
        this.suggestionsList.Visible := true
        this.UpdateEmbeddedHostHeight(true, listH)
    }

    HideSuggestionPopup() {
        if this.suggestionsList
            this.suggestionsList.Visible := false
        this.suggestionCount := 0
        this.UpdateEmbeddedHostHeight(false)
    }

    DismissSuggestionsIfVisible() {
        if !this.suggestionsList || !this.suggestionsList.Visible || this.suggestionCount <= 0
            return false
        this.SetSuggestionOptions([])
        return true
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

    CaptureEmbeddedBaseClientHeight() {
        if !this.isEmbedded || this.embeddedBaseClientHeight > 0 {
            return
        }
        try this.parentGui.GetClientPos(, , , &clientH)
        if (clientH > 0) {
            this.embeddedBaseClientHeight := clientH
        }
    }

    UpdateEmbeddedHostHeight(showSuggestions, listH := 0) {
        if !this.isEmbedded {
            return
        }

        this.CaptureEmbeddedBaseClientHeight()
        baseClientH := this.embeddedBaseClientHeight
        if (baseClientH <= 0) {
            return
        }

        targetClientH := baseClientH
        if showSuggestions {
            if (listH <= 0) {
                this.suggestionsList.GetPos(, , , &listH)
            }
            if (listH <= 0) {
                fallbackCount := this.suggestionCount > 0 ? this.suggestionCount : 1
                listH := this.CalculateSuggestionListHeight(fallbackCount)
            }
            desiredBottom := this.inputY + this.inputH + NativeUiConfig.SUGGESTION_LIST_GAP + listH + 8
            targetClientH := Max(baseClientH, desiredBottom)
        }

        this.SetParentClientHeight(targetClientH)
    }

    SetParentClientHeight(targetClientH) {
        if !this.parentGui || (targetClientH <= 0) {
            return
        }

        this.parentGui.GetClientPos(, , &clientW, &currentClientH)
        if (currentClientH = targetClientH) {
            return
        }

        this.parentGui.GetPos(&x, &y, &windowW, &windowH)
        frameH := windowH - currentClientH
        targetWindowH := targetClientH + frameH
        this.parentGui.Show("x" x " y" y " w" windowW " h" targetWindowH " NA")
    }

    CalculateSuggestionListHeight(optionCount) {
        visibleRows := optionCount < 1 ? 1 : Min(optionCount, NativeUiConfig.SUGGESTION_MAX_VISIBLE_COUNT)
        listH := (visibleRows * NativeUiConfig.SUGGESTION_ITEM_HEIGHT) + 6
        minSingleRowH := NativeUiConfig.SUGGESTION_ITEM_HEIGHT + 4
        return (listH < minSingleRowH) ? minSingleRowH : listH
    }
}
