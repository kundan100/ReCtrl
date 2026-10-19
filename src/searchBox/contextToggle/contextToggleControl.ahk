#Requires AutoHotkey v2

; Modular Context checkbox (above search field).
; Layout/visibility: ConfigAppSettings.CONTENT.CONTEXT_TOGGLE
class ContextToggleControl {
    static LABEL := "Context"

    hostGui := ""
    checkbox := ""
    isVisible := false
    syncing := false

    __New(hostGui, x, y, w) {
        this.hostGui := hostGui
        this.isVisible := ContextToggleControl.IsEnabledByConfig()
        if !this.isVisible
            return

        h := ContextToggleControl.ConfigHeight()
        hostGui.SetFont("s9", "Segoe UI")
        this.checkbox := hostGui.Add(
            "Checkbox",
            "x" x " y" y " w" w " h" h,
            ContextToggleControl.LABEL
        )
        this.SyncFromAppContext()
        this.checkbox.OnEvent("Click", (*) => this.OnClick())
        AppContext.OnEnabledChanged((*) => this.SyncFromAppContext())
    }

    static IsEnabledByConfig() {
        try return !!ConfigAppSettings.CONTENT.CONTEXT_TOGGLE.SHOW
        catch
            return !!NativeUiConfig.SHOW_CONTEXT_TOGGLE
    }

    static ConfigHeight() {
        try return Integer(ConfigAppSettings.CONTENT.CONTEXT_TOGGLE.HEIGHT)
        catch
            return 20
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
        this.checkbox.Move(x, y, w, ContextToggleControl.ConfigHeight())
    }

    Show() {
        if !this.checkbox || !ContextToggleControl.IsEnabledByConfig()
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
