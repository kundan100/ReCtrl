#Requires AutoHotkey v2

; Yellow strip under suggestion list: shows which token matched the typed query.
; Config: searchConfig.HIGHLIGHT_MATCHED_SEARCH_TOKEN
class HighlightMatchedSearchTokenControl {
    static GAP := 2
    static HEIGHT := 20

    hostGui := ""
    textCtrl := ""
    enabled := true
    bgColor := "FFFF00"
    textColor := "000000"

    __New(hostGui, x, y, w) {
        this.hostGui := hostGui
        hostGui.SetFont("s9", "Segoe UI")
        this.textCtrl := hostGui.Add("Text",
            "x" x " y" y " w" w " h" HighlightMatchedSearchTokenControl.HEIGHT
            " Hidden Background" this.bgColor " c" this.textColor
            " 0x200", "")
        this.textCtrl.SetFont("s9", "Segoe UI")
    }

    static DefaultConfig() {
        return Map(
            "ENABLED", true,
            "BG_COLOR", "FFFF00",
            "TEXT_COLOR", "000000"
        )
    }

    ApplyConfig(config) {
        if !IsObject(config) {
            return
        }
        if config.Has("ENABLED")
            this.enabled := !!config["ENABLED"]
        if config.Has("BG_COLOR")
            this.bgColor := config["BG_COLOR"]
        if config.Has("TEXT_COLOR")
            this.textColor := config["TEXT_COLOR"]

        if !this.textCtrl {
            return
        }
        this.textCtrl.Opt("Background" this.bgColor)
        this.textCtrl.SetFont("c" this.textColor " s9", "Segoe UI")
        if !this.enabled {
            this.Clear()
        }
    }

    ; Show "query  →  in  matchedToken" for the selected action.
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

        ; Text control has no rich bold — bold only the matched slice via Unicode.
        highlightedToken := this.FormatTokenWithBoldMatch(matchedToken, query)
        this.textCtrl.Value := query "  →  found in  '" highlightedToken "'"
        this.textCtrl.Visible := true
        return true
    }

    ; e.g. query "bro" + token "browser" => "𝗯𝗿𝗼wser"
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

    LayoutBelow(listX, listY, listW, listH) {
        if !this.textCtrl || !this.textCtrl.Visible {
            return
        }
        hintY := listY + listH + HighlightMatchedSearchTokenControl.GAP
        this.textCtrl.Move(listX, hintY, listW, HighlightMatchedSearchTokenControl.HEIGHT)
    }

    ; Height reserved under the list while suggestions are open (0 if feature disabled).
    ; Always reserved when enabled — does not grow/shrink with show/clear of hint text.
    OccupiedHeight() {
        if !this.enabled {
            return 0
        }
        return HighlightMatchedSearchTokenControl.GAP + HighlightMatchedSearchTokenControl.HEIGHT
    }

    ; Prefer the word/keyword that contains the query (not the whole label).
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
