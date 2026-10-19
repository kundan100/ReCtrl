#Requires AutoHotkey v2

#Include ..\..\shared\editControlColors.ahk

class SearchBoxGuiNative {
    parentGui := ""
    gui := ""
    searchEdit := ""
    searchEditBg := ""
    searchPlaceholder := ""
    searchEditBgColor := "FFFFFF"
    submitBtn := ""
    submitCallback := ""
    queryChangeCallback := ""
    inputFocusCallback := ""
    optionActivateCallback := ""
    selectionChangeCallback := ""
    isEmbedded := false
    showSubmitButton := false
    submitBtnWidth := 0
    suggestionsList := ""
    suggestionCount := 0
    highlightMatchedSearchToken := ""
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
            this.gui := Gui("+AlwaysOnTop +Border", ConfigAppSettings.APP_NAME " Search")
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
        ; Full-height field: Multi enables EM_SETRECT vertical centering; -VScroll/-WantReturn
        ; avoid scrollbar + keep Enter on Default button. Custom Text hint (cue banner won't center).
        this.searchEditBg := hostGui.Add("Text",
            "x" x " y" y " w" editW " h" inputH " BackgroundFFFFFF", "")
        this.searchEdit := hostGui.Add("Edit",
            "x" x " y" y " w" editW " h" inputH " -E0x200 Multi -WantReturn -VScroll")
        this.searchPlaceholder := hostGui.Add("Text",
            "x" x " y" y " w" editW " h" inputH " BackgroundTrans c808080",
            NativeUiConfig.SEARCH_PLACEHOLDER_TEXT)
        this.searchPlaceholder.SetFont("s12", "Segoe UI")
        this.searchPlaceholder.OnEvent("Click", (*) => this.Focus())
        this.ApplySearchEditColors()
        this.LayoutSearchEdit(x, y, editW, inputH)
        this.searchEdit.OnEvent("Change", (*) => this.OnSearchEditChange())
        this.searchEdit.OnEvent("Focus", (*) => this.OnSearchEditFocus())
        this.searchEdit.OnEvent("LoseFocus", (*) => this.UpdateSearchPlaceholder())

        if this.showSubmitButton {
            btnX := x + editW + btnGap
            this.submitBtn.Move(btnX, y, btnW, inputH)
        } else {
            ; Hidden default button lets Enter trigger submission from the edit control.
            this.submitBtn := hostGui.Add("Button", "x0 y0 w0 h0 Hidden Default", NativeUiConfig.SUBMIT_BUTTON_TEXT)
        }
        this.submitBtn.OnEvent("Click", (*) => this.OnSubmit())

        listY := y + inputH + this.OptionsListMarginTop()
        defaultListH := this.CalculateSuggestionListHeight(1)
        this.suggestionsList := hostGui.Add("ListBox",
            "x" x " y" listY " w" w " h" defaultListH " Hidden")
        this.suggestionsList.OnEvent("DoubleClick", (*) => this.OnOptionActivate())
        this.suggestionsList.OnEvent("Change", (*) => this.OnSuggestionChange())

        hintMargin := 2
        hintH := 20
        try {
            hintCfg := ConfigAppSettings.CONTENT.HIGHLIGHT_MATCHED_TOKEN
            hintMargin := Integer(hintCfg.MARGIN_TOP)
            hintH := Integer(hintCfg.HEIGHT)
        }
        hintY := listY + defaultListH + hintMargin
        this.highlightMatchedSearchToken := HighlightMatchedSearchTokenControl(hostGui, x, hintY, w)

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

    SetSelectionChangeCallback(callbackFunc) {
        this.selectionChangeCallback := callbackFunc
    }

    ApplyHighlightMatchedSearchTokenConfig(*) {
        if this.highlightMatchedSearchToken
            this.highlightMatchedSearchToken.ApplyFromAppSettings()
    }

    ShowHighlightMatchedSearchToken(query, action) {
        if !this.highlightMatchedSearchToken || this.suggestionCount <= 0 {
            this.ClearHighlightMatchedSearchToken()
            return
        }
        if this.highlightMatchedSearchToken.ShowFor(query, action) {
            this.LayoutHighlightMatchedSearchToken()
        }
        this.UpdateEmbeddedHostHeight(true)
    }

    ; kind: "recents" | "menu" — blank Enter / Ctrl+Enter list footer hint
    ShowHighlightBlankListHint(kind := "recents") {
        if !this.highlightMatchedSearchToken || this.suggestionCount <= 0 {
            this.ClearHighlightMatchedSearchToken()
            return
        }
        if this.highlightMatchedSearchToken.ShowBlankListHint(kind) {
            this.LayoutHighlightMatchedSearchToken()
        }
        this.UpdateEmbeddedHostHeight(true)
    }

    ClearHighlightMatchedSearchToken() {
        if !this.highlightMatchedSearchToken {
            return
        }
        this.highlightMatchedSearchToken.Clear()
        if this.suggestionCount > 0
            this.UpdateEmbeddedHostHeight(true)
    }

    LayoutHighlightMatchedSearchToken() {
        if !this.highlightMatchedSearchToken {
            return
        }
        this.suggestionsList.GetPos(&listX, &listY, &listW, &listH)
        this.highlightMatchedSearchToken.LayoutBelow(listX, listY, listW, listH)
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
        if (this.selectionChangeCallback) {
            this.selectionChangeCallback.Call(this.GetSelectedIndex())
        }
        ; ListBox has no "Click" event in AHK v2.
        ; Trigger activation only for mouse selection changes.
        if GetKeyState("LButton", "P") {
            this.OnOptionActivate()
        }
    }

    UpdateSearchPlaceholder() {
        if !this.searchPlaceholder
            return
        placeholder := NativeUiConfig.SEARCH_PLACEHOLDER_TEXT
        if (placeholder = "") {
            this.searchPlaceholder.Visible := false
            return
        }
        this.searchPlaceholder.Value := placeholder
        isEmpty := (Trim(this.searchEdit.Value) = "")
        show := isEmpty
        if show && !NativeUiConfig.SEARCH_PLACEHOLDER_SHOW_WHEN_FOCUSED {
            focusHwnd := 0
            try focusHwnd := ControlGetFocus("ahk_id " this.GetOwnerHwnd())
            if (Integer(focusHwnd) = Integer(this.searchEdit.Hwnd))
                show := false
        }
        this.searchPlaceholder.Visible := show
        if show
            this.LayoutSearchPlaceholder()
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
        this.UpdateSearchPlaceholder()
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
        this.ClearHighlightMatchedSearchToken()
        this.suggestionsList.Visible := false
        this.gui.Hide()
    }

    Reposition(x, y, w, h) {
        inputH := (h > 0) ? h : this.inputH
        if this.showSubmitButton {
            btnGap := NativeUiConfig.SUBMIT_BUTTON_GAP
            btnW := this.submitBtnWidth
            editW := Max(120, w - btnW - btnGap)
            this.LayoutSearchEdit(x, y, editW, inputH)
            this.submitBtn.Move(x + editW + btnGap, y, btnW, inputH)
        } else {
            this.LayoutSearchEdit(x, y, w, inputH)
        }

        listY := y + inputH + this.OptionsListMarginTop()
        visibleOptionCount := this.suggestionCount > 0 ? this.suggestionCount : 1
        listH := this.CalculateSuggestionListHeight(visibleOptionCount)
        this.suggestionsList.Move(x, listY, w, listH)
        this.LayoutHighlightMatchedSearchToken()
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
        if !ConfigAppSettings.OptionsListEnabled() {
            this.HideSuggestionPopup()
            return
        }
        this.suggestionCount := optionLabels.Length
        if (this.suggestionCount = 0) {
            this.HideSuggestionPopup()
            return
        }

        for label in optionLabels {
            this.suggestionsList.Add([label])
        }
        listH := this.CalculateSuggestionListHeight(this.suggestionCount)
        listY := this.inputY + this.inputH + this.OptionsListMarginTop()
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
        this.LayoutHighlightMatchedSearchToken()
        this.UpdateEmbeddedHostHeight(true, listH)
    }

    HideSuggestionPopup() {
        this.ClearHighlightMatchedSearchToken()
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
            ; Prefer the ListBox's real height after Move — Windows often snaps shorter than
            ; requested h (integral rows), which left a CONTENT.BG_COLOR gap below the list.
            this.suggestionsList.GetPos(, &listY, , &actualListH)
            if (actualListH <= 0) {
                if (listH <= 0) {
                    fallbackCount := this.suggestionCount > 0 ? this.suggestionCount : 1
                    listH := this.CalculateSuggestionListHeight(fallbackCount)
                }
                actualListH := listH
                listY := this.inputY + this.inputH + this.OptionsListMarginTop()
            }
            highlightH := 0
            if this.highlightMatchedSearchToken
                highlightH := this.highlightMatchedSearchToken.OccupiedHeight()
            desiredBottom := listY + actualListH + highlightH + this.OptionsListMarginBottom()
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

    OptionsListMarginTop() {
        return ConfigAppSettings.OptionsListInt("MARGIN_TOP", NativeUiConfig.SUGGESTION_LIST_GAP)
    }

    OptionsListMarginBottom() {
        return ConfigAppSettings.OptionsListInt("MARGIN_BOTTOM", NativeUiConfig.SUGGESTION_BOTTOM_GAP)
    }

    CalculateSuggestionListHeight(optionCount) {
        maxVisible := ConfigAppSettings.OptionsListInt("MAX_VISIBLE_COUNT", NativeUiConfig.SUGGESTION_MAX_VISIBLE_COUNT)
        itemH := ConfigAppSettings.OptionsListInt("ITEM_HEIGHT", NativeUiConfig.SUGGESTION_ITEM_HEIGHT)
        heightPad := ConfigAppSettings.OptionsListInt("HEIGHT_PADDING", NativeUiConfig.SUGGESTION_LIST_HEIGHT_PADDING)
        minExtra := ConfigAppSettings.OptionsListInt("MIN_EXTRA_HEIGHT", NativeUiConfig.SUGGESTION_LIST_MIN_EXTRA_HEIGHT)
        visibleRows := optionCount < 1 ? 1 : Min(optionCount, maxVisible)
        listH := (visibleRows * itemH) + heightPad
        minSingleRowH := itemH + minExtra
        return (listH < minSingleRowH) ? minSingleRowH : listH
    }

    OnSearchEditFocus(*) {
        ; Re-apply after focus; themed Edits sometimes repaint with system colors.
        this.ApplySearchEditColors()
        this.CenterSearchEditText()
        this.UpdateSearchPlaceholder()
        this.OnInputFocus()
    }

    OnSearchEditChange(*) {
        val := this.searchEdit.Value
        if InStr(val, "`n") || InStr(val, "`r") {
            val := RegExReplace(val, "[\r\n]+", " ")
            this.searchEdit.Value := val
            SendMessage(0x00B1, StrLen(val), StrLen(val), this.searchEdit) ; EM_SETSEL end
        }
        this.UpdateSearchPlaceholder()
        this.OnQueryChange()
    }

    ; CONTENT.SEARCH_BOX.BG_COLOR / TEXT_COLOR
    ApplySearchEditColors() {
        if !this.searchEdit
            return
        bg := 0xFFFFFF
        fg := 0x000000
        try {
            cfg := ConfigAppSettings.CONTENT.SEARCH_BOX
            if Trim(String(cfg.BG_COLOR)) != ""
                bg := EditControlColors.ParseRgb(cfg.BG_COLOR)
            if Trim(String(cfg.TEXT_COLOR)) != ""
                fg := EditControlColors.ParseRgb(cfg.TEXT_COLOR)
        }
        this.searchEditBgColor := Format("{:06X}", bg)
        if this.searchEditBg
            this.searchEditBg.Opt("Background" this.searchEditBgColor)
        EditControlColors.Apply(this.searchEdit.Hwnd, bg, fg)
        this.searchEdit.SetFont("c" Format("{:06X}", fg) " s12", "Segoe UI")
    }

    ; Full SEARCH_BOX.HEIGHT for plate + edit; text/caret centered via EM_SETRECT.
    LayoutSearchEdit(x, y, fieldW, fieldH) {
        if !this.searchEdit
            return
        if this.searchEditBg
            this.searchEditBg.Move(x, y, fieldW, fieldH)
        this.searchEdit.Move(x, y, fieldW, fieldH)
        ; Ensure no vertical scrollbar (Multi can re-add WS_VSCROLL / ES_AUTOVSCROLL).
        try this.searchEdit.Opt("-VScroll")
        try {
            sty := ControlGetStyle(this.searchEdit)
            ControlSetStyle((sty & ~0x200000) & ~0x40, this.searchEdit)
        }
        this.CenterSearchEditText()
        this.UpdateSearchPlaceholder()
    }

    LayoutSearchPlaceholder() {
        if !this.searchPlaceholder || !this.searchEdit
            return
        this.searchEdit.GetPos(&x, &y, &w, &h)
        fontH := this.GetEditFontHeight(this.searchEdit.Hwnd)
        if (fontH <= 0)
            fontH := 18
        padX := 8
        padY := Max(0, (h - fontH) // 2)
        this.searchPlaceholder.Move(x + padX, y + padY, Max(1, w - 2 * padX), fontH)
    }

    ; Vertically center typed text + caret inside the full-height edit.
    CenterSearchEditText() {
        if !this.searchEdit
            return
        hwnd := this.searchEdit.Hwnd
        if !hwnd
            return

        rc := Buffer(16, 0)
        if !DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
            return
        clientW := NumGet(rc, 8, "Int")
        clientH := NumGet(rc, 12, "Int")
        if (clientW <= 0 || clientH <= 0)
            return

        fontH := this.GetEditFontHeight(hwnd)
        if (fontH <= 0)
            fontH := 18

        padX := 8
        padY := Max(0, (clientH - fontH) // 2)
        fmt := Buffer(16, 0)
        NumPut("Int", padX, fmt, 0)
        NumPut("Int", padY, fmt, 4)
        NumPut("Int", Max(padX + 1, clientW - padX), fmt, 8)
        NumPut("Int", Min(clientH - 1, padY + fontH + 2), fmt, 12)
        SendMessage(0x00B3, 0, fmt.Ptr, hwnd) ; EM_SETRECT
        this.LayoutSearchPlaceholder()
    }

    GetEditFontHeight(hwnd) {
        if !hwnd
            return 0
        hFont := SendMessage(0x0031, 0, 0, hwnd) ; WM_GETFONT
        if !hFont
            return 0
        hDC := DllCall("GetDC", "Ptr", hwnd, "Ptr")
        if !hDC
            return 0
        prev := DllCall("SelectObject", "Ptr", hDC, "Ptr", hFont, "Ptr")
        tm := Buffer(64, 0)
        ok := DllCall("GetTextMetrics", "Ptr", hDC, "Ptr", tm)
        DllCall("SelectObject", "Ptr", hDC, "Ptr", prev)
        DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hDC)
        if !ok
            return 0
        return NumGet(tm, 0, "Int") ; tmHeight
    }
}
