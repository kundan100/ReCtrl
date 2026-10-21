#Requires AutoHotkey v2

; Find and focus a browser tab by title (UIA tab strip, Ctrl+Tab fallback).
; Optional urlNeedle: confirm via UIA Value (document / omnibox) — no clipboard.
class BrowserTabs {
    static UIA_ControlTypePropertyId := 30003
    static UIA_TabItemControlTypeId := 50019
    static UIA_EditControlTypeId := 50004
    static UIA_DocumentControlTypeId := 50030
    static UIA_TreeScope_Descendants := 4
    static UIA_Pattern_SelectionItem := 10010
    static UIA_Pattern_Invoke := 10000
    static UIA_Pattern_Value := 10002

    ; Focus a tab whose title contains tabTitle.
    ; If urlNeedle is set, only accept a tab whose active URL matches (UIA read).
    ; Returns true if focused, false if not found.
    static FocusByTitle(tabTitle, browserName, primaryLabel := "", urlNeedle := "") {
        tabTitle := Trim(tabTitle)
        urlNeedle := Trim(urlNeedle)
        if (tabTitle = "")
            return false

        for hwnd in BrowserWindows.ListByBrowserAndLabel(browserName, primaryLabel) {
            try {
                title := WinGetTitle(hwnd)
            } catch {
                continue
            }

            ; Fast path: active tab title matches (and URL, when required).
            if InStr(title, tabTitle, false) {
                if (urlNeedle = "") {
                    BrowserWindows.Activate(hwnd)
                    return true
                }
                BrowserWindows.Activate(hwnd)
                Sleep(80)
                if BrowserTabs.UrlMatches(BrowserTabs.ReadActiveUrlViaUia(hwnd), urlNeedle)
                    return true
                ; Wrong env — keep scanning other tabs in this window.
            }

            uiaStatus := BrowserTabs.TryFocusTabViaUia(hwnd, tabTitle, urlNeedle)
            if (uiaStatus = 1)
                return true
            if (uiaStatus = 0)
                continue  ; Tabs listed; none matched in this window.

            ; UIA failed: Ctrl+Tab fallback only for title-only (URL confirm would be noisy).
            if (urlNeedle = "" && BrowserTabs.FocusTabByCycling(hwnd, tabTitle))
                return true
        }
        return false
    }

    ; Returns: 1 = focused match, 0 = tabs enumerated but no match, -1 = UIA failed.
    static TryFocusTabViaUia(hwnd, tabTitle, urlNeedle := "") {
        try {
            BrowserWindows.Activate(hwnd)

            tabs := BrowserTabs.FindAllByControlTypeFromHwnd(hwnd, BrowserTabs.UIA_TabItemControlTypeId)
            if (tabs = "")
                return -1
            if (tabs.Length = 0)
                return -1

            for tabEl in tabs {
                name := BrowserTabs.ElementName(tabEl)
                if !InStr(name, tabTitle, false)
                    continue
                if !BrowserTabs.SelectOrInvoke(tabEl)
                    continue

                if (urlNeedle = "") {
                    BrowserWindows.Activate(hwnd)
                    return 1
                }

                Sleep(120)
                if BrowserTabs.UrlMatches(BrowserTabs.ReadActiveUrlViaUia(hwnd), urlNeedle) {
                    BrowserWindows.Activate(hwnd)
                    return 1
                }
            }
            return 0
        } catch {
            return -1
        }
    }

    ; Read URL of the active tab via UIA Value (document / address bar). No clipboard.
    static ReadActiveUrlViaUia(hwnd) {
        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd)
            return ""

        try {
            uia := BrowserTabs.GetUia()
            ComCall(6, uia, "ptr", hwnd, "ptr*", &root := 0)
            if !root
                return ""
            rootEl := ComValue(0xD, root)

            url := BrowserTabs.FirstUrlFromControlType(uia, rootEl, BrowserTabs.UIA_DocumentControlTypeId)
            if (url != "")
                return url

            url := BrowserTabs.AddressBarUrlFromEdits(uia, rootEl)
            if (url != "")
                return url

            return BrowserTabs.FirstUrlFromControlType(uia, rootEl, BrowserTabs.UIA_EditControlTypeId)
        } catch {
            return ""
        }
    }

    static FirstUrlFromControlType(uia, rootEl, controlTypeId) {
        elems := BrowserTabs.FindAllByControlType(uia, rootEl, controlTypeId)
        if (elems = "")
            return ""
        for el in elems {
            val := BrowserTabs.ElementValue(el)
            if BrowserTabs.LooksLikeUrl(val)
                return Trim(val)
        }
        return ""
    }

    static AddressBarUrlFromEdits(uia, rootEl) {
        elems := BrowserTabs.FindAllByControlType(uia, rootEl, BrowserTabs.UIA_EditControlTypeId)
        if (elems = "")
            return ""
        for el in elems {
            name := BrowserTabs.ElementName(el)
            if !RegExMatch(name, "i)address|omnibox|search or type a (url|web)|search or enter")
                continue
            val := Trim(BrowserTabs.ElementValue(el))
            if (val != "")
                return val
        }
        return ""
    }

    static FindAllByControlTypeFromHwnd(hwnd, controlTypeId) {
        try {
            uia := BrowserTabs.GetUia()
            ComCall(6, uia, "ptr", hwnd, "ptr*", &root := 0)
            if !root
                return ""
            return BrowserTabs.FindAllByControlType(uia, ComValue(0xD, root), controlTypeId)
        } catch {
            return ""
        }
    }

    static FindAllByControlType(uia, rootEl, controlTypeId) {
        try {
            condVar := BrowserTabs.VariantInt(controlTypeId)
            ComCall(23, uia, "int", BrowserTabs.UIA_ControlTypePropertyId, "ptr", condVar, "ptr*", &cond := 0)
            if !cond
                return ""
            condObj := ComValue(0xD, cond)

            ComCall(6, rootEl, "int", BrowserTabs.UIA_TreeScope_Descendants, "ptr", condObj, "ptr*", &arr := 0)
            if !arr
                return ""
            arrObj := ComValue(0xD, arr)

            ComCall(3, arrObj, "int*", &len := 0)
            out := []
            loop len {
                ComCall(4, arrObj, "int", A_Index - 1, "ptr*", &el := 0)
                if el
                    out.Push(ComValue(0xD, el))
            }
            return out
        } catch {
            return ""
        }
    }

    static ElementValue(element) {
        if !element
            return ""
        try {
            ComCall(16, element, "int", BrowserTabs.UIA_Pattern_Value, "ptr*", &pat := 0)
            if !pat
                return ""
            patObj := ComValue(0xD, pat)
            ComCall(4, patObj, "ptr*", &valPtr := 0)  ; get_CurrentValue
            if !valPtr
                return ""
            val := StrGet(valPtr, "UTF-16")
            DllCall("oleaut32\SysFreeString", "ptr", valPtr)
            return val
        } catch {
            return ""
        }
    }

    static LooksLikeUrl(text) {
        t := Trim(text)
        if (t = "")
            return false
        if RegExMatch(t, "i)^https?://")
            return true
        if RegExMatch(t, "i)^[a-z0-9.-]+:\d{2,5}(/|$)")
            return true
        if InStr(t, "localhost")
            return true
        return false
    }

    static UrlMatches(actual, wanted) {
        a := StrLower(RTrim(Trim(actual), "/"))
        w := StrLower(RTrim(Trim(wanted), "/"))
        if (a = "" || w = "")
            return false
        return InStr(a, w) || InStr(w, a)
    }

    static GetUia() {
        static uia := 0
        if !uia
            uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        return uia
    }

    static VariantInt(value) {
        buf := Buffer(24, 0)
        NumPut("UShort", 3, buf, 0)  ; VT_I4
        NumPut("Int", Integer(value), buf, 8)
        return buf
    }

    static ElementName(element) {
        ComCall(23, element, "ptr*", &namePtr := 0)  ; get_CurrentName
        if !namePtr
            return ""
        name := StrGet(namePtr, "UTF-16")
        DllCall("oleaut32\SysFreeString", "ptr", namePtr)
        return name
    }

    static SelectOrInvoke(element) {
        ComCall(16, element, "int", BrowserTabs.UIA_Pattern_SelectionItem, "ptr*", &sel := 0)
        if sel {
            selObj := ComValue(0xD, sel)
            ComCall(3, selObj)  ; SelectionItem.Select
            return true
        }
        ComCall(16, element, "int", BrowserTabs.UIA_Pattern_Invoke, "ptr*", &inv := 0)
        if inv {
            invObj := ComValue(0xD, inv)
            ComCall(3, invObj)  ; Invoke
            return true
        }
        return false
    }

    static FocusTabByCycling(hwnd, tabTitle) {
        try {
            BrowserWindows.Activate(hwnd)
            startTitle := WinGetTitle(hwnd)
            if InStr(startTitle, tabTitle, false)
                return true

            loop 50 {
                SendInput("^{Tab}")
                Sleep(80)
                title := WinGetTitle(hwnd)
                if InStr(title, tabTitle, false)
                    return true
                if (title = startTitle)
                    break
            }
        } catch {
            return false
        }
        return false
    }
}
