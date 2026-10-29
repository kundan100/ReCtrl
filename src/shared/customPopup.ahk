#Requires AutoHotkey v2

; Shared fixed-height popup with selectable, scrollable text (ReadOnly Edit).
; Reusable for tips, details, diagnostics, etc.
; Public API:
;   CustomPopup.Show(text, title := "", ownerHwnd := 0, options := unset)
; options (Map, all optional): width, bodyHeight, padding, buttonWidth, buttonHeight,
;   fontSize, fontName, buttonLabel
class CustomPopup {
    static DEFAULT_WIDTH := 520
    static DEFAULT_BODY_HEIGHT := 420
    static DEFAULT_PADDING := 12
    static DEFAULT_BUTTON_HEIGHT := 28
    static DEFAULT_BUTTON_WIDTH := 88
    static DEFAULT_FONT_SIZE := "s9"
    static DEFAULT_FONT_NAME := "Consolas"
    static DEFAULT_BUTTON_LABEL := "Close"

    ; Show modal dialog. Text is selectable/copyable; body scrolls when long.
    static Show(text, title := "", ownerHwnd := 0, options := unset) {
        text := String(text)
        if (Trim(title) = "")
            title := ConfigAppSettings.APP_NAME
        ; Tip/callers often omit options; unset must not be read (AHK: "parameter has not been assigned").
        if !IsSet(options) || !IsObject(options)
            options := Map()

        width := CustomPopup.OptInt(options, "width", CustomPopup.DEFAULT_WIDTH)
        bodyHeight := CustomPopup.OptInt(options, "bodyHeight", CustomPopup.DEFAULT_BODY_HEIGHT)
        padding := CustomPopup.OptInt(options, "padding", CustomPopup.DEFAULT_PADDING)
        buttonWidth := CustomPopup.OptInt(options, "buttonWidth", CustomPopup.DEFAULT_BUTTON_WIDTH)
        buttonHeight := CustomPopup.OptInt(options, "buttonHeight", CustomPopup.DEFAULT_BUTTON_HEIGHT)
        fontSize := CustomPopup.OptStr(options, "fontSize", CustomPopup.DEFAULT_FONT_SIZE)
        fontName := CustomPopup.OptStr(options, "fontName", CustomPopup.DEFAULT_FONT_NAME)
        buttonLabel := CustomPopup.OptStr(options, "buttonLabel", CustomPopup.DEFAULT_BUTTON_LABEL)

        opts := "+AlwaysOnTop -MinimizeBox +OwnDialogs"
        g := Gui(opts, title)
        if ownerHwnd {
            try g.Opt("+Owner" ownerHwnd)
        }

        g.MarginX := padding
        g.MarginY := padding
        g.SetFont(fontSize, fontName)

        bodyW := width - (padding * 2)
        ; ReadOnly + Multi + VScroll: select/copy allowed; edit blocked; scroll when needed.
        edit := g.Add("Edit",
            "w" bodyW " h" bodyHeight " ReadOnly Multi WantTab VScroll -Wrap",
            text)

        g.SetFont("s9", "Segoe UI")
        btn := g.Add("Button", "Default w" buttonWidth " h" buttonHeight, buttonLabel)
        btn.OnEvent("Click", (*) => g.Destroy())
        g.OnEvent("Close", (*) => g.Destroy())
        g.OnEvent("Escape", (*) => g.Destroy())

        g.Show("Center")
        edit.Focus()
        ; Select nothing by default so user can choose what to copy.
        try SendMessage(0x00B1, 0, 0, edit)  ; EM_SETSEL start=0 end=0
        WinWaitClose(g)
    }

    static OptInt(options, key, defaultValue) {
        if !IsObject(options) || !options.Has(key)
            return defaultValue
        try return Integer(options[key])
        catch
            return defaultValue
    }

    static OptStr(options, key, defaultValue) {
        if !IsObject(options) || !options.Has(key)
            return defaultValue
        val := Trim(String(options[key]))
        return val != "" ? val : defaultValue
    }
}
