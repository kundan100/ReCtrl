#Requires AutoHotkey v2

; Minimal JSON → Array/Map parser for menu config (objects become Map).
; Note: In AHK v2, '"'/`"'` patterns are easy to get wrong — use Chr(34) for double quotes.
class JsonParse {
    static DQ := Chr(34)      ; "
    static BS := Chr(92)      ; \

    static Parse(text) {
        parser := JsonParse(text)
        return parser.ParseValue()
    }

    text := ""
    pos := 1
    len := 0

    __New(text) {
        this.text := String(text)
        this.len := StrLen(this.text)
        this.pos := 1
    }

    ParseValue() {
        this.SkipWs()
        ch := this.Peek()
        if (ch = "{")
            return this.ParseObject()
        if (ch = "[")
            return this.ParseArray()
        if (ch = JsonParse.DQ)
            return this.ParseString()
        if (ch = "t" || ch = "f")
            return this.ParseBool()
        if (ch = "n")
            return this.ParseNull()
        if (ch = "-" || this.IsDigit(ch))
            return this.ParseNumber()
        throw Error("Invalid JSON at position " this.pos)
    }

    ParseObject() {
        this.Expect("{")
        obj := Map()
        this.SkipWs()
        if (this.Peek() = "}") {
            this.Advance(1)
            return obj
        }
        loop {
            this.SkipWs()
            key := this.ParseString()
            this.SkipWs()
            this.Expect(":")
            value := this.ParseValue()
            obj[key] := value
            this.SkipWs()
            ch := this.Peek()
            if (ch = "}") {
                this.Advance(1)
                return obj
            }
            this.Expect(",")
        }
    }

    ParseArray() {
        this.Expect("[")
        arr := []
        this.SkipWs()
        if (this.Peek() = "]") {
            this.Advance(1)
            return arr
        }
        loop {
            arr.Push(this.ParseValue())
            this.SkipWs()
            ch := this.Peek()
            if (ch = "]") {
                this.Advance(1)
                return arr
            }
            this.Expect(",")
        }
    }

    ParseString() {
        this.Expect(JsonParse.DQ)
        out := ""
        while (this.pos <= this.len) {
            ch := this.Peek()
            this.Advance(1)
            if (ch = JsonParse.DQ)
                return out
            if (ch = JsonParse.BS) {
                esc := this.Peek()
                this.Advance(1)
                if (esc = JsonParse.DQ || esc = JsonParse.BS || esc = "/") {
                    out .= esc
                } else if (esc = "b") {
                    out .= "`b"
                } else if (esc = "f") {
                    out .= "`f"
                } else if (esc = "n") {
                    out .= "`n"
                } else if (esc = "r") {
                    out .= "`r"
                } else if (esc = "t") {
                    out .= "`t"
                } else if (esc = "u") {
                    hex := SubStr(this.text, this.pos, 4)
                    this.Advance(4)
                    out .= Chr(Integer("0x" hex))
                } else {
                    throw Error("Invalid escape at position " this.pos)
                }
            } else {
                out .= ch
            }
        }
        throw Error("Unterminated string")
    }

    ParseNumber() {
        start := this.pos
        if (this.Peek() = "-")
            this.Advance(1)
        while (this.pos <= this.len) {
            ch := this.Peek()
            if !(this.IsDigit(ch) || ch = "." || ch = "e" || ch = "E" || ch = "+" || ch = "-")
                break
            this.Advance(1)
        }
        numText := SubStr(this.text, start, this.pos - start)
        if (numText = "" || numText = "-")
            throw Error("Invalid number at position " start)
        return Number(numText)
    }

    ParseBool() {
        if (SubStr(this.text, this.pos, 4) = "true") {
            this.Advance(4)
            return true
        }
        if (SubStr(this.text, this.pos, 5) = "false") {
            this.Advance(5)
            return false
        }
        throw Error("Invalid boolean at position " this.pos)
    }

    ParseNull() {
        if (SubStr(this.text, this.pos, 4) = "null") {
            this.Advance(4)
            return ""
        }
        throw Error("Invalid null at position " this.pos)
    }

    SkipWs() {
        while (this.pos <= this.len) {
            ch := this.Peek()
            if (ch = " " || ch = "`t" || ch = "`n" || ch = "`r")
                this.Advance(1)
            else
                break
        }
    }

    Peek() {
        if (this.pos > this.len)
            return ""
        return SubStr(this.text, this.pos, 1)
    }

    Advance(n) {
        this.pos := this.pos + Integer(n)
    }

    Expect(ch) {
        this.SkipWs()
        if (this.Peek() != ch)
            throw Error("Expected '" ch "' at position " this.pos)
        this.Advance(1)
    }

    IsDigit(ch) {
        if (ch = "")
            return false
        code := Ord(ch)
        return code >= 48 && code <= 57
    }
}
