#Requires AutoHotkey v2

; Modular Context checkbox (above search field).
; Visibility is controlled by NativeUiConfig.SHOW_CONTEXT_TOGGLE for easy hide/show later.
class ContextToggleControl {
    static LABEL := "Context"
    static HEIGHT := 20
    static GAP_BELOW := 4

    hostGui := ""
    checkbox := ""
    isVisible := false
    syncing := false

    __New(hostGui, x, y, w) {
        this.hostGui := hostGui
        this.isVisible := NativeUiConfig.SHOW_CONTEXT_TOGGLE
        if !this.isVisible
            return

        hostGui.SetFont("s9", "Segoe UI")
        this.checkbox := hostGui.Add(
            "Checkbox",
            "x" x " y" y " w" w " h" ContextToggleControl.HEIGHT,
            ContextToggleControl.LABEL
        )
        this.SyncFromAppContext()
        this.checkbox.OnEvent("Click", (*) => this.OnClick())
        AppContext.OnEnabledChanged((*) => this.SyncFromAppContext())
    }

    ; Height reserved above the search field (0 when hidden by config).
    static OccupiedHeight() {
        if !NativeUiConfig.SHOW_CONTEXT_TOGGLE
            return 0
        return ContextToggleControl.HEIGHT + ContextToggleControl.GAP_BELOW
    }

    OnClick() {
        if !this.checkbox || this.syncing
            return
        AppContext.SetEnabled(!!this.checkbox.Value)
    }

    SyncFromAppContext() {
        if !this.checkbox
            return
        this.syncing := true
        try this.checkbox.Value := AppContext.IsEnabled() ? 1 : 0
        finally this.syncing := false
    }

    Reposition(x, y, w) {
        if !this.checkbox
            return
        this.checkbox.Move(x, y, w, ContextToggleControl.HEIGHT)
    }

    Show() {
        if !this.checkbox || !NativeUiConfig.SHOW_CONTEXT_TOGGLE
            return
        this.checkbox.Visible := true
        this.isVisible := true
        this.SyncFromAppContext()
    }

    Hide() {
        if !this.checkbox
            return
        this.checkbox.Visible := false
        this.isVisible := false
    }
}
