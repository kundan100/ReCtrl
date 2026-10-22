#Requires AutoHotkey v2

; Horizontal chip bar above the search field.
; Config: ConfigAppSettings.CONTENT.CHIP_BAR (chips[] drawn in JSON order).
; Chip types: "context" (AppContext checkbox), "temp" (placeholder button).
class ChipBarControl {
    hostGui := ""
    chipItems := []
    isVisible := false
    syncing := false
    contextCheckbox := ""
    barX := 0
    barY := 0
    barW := 0

    __New(hostGui, x, y, w) {
        this.hostGui := hostGui
        this.isVisible := ChipBarControl.IsEnabledByConfig()
        if !this.isVisible
            return
        this.BuildChips(x, y, w)
    }

    static IsEnabledByConfig() {
        try return !!ConfigAppSettings.CONTENT.CHIP_BAR.SHOW
        catch
            return !!NativeUiConfig.SHOW_CHIP_BAR
    }

    static ConfigHeight() {
        try return Integer(ConfigAppSettings.CONTENT.CHIP_BAR.HEIGHT)
        catch
            return 20
    }

    static ConfigGap() {
        try {
            cfg := ConfigAppSettings.CONTENT.CHIP_BAR
            if cfg.HasOwnProp("GAP")
                return Integer(cfg.GAP)
        }
        return 8
    }

    static GetChipsConfig() {
        try {
            cfg := ConfigAppSettings.CONTENT.CHIP_BAR
            if cfg.HasOwnProp("chips") && (cfg.chips is Array)
                return cfg.chips
        }
        return []
    }

    HasControls() {
        return this.chipItems.Length > 0
    }

    BuildChips(x, y, w) {
        this.barX := x
        this.barY := y
        this.barW := w
        this.chipItems := []
        this.contextCheckbox := ""

        h := ChipBarControl.ConfigHeight()
        gap := ChipBarControl.ConfigGap()
        cursorX := x
        this.hostGui.SetFont("s9", "Segoe UI")

        for chipDef in ChipBarControl.GetChipsConfig() {
            if !ChipBarControl.ChipWantShow(chipDef)
                continue

            type := ChipBarControl.ChipType(chipDef)
            label := ChipBarControl.ChipLabel(chipDef)
            chipW := ChipBarControl.EstimateChipWidth(label, type)
            if (cursorX + chipW > x + w && cursorX > x)
                break

            item := Map("type", type, "def", chipDef, "ctrl", "")
            if (type = "context") {
                ctrl := this.hostGui.Add("Checkbox", "x" cursorX " y" y " w" chipW " h" h, label)
                this.contextCheckbox := ctrl
                ctrl.OnEvent("Click", (*) => this.OnContextClick())
                item["ctrl"] := ctrl
                this.chipItems.Push(item)
                this.SyncFromAppContext()
                AppContext.OnEnabledChanged((*) => this.SyncFromAppContext())
            } else {
                ; Temporary placeholder chip — no real action yet.
                ctrl := this.hostGui.Add("Button", "x" cursorX " y" y " w" chipW " h" h, label)
                item["ctrl"] := ctrl
                this.chipItems.Push(item)
            }
            cursorX += chipW + gap
        }
        this.isVisible := this.HasControls()
    }

    static ChipWantShow(chipDef) {
        if !(chipDef is Object)
            return false
        if chipDef.HasOwnProp("SHOW")
            return !!chipDef.SHOW
        return true
    }

    static ChipType(chipDef) {
        if chipDef.HasOwnProp("type") && Trim(String(chipDef.type)) != ""
            return StrLower(Trim(String(chipDef.type)))
        if chipDef.HasOwnProp("id") && Trim(String(chipDef.id)) != ""
            return StrLower(Trim(String(chipDef.id)))
        return "temp"
    }

    static ChipLabel(chipDef) {
        if chipDef.HasOwnProp("label") && Trim(String(chipDef.label)) != ""
            return Trim(String(chipDef.label))
        if chipDef.HasOwnProp("id") && Trim(String(chipDef.id)) != ""
            return Trim(String(chipDef.id))
        return "Chip"
    }

    static EstimateChipWidth(label, type) {
        ; Rough fit for s9 Segoe UI; checkbox needs room for the box.
        base := 12 + (StrLen(label) * 7)
        if (type = "context")
            return Max(72, base + 18)
        return Max(56, base + 10)
    }

    OnContextClick() {
        if !this.contextCheckbox || this.syncing
            return
        AppContext.SetEnabled(!!this.contextCheckbox.Value)
    }

    SyncFromAppContext() {
        if !this.contextCheckbox
            return
        this.syncing := true
        try this.contextCheckbox.Value := AppContext.IsEnabled() ? 1 : 0
        finally this.syncing := false
    }

    Reposition(x, y, w) {
        if !this.HasControls()
            return
        this.barX := x
        this.barY := y
        this.barW := w

        h := ChipBarControl.ConfigHeight()
        gap := ChipBarControl.ConfigGap()
        cursorX := x
        for item in this.chipItems {
            ctrl := item["ctrl"]
            if !ctrl
                continue
            type := item["type"]
            label := ChipBarControl.ChipLabel(item["def"])
            chipW := ChipBarControl.EstimateChipWidth(label, type)
            if (cursorX + chipW > x + w && cursorX > x)
                break
            ctrl.Move(cursorX, y, chipW, h)
            cursorX += chipW + gap
        }
    }

    Show() {
        if !ChipBarControl.IsEnabledByConfig()
            return
        if !this.HasControls()
            return
        for item in this.chipItems {
            if item["ctrl"]
                item["ctrl"].Visible := true
        }
        this.isVisible := true
        this.SyncFromAppContext()
    }

    Hide() {
        for item in this.chipItems {
            if item["ctrl"]
                item["ctrl"].Visible := false
        }
        this.isVisible := false
    }
}
