#Requires AutoHotkey v2

class SearchBoxGuiNative {
    parentGui := ""
    gui := ""
    searchEdit := ""
    submitBtn := ""
    submitCallback := ""
    isEmbedded := false
    showSubmitButton := false
    submitBtnWidth := 0

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

        btnGap := NativeUiConfig.SUBMIT_BUTTON_GAP
        if this.showSubmitButton {
            this.submitBtn := hostGui.Add("Button", "x0 y0 h" h " Default", NativeUiConfig.SUBMIT_BUTTON_TEXT)
            this.submitBtn.GetPos(, , &measuredBtnW)
            this.submitBtnWidth := Max(NativeUiConfig.SUBMIT_BUTTON_MIN_WIDTH, measuredBtnW)
        }

        btnW := this.showSubmitButton ? this.submitBtnWidth : 0
        editW := this.showSubmitButton ? Max(120, w - btnW - btnGap) : w
        this.searchEdit := hostGui.Add("Edit", "x" x " y" y " w" editW " h" h)
        this.searchEdit.SetFont("s12", "Segoe UI")

        if this.showSubmitButton {
            btnX := x + editW + btnGap
            this.submitBtn.Move(btnX, y, btnW, h)
        } else {
            ; Hidden default button lets Enter trigger submission from the edit control.
            this.submitBtn := hostGui.Add("Button", "x0 y0 w0 h0 Hidden Default", NativeUiConfig.SUBMIT_BUTTON_TEXT)
        }
        this.submitBtn.OnEvent("Click", (*) => this.OnSubmit())

        if !this.isEmbedded {
            this.gui.OnEvent("Escape", (*) => this.Hide())
        }
    }

    SetSubmitCallback(callbackFunc) {
        this.submitCallback := callbackFunc
    }

    OnSubmit() {
        if (this.submitCallback) {
            this.submitCallback.Call(this.GetSearchText())
        }
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

    Hide() {
        if this.isEmbedded {
            return
        }
        this.gui.Hide()
    }

    Reposition(x, y, w, h) {
        if this.showSubmitButton {
            btnGap := NativeUiConfig.SUBMIT_BUTTON_GAP
            btnW := this.submitBtnWidth
            editW := Max(120, w - btnW - btnGap)
            this.searchEdit.Move(x, y, editW, h)
            this.submitBtn.Move(x + editW + btnGap, y, btnW, h)
        } else {
            this.searchEdit.Move(x, y, w, h)
        }
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
