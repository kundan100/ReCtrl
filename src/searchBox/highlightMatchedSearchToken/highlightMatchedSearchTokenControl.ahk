#Requires AutoHotkey v2

; Strip under suggestion list: match hint while typing, or blank-list hints (Enter / Ctrl+Enter).
; Config: ConfigAppSettings.CONTENT.HIGHLIGHT_MATCHED_TOKEN
class HighlightMatchedSearchTokenControl {
    hostGui := ""
    textCtrl := ""
    enabled := true
    marginTop := 2
    height := 20
    bgColor := "FFFF00"
    textColor := "000000"
    blankListEnabled := true
    blankRecentsText := "Enter → recent actions"
    blankMenuText := "Ctrl+Enter → full menu · Esc / Backspace goes up"

    __New(hostGui, x, y, w) {
        this.hostGui := hostGui
        this.ApplyFromAppSettings()
        hostGui.SetFont("s9", "Segoe UI")
        this.textCtrl := hostGui.Add("Text",
            "x" x " y" y " w" w " h" this.height
            " Hidden Background" this.bgColor " c" this.textColor
            " 0x200", "")
        this.textCtrl.SetFont("s9", "Segoe UI")
    }

    static Cfg() {
        return ConfigAppSettings.CONTENT.HIGHLIGHT_MATCHED_TOKEN
    }

    static IsEnabledByConfig() {
        try return ConfigAppSettings.IsShowFlagEnabled(
            ConfigAppSettings.CONTENT.HIGHLIGHT_MATCHED_TOKEN.SHOW, true)
        catch
            return true
    }

    static ColorToGui(color) {
        hex := StrUpper(Trim(String(color)))
        hex := RegExReplace(hex, "^0X", "")
        hex := RegExReplace(hex, "^#", "")
        return hex
    }

    ApplyFromAppSettings() {
        if !HighlightMatchedSearchTokenControl.IsEnabledByConfig() {
            this.enabled := false
            this.Clear()
            return
        }

        this.enabled := true
        try {
            cfg := HighlightMatchedSearchTokenControl.Cfg()
            this.marginTop := Integer(cfg.MARGIN_TOP)
            this.height := Integer(cfg.HEIGHT)
            this.bgColor := HighlightMatchedSearchTokenControl.ColorToGui(cfg.BG_COLOR)
            this.textColor := HighlightMatchedSearchTokenControl.ColorToGui(cfg.TEXT_COLOR)
            if cfg.HasOwnProp("BLANK_LIST") && IsObject(cfg.BLANK_LIST) {
                blank := cfg.BLANK_LIST
                this.blankListEnabled := ConfigAppSettings.IsShowFlagEnabled(blank.SHOW, true)
                if blank.HasOwnProp("RECENTS_TEXT") && Trim(String(blank.RECENTS_TEXT)) != ""
                    this.blankRecentsText := String(blank.RECENTS_TEXT)
                if blank.HasOwnProp("MENU_TEXT") && Trim(String(blank.MENU_TEXT)) != ""
                    this.blankMenuText := String(blank.MENU_TEXT)
            }
        } catch {
            ; keep previous / defaults
        }

        if !this.textCtrl
            return
        this.textCtrl.Opt("Background" this.bgColor)
        this.textCtrl.SetFont("c" this.textColor " s9", "Segoe UI")
    }

    ; Show "query  →  found in  'matchedToken'" for the selected action (typing mode).
    ShowFor(query, action) {
        if !this.enabled || !this.textCtrl {
            this.Clear()
            return false
        }
        query := Trim(query)
        if (query = "") || !IsObject(action) {
            this.Clear()
            return false
        }

        matchedToken := this.FindMatchedSearchToken(query, action)
        if (matchedToken = "") {
            this.Clear()
            return false
        }

        highlightedToken := this.FormatTokenWithBoldMatch(matchedToken, query)
        this.textCtrl.Value := query "  →  found in  '" highlightedToken "'"
        this.textCtrl.Visible := true
        return true
    }

    ; kind: "recents" (blank Enter) | "menu" (Ctrl+Enter / browse)
    ShowBlankListHint(kind := "recents") {
        if !this.enabled || !this.textCtrl || !this.blankListEnabled {
            this.Clear()
            return false
        }
        text := (StrLower(Trim(String(kind))) = "menu")
            ? this.blankMenuText
            : this.blankRecentsText
        text := Trim(text)
        if (text = "") {
            this.Clear()
            return false
        }
        this.textCtrl.Value := text
        this.textCtrl.Visible := true
        return true
    }

    FormatTokenWithBoldMatch(token, query) {
        pos := InStr(token, query, false)
        if !pos {
            return token
        }
        qLen := StrLen(query)
        before := SubStr(token, 1, pos - 1)
        matched := SubStr(token, pos, qLen)
        after := SubStr(token, pos + qLen)
        return before this.ToBoldUnicode(matched) after
    }

    ToBoldUnicode(text) {
        out := ""
        Loop Parse, text {
            code := Ord(A_LoopField)
            if (code >= Ord("A") && code <= Ord("Z"))
                out .= Chr(0x1D400 + (code - Ord("A")))
            else if (code >= Ord("a") && code <= Ord("z"))
                out .= Chr(0x1D41A + (code - Ord("a")))
            else if (code >= Ord("0") && code <= Ord("9"))
                out .= Chr(0x1D7CE + (code - Ord("0")))
            else
                out .= A_LoopField
        }
        return out
    }

    Clear() {
        if !this.textCtrl {
            return
        }
        this.textCtrl.Value := ""
        this.textCtrl.Visible := false
    }

    IsShowing() {
        return this.textCtrl && this.textCtrl.Visible
    }

    LayoutBelow(listX, listY, listW, listH) {
        if !this.textCtrl || !this.textCtrl.Visible {
            return
        }
        hintY := listY + listH + this.marginTop
        this.textCtrl.Move(listX, hintY, listW, this.height)
    }

    ; Reserve space only while the strip is actually visible.
    OccupiedHeight() {
        if !this.enabled || !this.IsShowing() {
            return 0
        }
        return this.marginTop + this.height
    }

    FindMatchedSearchToken(query, action) {
        q := StrLower(Trim(query))
        if (q = "") {
            return ""
        }

        label := action.Has("label") ? action["label"] : ""
        word := this.FindWordContaining(label, q)
        if (word != "") {
            return word
        }

        if action.Has("command") {
            command := String(action["command"])
            if InStr(StrLower(command), q) {
                word := this.FindWordContaining(command, q)
                return word != "" ? word : command
            }
        }

        if action.Has("keywords") {
            for kw in action["keywords"] {
                if InStr(StrLower(kw), q)
                    return kw
            }
        }
        return ""
    }

    FindWordContaining(text, queryLower) {
        Loop Parse, text, A_Space {
            word := Trim(A_LoopField)
            if (word = "")
                continue
            if InStr(StrLower(word), queryLower)
                return word
        }
        return ""
    }
}
