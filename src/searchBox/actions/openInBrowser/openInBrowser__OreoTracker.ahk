#Requires AutoHotkey v2

; Open Oreo tracker in browser (actionType: openInBrowser__OreoTracker).
; 1) Search open tabs (UIA tab strip; Ctrl+Tab fallback) in the target browser/profile.
; 2) If a matching tab title is found → focus/select that tab.
; 3) Otherwise open FILE_PATH in that browser/profile.
class OpenInBrowser__OreoTracker {
    ; Tab title substring to match against each open tab's name.
    static TAB_TITLE := "Oreo__action_tracker.xlsx"
    ; Browser display name from BrowserActions.GuessBrowserName (e.g. "Google Chrome").
    static BROWSER_NAME := "Google Chrome"
    ; Primary label = profileDisplayName (signed-in email, or local profile name if unsigned).
    ; Blank = match any profile of BROWSER_NAME.
    static PRIMARY_LABEL := "kkundancybage2.com@gmail.com"
    ; Path/URL to open when no matching tab is found.
    static FILE_PATH := "https://zebra-my.sharepoint.com/:x:/r/personal/sc5394_zebra_com/Documents/Sync%20Oreo/Oreo__action_tracker.xlsx?d=w5f2cdd3ddb184770a587a8387bfc8e33&csf=1&web=1&e=yAQSMO"

    static UIA_ControlTypePropertyId := 30003
    static UIA_TabItemControlTypeId := 50019
    static UIA_TreeScope_Descendants := 4
    static UIA_Pattern_SelectionItem := 10010
    static UIA_Pattern_Invoke := 10000

    static Run(action := unset, ownerHwnd := 0) {
        try {
            if OpenInBrowser__OreoTracker.FindAndFocusMatchingTab()
                return Map("ok", true, "silent", true)

            OpenInBrowser__OreoTracker.OpenInTargetBrowser()
            return Map("ok", true, "silent", true)
        } catch as err {
            return Map(
                "ok", false,
                "title", ConfigApp.APP_NAME " — Oreo tracker",
                "message", err.Message
            )
        }
    }

    ; Walk Chrome windows for the target profile; match any open tab (not only the active one).
    static FindAndFocusMatchingTab() {
        tabTitle := OpenInBrowser__OreoTracker.TAB_TITLE
        if (tabTitle = "")
            return false

        for hwnd in OpenInBrowser__OreoTracker.ListCandidateWindows() {
            try {
                title := WinGetTitle(hwnd)
            } catch {
                continue
            }
            ; Fast path: active tab already matches.
            if InStr(title, tabTitle, false) {
                OpenInBrowser__OreoTracker.ActivateWindow(hwnd)
                return true
            }

            ; Prefer UIA: enumerate all TabItems and select by name.
            uiaStatus := OpenInBrowser__OreoTracker.TryFocusTabViaUia(hwnd, tabTitle)
            if (uiaStatus = 1)
                return true
            if (uiaStatus = 0)
                continue  ; Tabs were listed; none matched in this window.

            ; Fallback if UIA could not list tabs (accessibility unavailable, etc.).
            if OpenInBrowser__OreoTracker.FocusTabByCycling(hwnd, tabTitle)
                return true
        }
        return false
    }

    ; Chrome windows that match BROWSER_NAME + PRIMARY_LABEL.
    static ListCandidateWindows() {
        out := []
        for hwnd in WinGetList("ahk_exe chrome.exe") {
            if !DllCall("IsWindow", "Ptr", hwnd)
                continue
            try {
                exeName := WinGetProcessName(hwnd)
                processPath := WinGetProcessPath(hwnd)
                pid := WinGetPID(hwnd)
            } catch {
                continue
            }
            if (BrowserActions.GuessBrowserName(exeName, processPath) != OpenInBrowser__OreoTracker.BROWSER_NAME)
                continue
            if !OpenInBrowser__OreoTracker.WindowMatchesPrimaryLabel(hwnd, pid, exeName, processPath)
                continue
            out.Push(hwnd)
        }
        return out
    }

    static WindowMatchesPrimaryLabel(hwnd, pid, exeName, processPath) {
        wanted := Trim(OpenInBrowser__OreoTracker.PRIMARY_LABEL)
        if (wanted = "")
            return true

        profile := BrowserActions.CollectBrowserProfile(pid, exeName, processPath, hwnd)
        return (
            OpenInBrowser__OreoTracker.LabelEquals(profile["profileDisplayName"], wanted)
            || OpenInBrowser__OreoTracker.LabelEquals(profile["profileAccount"], wanted)
            || OpenInBrowser__OreoTracker.LabelEquals(profile["profileName"], wanted)
        )
    }

    static LabelEquals(actual, wanted) {
        return (actual != "" && StrLower(actual) = StrLower(wanted))
    }

    static ActivateWindow(hwnd) {
        try {
            if (WinGetMinMax(hwnd) = -1)
                WinRestore(hwnd)
        } catch {
            ; ignore
        }
        WinActivate("ahk_id " hwnd)
        try WinWaitActive("ahk_id " hwnd, , 2)
    }

    ; Returns: 1 = focused match, 0 = tabs enumerated but no match, -1 = UIA failed.
    static TryFocusTabViaUia(hwnd, tabTitle) {
        try {
            OpenInBrowser__OreoTracker.ActivateWindow(hwnd)

            uia := OpenInBrowser__OreoTracker.GetUia()
            ComCall(6, uia, "ptr", hwnd, "ptr*", &root := 0)  ; ElementFromHandle
            if !root
                return -1
            rootEl := ComValue(0xD, root)

            condVar := OpenInBrowser__OreoTracker.VariantInt(OpenInBrowser__OreoTracker.UIA_TabItemControlTypeId)
            ComCall(23, uia, "int", OpenInBrowser__OreoTracker.UIA_ControlTypePropertyId, "ptr", condVar, "ptr*", &cond := 0)
            if !cond
                return -1
            condObj := ComValue(0xD, cond)

            ComCall(6, rootEl, "int", OpenInBrowser__OreoTracker.UIA_TreeScope_Descendants, "ptr", condObj, "ptr*", &arr := 0)
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

                name := OpenInBrowser__OreoTracker.ElementName(tabEl)
                if !InStr(name, tabTitle, false)
                    continue

                if OpenInBrowser__OreoTracker.SelectOrInvoke(tabEl) {
                    OpenInBrowser__OreoTracker.ActivateWindow(hwnd)
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

    ; VARIANT VT_I4 for CreatePropertyCondition (x64 layout).
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
        ComCall(16, element, "int", OpenInBrowser__OreoTracker.UIA_Pattern_SelectionItem, "ptr*", &sel := 0)
        if sel {
            selObj := ComValue(0xD, sel)
            ComCall(3, selObj)  ; SelectionItem.Select
            return true
        }
        ComCall(16, element, "int", OpenInBrowser__OreoTracker.UIA_Pattern_Invoke, "ptr*", &inv := 0)
        if inv {
            invObj := ComValue(0xD, inv)
            ComCall(3, invObj)  ; Invoke
            return true
        }
        return false
    }

    ; Fallback: cycle tabs in one window and match WinGetTitle (active tab title).
    static FocusTabByCycling(hwnd, tabTitle) {
        try {
            OpenInBrowser__OreoTracker.ActivateWindow(hwnd)
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

    static OpenInTargetBrowser() {
        chromeExe := OpenInBrowser__OreoTracker.ResolveChromeExe()
        if (chromeExe = "")
            throw Error("Could not find Google Chrome (chrome.exe).")

        profileDir := OpenInBrowser__OreoTracker.ResolveProfileDirectory()
        url := OpenInBrowser__OreoTracker.FILE_PATH
        if (url = "")
            throw Error("FILE_PATH is empty; nothing to open.")

        if (profileDir != "")
            Run(Format('"{1}" --profile-directory="{2}" "{3}"', chromeExe, profileDir, url))
        else
            Run(Format('"{1}" "{2}"', chromeExe, url))
    }

    ; Resolve --profile-directory from PRIMARY_LABEL via Chrome Local State / Preferences.
    ; Blank PRIMARY_LABEL → omit profile switch (Chrome default behavior).
    static ResolveProfileDirectory() {
        wanted := Trim(OpenInBrowser__OreoTracker.PRIMARY_LABEL)
        if (wanted = "")
            return ""

        userDataDir := BrowserActions.DefaultUserDataDir("chrome.exe")
        if (userDataDir = "" || !DirExist(userDataDir))
            throw Error("Chrome User Data folder not found.")

        for profileDir in OpenInBrowser__OreoTracker.ListProfileDirectories(userDataDir) {
            profilePath := userDataDir "\" profileDir
            names := BrowserActions.ResolveProfileIdentity(userDataDir, profileDir, profilePath)
            displayName := names["signedIn"] ? names["account"] : names["profileName"]
            if (
                OpenInBrowser__OreoTracker.LabelEquals(displayName, wanted)
                || OpenInBrowser__OreoTracker.LabelEquals(names["account"], wanted)
                || OpenInBrowser__OreoTracker.LabelEquals(names["profileName"], wanted)
            ) {
                return profileDir
            }
        }

        throw Error(
            "No Chrome profile matches primary label:`n"
            OpenInBrowser__OreoTracker.PRIMARY_LABEL
        )
    }

    static ListProfileDirectories(userDataDir) {
        dirs := []
        if DirExist(userDataDir "\Default")
            dirs.Push("Default")
        loop files userDataDir "\Profile *", "D"
            dirs.Push(A_LoopFileName)
        return dirs
    }

    static ResolveChromeExe() {
        for hwnd in WinGetList("ahk_exe chrome.exe") {
            try {
                processPath := WinGetProcessPath(hwnd)
                if (processPath != "" && FileExist(processPath)
                    && BrowserActions.GuessBrowserName("chrome.exe", processPath) = OpenInBrowser__OreoTracker.BROWSER_NAME) {
                    return processPath
                }
            } catch {
                ; try next window
            }
        }

        candidates := [
            EnvGet("ProgramFiles") "\Google\Chrome\Application\chrome.exe",
            EnvGet("ProgramFiles(x86)") "\Google\Chrome\Application\chrome.exe",
            EnvGet("LOCALAPPDATA") "\Google\Chrome\Application\chrome.exe"
        ]
        for path in candidates {
            if (path != "" && FileExist(path))
                return path
        }
        return ""
    }
}
