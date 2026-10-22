#Requires AutoHotkey v2

; Low-level UIA helpers for login steps (find / type / click). No clipboard.
class BrowserLoginUia {
    static UIA_AutomationIdPropertyId := 30011
    static UIA_EditControlTypeId := 50004
    static UIA_ButtonControlTypeId := 50000
    static UIA_TreeScope_Descendants := 4
    static UIA_Pattern_Value := 10002
    static UIA_Pattern_Invoke := 10000

    ; fieldIdentifier: { type, key, value } — type: input|button; key: id|containsText|name
    ; Returns element or 0. Polls until waitMs_maxTimeForFieldToShowUp.
    static WaitFind(hwnd, fieldIdentifier, waitMs_maxTimeForFieldToShowUp := 3000) {
        if !(fieldIdentifier is Map)
            return 0
        deadline := A_TickCount + Max(0, Integer(waitMs_maxTimeForFieldToShowUp))
        loop {
            el := BrowserLoginUia.Find(hwnd, fieldIdentifier)
            if el
                return el
            if (A_TickCount >= deadline)
                return 0
            Sleep(200)
        }
    }

    static Find(hwnd, fieldIdentifier) {
        ctrlType := StrLower(Trim(String(fieldIdentifier.Has("type") ? fieldIdentifier["type"] : "")))
        key := StrLower(Trim(String(fieldIdentifier.Has("key") ? fieldIdentifier["key"] : "")))
        value := Trim(String(fieldIdentifier.Has("value") ? fieldIdentifier["value"] : ""))
        if (value = "")
            return 0

        if (key = "id")
            return BrowserLoginUia.FindByAutomationId(hwnd, value)

        if (ctrlType = "button") {
            if (key = "containstext" || key = "name")
                return BrowserLoginUia.FindButtonByText(hwnd, value, key = "name")
            return 0
        }

        ; input / edit
        if (key = "containstext" || key = "name")
            return BrowserLoginUia.FindEditByName(hwnd, value, key = "name")
        return 0
    }

    static FindByAutomationId(hwnd, automationId) {
        try {
            root := BrowserLoginUia.RootFromHwnd(hwnd)
            if !root
                return 0
            uia := BrowserTabs.GetUia()
            condVar := BrowserLoginUia.VariantBStr(automationId)
            ComCall(23, uia, "int", BrowserLoginUia.UIA_AutomationIdPropertyId, "ptr", condVar, "ptr*", &cond := 0)
            BrowserLoginUia.ClearVariantBStr(condVar)
            if !cond
                return 0
            condObj := ComValue(0xD, cond)
            ComCall(5, root, "int", BrowserLoginUia.UIA_TreeScope_Descendants, "ptr", condObj, "ptr*", &el := 0)
            return el ? ComValue(0xD, el) : 0
        } catch {
            return 0
        }
    }

    static FindEditByName(hwnd, nameNeedle, exact := false) {
        try {
            root := BrowserLoginUia.RootFromHwnd(hwnd)
            if !root
                return 0
            uia := BrowserTabs.GetUia()
            edits := BrowserTabs.FindAllByControlType(uia, root, BrowserLoginUia.UIA_EditControlTypeId)
            if (edits = "")
                return 0
            needle := StrLower(nameNeedle)
            for el in edits {
                aid := StrLower(BrowserLoginUia.ElementAutomationId(el))
                name := StrLower(BrowserTabs.ElementName(el))
                if exact {
                    if (aid = needle || name = needle)
                        return el
                } else if (aid = needle || name = needle || InStr(name, needle)) {
                    return el
                }
            }
            return 0
        } catch {
            return 0
        }
    }

    static FindButtonByText(hwnd, buttonText, exact := false) {
        try {
            root := BrowserLoginUia.RootFromHwnd(hwnd)
            if !root
                return 0
            uia := BrowserTabs.GetUia()
            buttons := BrowserTabs.FindAllByControlType(uia, root, BrowserLoginUia.UIA_ButtonControlTypeId)
            if (buttons = "")
                return 0
            for el in buttons {
                name := BrowserTabs.ElementName(el)
                if exact {
                    if (StrLower(name) = StrLower(buttonText))
                        return el
                } else if (StrLower(name) = StrLower(buttonText) || InStr(name, buttonText, false)) {
                    return el
                }
            }
            return 0
        } catch {
            return 0
        }
    }

    static SetEditValue(element, value) {
        if !element
            return false
        try {
            BrowserLoginUia.SetFocus(element)
            Sleep(80)
            SendInput("^a")
            Sleep(40)
            if (value != "")
                SendText(value)
            else
                SendInput("{Delete}")
            Sleep(60)
            return true
        } catch {
            try {
                ComCall(16, element, "int", BrowserLoginUia.UIA_Pattern_Value, "ptr*", &pat := 0)
                if !pat
                    return false
                patObj := ComValue(0xD, pat)
                bstr := DllCall("oleaut32\SysAllocString", "WStr", String(value), "ptr")
                try {
                    ComCall(3, patObj, "ptr", bstr)
                } finally {
                    DllCall("oleaut32\SysFreeString", "ptr", bstr)
                }
                return true
            } catch {
                return false
            }
        }
    }

    static Click(element) {
        if !element
            return false
        if BrowserTabs.SelectOrInvoke(element)
            return true
        try {
            ComCall(16, element, "int", BrowserLoginUia.UIA_Pattern_Invoke, "ptr*", &inv := 0)
            if !inv
                return false
            invObj := ComValue(0xD, inv)
            ComCall(3, invObj)
            return true
        } catch {
            return false
        }
    }

    static SetFocus(element) {
        try {
            ComCall(3, element)
            return true
        } catch {
            return false
        }
    }

    static RootFromHwnd(hwnd) {
        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd)
            return 0
        uia := BrowserTabs.GetUia()
        ComCall(6, uia, "ptr", hwnd, "ptr*", &root := 0)
        return root ? ComValue(0xD, root) : 0
    }

    static ElementAutomationId(element) {
        if !element
            return ""
        try {
            pv := Buffer(24, 0)
            ComCall(9, element, "int", BrowserLoginUia.UIA_AutomationIdPropertyId, "ptr", pv)
            vt := NumGet(pv, 0, "UShort")
            text := ""
            try {
                if (vt = 8 || vt = 31) {
                    p := NumGet(pv, 8, "Ptr")
                    if p
                        text := StrGet(p, "UTF-16")
                }
            } finally {
                DllCall("ole32\PropVariantClear", "Ptr", pv)
            }
            return Trim(text)
        } catch {
            return ""
        }
    }

    static VariantBStr(text) {
        buf := Buffer(24, 0)
        NumPut("UShort", 8, buf, 0)
        bstr := DllCall("oleaut32\SysAllocString", "WStr", String(text), "ptr")
        NumPut("Ptr", bstr, buf, 8)
        return buf
    }

    static ClearVariantBStr(buf) {
        try DllCall("ole32\PropVariantClear", "Ptr", buf)
    }
}
