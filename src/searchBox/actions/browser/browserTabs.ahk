#Requires AutoHotkey v2

; Find and focus a browser tab by title (UIA tab strip, Ctrl+Tab fallback).
class BrowserTabs {
    static UIA_ControlTypePropertyId := 30003
    static UIA_TabItemControlTypeId := 50019
    static UIA_TreeScope_Descendants := 4
    static UIA_Pattern_SelectionItem := 10010
    static UIA_Pattern_Invoke := 10000

    ; Focus a tab whose title contains tabTitle, in windows matching browserName/primaryLabel.
    ; Returns true if focused, false if not found.
    static FocusByTitle(tabTitle, browserName, primaryLabel := "") {
        tabTitle := Trim(tabTitle)
        if (tabTitle = "")
            return false

        for hwnd in BrowserWindows.ListByBrowserAndLabel(browserName, primaryLabel) {
            try {
                title := WinGetTitle(hwnd)
            } catch {
                continue
            }
            ; Fast path: active tab already matches.
            if InStr(title, tabTitle, false) {
                BrowserWindows.Activate(hwnd)
                return true
            }

            uiaStatus := BrowserTabs.TryFocusTabViaUia(hwnd, tabTitle)
            if (uiaStatus = 1)
                return true
            if (uiaStatus = 0)
                continue  ; Tabs listed; none matched in this window.

            if BrowserTabs.FocusTabByCycling(hwnd, tabTitle)
                return true
        }
        return false
    }

    ; Returns: 1 = focused match, 0 = tabs enumerated but no match, -1 = UIA failed.
    static TryFocusTabViaUia(hwnd, tabTitle) {
        try {
            BrowserWindows.Activate(hwnd)

            uia := BrowserTabs.GetUia()
            ComCall(6, uia, "ptr", hwnd, "ptr*", &root := 0)  ; ElementFromHandle
            if !root
                return -1
            rootEl := ComValue(0xD, root)

            condVar := BrowserTabs.VariantInt(BrowserTabs.UIA_TabItemControlTypeId)
            ComCall(23, uia, "int", BrowserTabs.UIA_ControlTypePropertyId, "ptr", condVar, "ptr*", &cond := 0)
            if !cond
                return -1
            condObj := ComValue(0xD, cond)

            ComCall(6, rootEl, "int", BrowserTabs.UIA_TreeScope_Descendants, "ptr", condObj, "ptr*", &arr := 0)
            if !arr
                return -1
            arrObj := ComValue(0xD, arr)

            ComCall(3, arrObj, "int*", &len := 0)
            if (len <= 0)
                return -1

            loop len {
                ComCall(4, arrObj, "int", A_Index - 1, "ptr*", &tab := 0)
                if !tab
                    continue
                tabEl := ComValue(0xD, tab)

                name := BrowserTabs.ElementName(tabEl)
                if !InStr(name, tabTitle, false)
                    continue

                if BrowserTabs.SelectOrInvoke(tabEl) {
                    BrowserWindows.Activate(hwnd)
                    return 1
                }
            }
            return 0
        } catch {
            return -1
        }
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
