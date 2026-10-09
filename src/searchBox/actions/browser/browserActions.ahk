#Requires AutoHotkey v2

; All browser-related search actions are handled here (actionType: browserActions).
class BrowserActions {
    static Run(action, ownerHwnd := 0) {
        ; Currently one browser action; extend with action["id"] branches as needed.
        BrowserActions.ShowBrowserTip(ownerHwnd)
    }

    static ShowBrowserTip(ownerHwnd := 0) {
        ; Always bind to the topmost *browser* under ReCtrl (avoids stale/non-browser context).
        if !(ownerHwnd && AppContext.CaptureBrowserUnder(ownerHwnd))
            AppContext.RefreshUnderlying(ownerHwnd)

        details := BrowserActions.CollectBrowserDetails(ownerHwnd)
        text := BrowserActions.FormatBrowserDetails(details)
        BrowserActions.ShowOwnedMessage(text, ConfigApp.APP_NAME " — Browser", ownerHwnd)
    }

    ; Gather all readable details about the current browser context window.
    static CollectBrowserDetails(restoreHwnd := 0) {
        info := Map(
            "ok", false,
            "kind", AppContext.GetCurrentKind(),
            "contextEnabled", AppContext.IsEnabled()
        )

        if !IsObject(AppContext.last) {
            info["error"] := "No browser context captured."
            return info
        }

        hwnd := AppContext.last.Has("hwnd") ? AppContext.last["hwnd"] : 0
        info["hwnd"] := hwnd
        info["exe"] := AppContext.last.Has("exe") ? AppContext.last["exe"] : ""
        info["title"] := AppContext.last.Has("title") ? AppContext.last["title"] : ""
        info["class"] := AppContext.last.Has("class") ? AppContext.last["class"] : ""
        info["kind"] := AppContext.last.Has("kind") ? AppContext.last["kind"] : ""

        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd) {
            info["error"] := "Browser window handle is no longer valid."
            info["windowValid"] := false
            return info
        }

        info["windowValid"] := true
        info["ok"] := true

        try {
            info["pid"] := WinGetPID(hwnd)
        } catch {
            info["pid"] := ""
        }

        try {
            info["processPath"] := WinGetProcessPath(hwnd)
        } catch {
            info["processPath"] := ""
        }

        try {
            info["minMax"] := WinGetMinMax(hwnd)  ; -1 minimized, 0 normal, 1 maximized
        } catch {
            info["minMax"] := ""
        }

        try {
            info["transparent"] := WinGetTransparent(hwnd)
        } catch {
            info["transparent"] := ""
        }

        try {
            info["style"] := Format("0x{:08X}", WinGetStyle(hwnd))
        } catch {
            info["style"] := ""
        }

        try {
            info["exStyle"] := Format("0x{:08X}", WinGetExStyle(hwnd))
        } catch {
            info["exStyle"] := ""
        }

        try {
            info["isVisible"] := !!DllCall("IsWindowVisible", "Ptr", hwnd)
        } catch {
            info["isVisible"] := ""
        }

        try {
            info["isMinimized"] := !!DllCall("IsIconic", "Ptr", hwnd)
        } catch {
            info["isMinimized"] := ""
        }

        try {
            info["isZoomed"] := !!DllCall("IsZoomed", "Ptr", hwnd)
        } catch {
            info["isZoomed"] := ""
        }

        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            info["x"] := wx
            info["y"] := wy
            info["width"] := ww
            info["height"] := wh
        } catch {
            info["x"] := ""
            info["y"] := ""
            info["width"] := ""
            info["height"] := ""
        }

        try {
            WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
            info["clientX"] := cx
            info["clientY"] := cy
            info["clientWidth"] := cw
            info["clientHeight"] := ch
        } catch {
            info["clientX"] := ""
            info["clientY"] := ""
            info["clientWidth"] := ""
            info["clientHeight"] := ""
        }

        try {
            info["controlCount"] := WinGetControlsHwnd(hwnd).Length
        } catch {
            info["controlCount"] := ""
        }

        try {
            focused := ControlGetFocus("ahk_id " hwnd)
            info["activeControl"] := focused ? focused : ""
        } catch {
            info["activeControl"] := ""
        }

        ; Live re-read title/class/exe in case they changed since capture.
        try {
            info["titleLive"] := WinGetTitle(hwnd)
        } catch {
            info["titleLive"] := info["title"]
        }

        try {
            info["classLive"] := WinGetClass(hwnd)
        } catch {
            info["classLive"] := info["class"]
        }

        try {
            info["exeLive"] := WinGetProcessName(hwnd)
        } catch {
            info["exeLive"] := info["exe"]
        }

        try {
            info["minMaxLabel"] := BrowserActions.MinMaxLabel(info["minMax"])
        } catch {
            info["minMaxLabel"] := ""
        }

        exeForProfile := info["exeLive"] != "" ? info["exeLive"] : info["exe"]
        pathForProfile := info.Has("processPath") ? info["processPath"] : ""
        info["browserName"] := BrowserActions.GuessBrowserName(exeForProfile, pathForProfile)

        ; Chromium profile: prefer per-window AppUserModel props (multi-profile safe),
        ; then process tree. PID alone is unreliable across Chrome profiles.
        profileInfo := BrowserActions.CollectBrowserProfile(info["pid"], exeForProfile, pathForProfile, hwnd)
        info["profileDirectory"] := profileInfo["profileDirectory"]
        info["profileName"] := profileInfo["profileName"]
        info["profileAccount"] := profileInfo["profileAccount"]
        info["profileSignedIn"] := profileInfo["profileSignedIn"]
        info["profileDisplayName"] := profileInfo["profileDisplayName"]
        info["profileGaiaName"] := profileInfo["profileGaiaName"]
        info["profileUserName"] := profileInfo["profileUserName"]
        info["userDataDir"] := profileInfo["userDataDir"]
        info["profilePath"] := profileInfo["profilePath"]
        info["profileCommandLine"] := profileInfo["commandLine"]
        info["profileMainPid"] := profileInfo["mainPid"]
        info["profileSource"] := profileInfo["source"]
        info["profileAppId"] := profileInfo["appId"]
        info["profileNote"] := profileInfo["note"]

        ; URL: browsers do not expose this via WinGet/UIA reliably.
        ; Confirmed simple method: focus address bar (Ctrl+L) and copy (Ctrl+C).
        urlInfo := BrowserActions.CollectBrowserUrl(hwnd, restoreHwnd)
        info["url"] := urlInfo["url"]
        info["urlSource"] := urlInfo["source"]
        info["urlNote"] := urlInfo["note"]

        return info
    }

    ; Read profile for this HWND:
    ; 1) Window AppUserModel RelaunchCommand / ID (Chrome sets these per profile window)
    ; 2) Main process command line for this window's PID tree
    ; 3) Signed-in account from Local State / Preferences for that profile folder
    static CollectBrowserProfile(pid, exeName, processPath := "", hwnd := 0) {
        out := Map(
            "commandLine", "",
            "mainPid", pid,
            "profileDirectory", "",
            "userDataDir", "",
            "profileName", "",
            "profileAccount", "",
            "profileSignedIn", false,
            "profileDisplayName", "",
            "profileGaiaName", "",
            "profileUserName", "",
            "profilePath", "",
            "source", "",
            "appId", "",
            "note", ""
        )

        profileDir := ""
        userDataDir := ""
        source := ""

        ; Per-window props beat process-tree guessing when several profiles are open.
        winProps := BrowserActions.GetWindowAppUserModelProps(hwnd)
        out["appId"] := winProps["appId"]
        if (winProps["relaunchCommand"] != "") {
            profileDir := BrowserActions.ParseChromiumSwitch(winProps["relaunchCommand"], "profile-directory")
            userDataDir := BrowserActions.ParseChromiumSwitch(winProps["relaunchCommand"], "user-data-dir")
            out["commandLine"] := winProps["relaunchCommand"]
            if (profileDir != "" || userDataDir != "")
                source := "window-relaunch-command"
        }

        procInfo := BrowserActions.ResolveBrowserMainProcess(pid, exeName)
        out["mainPid"] := procInfo["pid"]
        procCmd := procInfo["commandLine"]
        if (out["commandLine"] = "" && procCmd != "")
            out["commandLine"] := procCmd

        if (profileDir = "" && procCmd != "") {
            profileDir := BrowserActions.ParseChromiumSwitch(procCmd, "profile-directory")
            if (userDataDir = "")
                userDataDir := BrowserActions.ParseChromiumSwitch(procCmd, "user-data-dir")
            if (profileDir != "")
                source := "process-command-line"
        }

        if (userDataDir = "")
            userDataDir := BrowserActions.ResolveUserDataDir(exeName, processPath)

        ; AppUserModelID encodes profile folder for non-Default profiles (e.g. ...UserData.Profile1).
        if (profileDir = "" && winProps["appId"] != "") {
            fromAppId := BrowserActions.ResolveProfileDirFromAppId(userDataDir, winProps["appId"])
            if (fromAppId != "") {
                profileDir := fromAppId
                source := "window-app-user-model-id"
            }
        }

        ; Missing --profile-directory / no AUMID suffix ⇒ Default profile.
        if (profileDir = "") {
            profileDir := "Default"
            if (source = "")
                source := (procCmd != "" ? "process-default" : "fallback-default")
        }
        if (source = "")
            source := "unknown"

        if (procCmd = "" && winProps["relaunchCommand"] = "")
            out["note"] := "Could not read window relaunch command or process command line."

        out["source"] := source
        out["profileDirectory"] := profileDir
        out["userDataDir"] := userDataDir
        profilePath := ""
        if (userDataDir != "" && profileDir != "") {
            profilePath := userDataDir "\" profileDir
            out["profilePath"] := profilePath
        }

        names := BrowserActions.ResolveProfileIdentity(userDataDir, profileDir, profilePath)
        out["profileName"] := names["profileName"]
        out["profileAccount"] := names["account"]
        out["profileSignedIn"] := names["signedIn"]
        out["profileGaiaName"] := names["gaiaName"]
        out["profileUserName"] := names["userName"]
        out["profileDisplayName"] := names["signedIn"] ? names["account"] : names["profileName"]

        if (out["profileDisplayName"] = "" && profileDir != "") {
            extra := "Profile folder known; name/account not found in Local State/Preferences."
            out["note"] := out["note"] != "" ? out["note"] " " extra : extra
        }

        return out
    }

    ; Chrome sets System.AppUserModel.ID + RelaunchCommand on each browser HWND (per profile).
    static GetWindowAppUserModelProps(hwnd) {
        out := Map("appId", "", "relaunchCommand", "")
        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd)
            return out

        iid := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString", "WStr", "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}", "Ptr", iid, "Int")
            return out

        store := 0
        hr := DllCall("shell32\SHGetPropertyStoreForWindow", "Ptr", hwnd, "Ptr", iid, "Ptr*", &store, "Int")
        if (hr != 0 || !store)
            return out

        try {
            out["appId"] := BrowserActions.PropertyStoreGetString(store, BrowserActions.PKEY_AppUserModel(5))
            out["relaunchCommand"] := BrowserActions.PropertyStoreGetString(store, BrowserActions.PKEY_AppUserModel(2))
        } finally {
            try ComCall(2, store)  ; IUnknown::Release
        }
        return out
    }

    ; PKEY_AppUserModel_* : fmtid {9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}, pid = property id
    ; 2 = RelaunchCommand, 5 = ID
    static PKEY_AppUserModel(propId) {
        buf := Buffer(20, 0)
        NumPut("UInt", 0x9F4C2855, buf, 0)
        NumPut("UShort", 0x9F79, buf, 4)
        NumPut("UShort", 0x4B39, buf, 6)
        NumPut("UChar", 0xA8, buf, 8)
        NumPut("UChar", 0xD0, buf, 9)
        NumPut("UChar", 0xE1, buf, 10)
        NumPut("UChar", 0xD4, buf, 11)
        NumPut("UChar", 0x2D, buf, 12)
        NumPut("UChar", 0xE1, buf, 13)
        NumPut("UChar", 0xD5, buf, 14)
        NumPut("UChar", 0xF3, buf, 15)
        NumPut("UInt", Integer(propId), buf, 16)
        return buf
    }

    static PropertyStoreGetString(store, pkey) {
        if !store
            return ""
        pv := Buffer(24, 0)
        try {
            ComCall(5, store, "Ptr", pkey, "Ptr", pv)  ; IPropertyStore::GetValue
        } catch {
            return ""
        }
        vt := NumGet(pv, 0, "UShort")
        text := ""
        try {
            if (vt = 31 || vt = 8) {  ; VT_LPWSTR / VT_BSTR
                p := NumGet(pv, 8, "Ptr")
                if p
                    text := StrGet(p, "UTF-16")
            }
        } finally {
            DllCall("ole32\PropVariantClear", "Ptr", pv)
        }
        return Trim(text)
    }

    ; Map Chrome AUMID suffix (UserData.Profile1) back to folder name ("Profile 1").
    static ResolveProfileDirFromAppId(userDataDir, appId) {
        if (appId = "" || userDataDir = "")
            return ""
        if !DirExist(userDataDir)
            return ""

        userDataBase := BrowserActions.SanitizeAumidPart(BrowserActions.FileBaseName(userDataDir))
        if (userDataBase = "")
            return ""

        ; Default profile omits the profile_id suffix in Chrome's AUMID.
        ; If appId does not contain UserData.<something>, treat as Default.
        needleRoot := "." userDataBase "."
        if !InStr(appId, needleRoot) && !RegExMatch(appId, "i)\." userDataBase "$")
            return "Default"

        bestDir := ""
        bestLen := 0
        loop files userDataDir "\*", "D" {
            folder := A_LoopFileName
            if (folder = "" || folder = "System Profile")
                continue
            if !FileExist(userDataDir "\" folder "\Preferences")
                continue
            suffix := userDataBase "." BrowserActions.SanitizeAumidPart(folder)
            if (suffix = userDataBase ".")
                continue
            if InStr(appId, suffix) && StrLen(suffix) > bestLen {
                bestDir := folder
                bestLen := StrLen(suffix)
            }
        }
        return bestDir
    }

    static SanitizeAumidPart(text) {
        return RegExReplace(String(text), "[^A-Za-z0-9.]", "")
    }

    static FileBaseName(path) {
        p := RTrim(StrReplace(String(path), "/", "\"), "\")
        SplitPath(p, &name)
        return name != "" ? name : p
    }

    ; Walk this window's process tree to the main browser process (no --type=).
    ; Child/renderer PIDs often lack --profile-directory; the main process has it per open profile.
    static ResolveBrowserMainProcess(pid, exeName := "") {
        pid := Integer(pid)
        if !pid
            return Map("pid", 0, "commandLine", "")

        if (exeName = "")
            exeName := BrowserActions.GetProcessName(pid)
        if (exeName = "")
            return Map("pid", pid, "commandLine", BrowserActions.GetProcessCommandLine(pid))

        parentOf := Map()
        cmdOf := Map()
        try {
            ; Escape single quotes for WMI.
            safeName := StrReplace(exeName, "'", "\'")
            query := "SELECT ProcessId, ParentProcessId, CommandLine FROM Win32_Process WHERE Name='" safeName "'"
            for proc in ComObjGet("winmgmts:").ExecQuery(query) {
                p := Integer(proc.ProcessId)
                parentOf[p] := Integer(proc.ParentProcessId)
                cmdOf[p] := (proc.CommandLine != "") ? String(proc.CommandLine) : ""
            }
        } catch {
            ; Fall through to single-PID queries below.
        }

        if !cmdOf.Has(pid) {
            cmd := BrowserActions.GetProcessCommandLine(pid)
            if BrowserActions.IsBrowserMainCommandLine(cmd)
                return Map("pid", pid, "commandLine", cmd)
            parentPid := BrowserActions.GetParentProcessId(pid)
            if parentPid {
                parentCmd := BrowserActions.GetProcessCommandLine(parentPid)
                if BrowserActions.IsBrowserMainCommandLine(parentCmd)
                    return Map("pid", parentPid, "commandLine", parentCmd)
            }
            return Map("pid", pid, "commandLine", cmd)
        }

        bestWithProfile := Map("pid", 0, "commandLine", "")
        current := pid
        seen := Map()
        loop 12 {
            if !current || seen.Has(current)
                break
            seen[current] := true
            cmd := cmdOf.Has(current) ? cmdOf[current] : ""
            if (cmd != "") {
                if BrowserActions.IsBrowserMainCommandLine(cmd)
                    return Map("pid", current, "commandLine", cmd)
                if (bestWithProfile["pid"] = 0 && BrowserActions.ParseChromiumSwitch(cmd, "profile-directory") != "")
                    bestWithProfile := Map("pid", current, "commandLine", cmd)
            }
            if !parentOf.Has(current)
                break
            next := parentOf[current]
            if (next = 0 || next = current)
                break
            current := next
        }

        if bestWithProfile["pid"]
            return bestWithProfile
        return Map("pid", pid, "commandLine", cmdOf.Has(pid) ? cmdOf[pid] : "")
    }

    static GetProcessName(pid) {
        if (pid = "" || pid = 0)
            return ""
        try {
            query := "SELECT Name FROM Win32_Process WHERE ProcessId=" Integer(pid)
            for proc in ComObjGet("winmgmts:").ExecQuery(query) {
                return (proc.Name != "") ? String(proc.Name) : ""
            }
        } catch {
            return ""
        }
        return ""
    }

    static IsBrowserMainCommandLine(commandLine) {
        if (commandLine = "")
            return false
        ; Renderer/GPU/utility processes have --type=... and usually lack profile identity.
        if RegExMatch(commandLine, "i)--type=")
            return false
        return true
    }

    static GetParentProcessId(pid) {
        if (pid = "" || pid = 0)
            return 0
        try {
            query := "SELECT ParentProcessId FROM Win32_Process WHERE ProcessId=" Integer(pid)
            for proc in ComObjGet("winmgmts:").ExecQuery(query) {
                return Integer(proc.ParentProcessId)
            }
        } catch {
            return 0
        }
        return 0
    }

    static GetProcessCommandLine(pid) {
        if (pid = "" || pid = 0)
            return ""
        try {
            query := "SELECT CommandLine FROM Win32_Process WHERE ProcessId=" Integer(pid)
            for proc in ComObjGet("winmgmts:").ExecQuery(query) {
                cmd := proc.CommandLine
                return (cmd != "") ? String(cmd) : ""
            }
        } catch {
            return ""
        }
        return ""
    }

    static ParseChromiumSwitch(commandLine, switchName) {
        if (commandLine = "" || switchName = "")
            return ""
        ; Chrome often uses unquoted values with spaces:
        ;   --profile-directory=Profile 1
        ; Quoted form is also common:
        ;   --profile-directory="Profile 1"
        ; \S+ was wrong — it stopped at the first space ("Profile" only).
        pattern := "i)--" switchName "=(?:`"([^`"]+)`"|(.+?)(?=\s+--|$))"
        if RegExMatch(commandLine, pattern, &m) {
            if (m[1] != "")
                return Trim(m[1])
            if (m[2] != "")
                return Trim(m[2])
        }
        return ""
    }

    ; Canary/Beta/Dev/Stable all use chrome.exe — distinguish by install folder.
    static ResolveUserDataDir(exeName, processPath := "") {
        fromPath := BrowserActions.UserDataDirFromProcessPath(processPath)
        if (fromPath != "")
            return fromPath
        return BrowserActions.DefaultUserDataDir(exeName)
    }

    static UserDataDirFromProcessPath(processPath) {
        if (processPath = "")
            return ""
        path := StrReplace(processPath, "/", "\")
        localApp := EnvGet("LOCALAPPDATA")
        if (localApp = "")
            return ""

        ; ...\Google\Chrome SxS\Application\chrome.exe → ...\Google\Chrome SxS\User Data
        if InStr(path, "\Google\Chrome SxS\", false)
            return localApp "\Google\Chrome SxS\User Data"
        if InStr(path, "\Google\Chrome Beta\", false)
            return localApp "\Google\Chrome Beta\User Data"
        if InStr(path, "\Google\Chrome Dev\", false)
            return localApp "\Google\Chrome Dev\User Data"
        if InStr(path, "\Google\Chrome\", false)
            return localApp "\Google\Chrome\User Data"

        if InStr(path, "\Microsoft\Edge SxS\", false)
            return localApp "\Microsoft\Edge SxS\User Data"
        if InStr(path, "\Microsoft\Edge Beta\", false)
            return localApp "\Microsoft\Edge Beta\User Data"
        if InStr(path, "\Microsoft\Edge Dev\", false)
            return localApp "\Microsoft\Edge Dev\User Data"
        if InStr(path, "\Microsoft\Edge\", false)
            return localApp "\Microsoft\Edge\User Data"

        if InStr(path, "\BraveSoftware\Brave-Browser\", false)
            return localApp "\BraveSoftware\Brave-Browser\User Data"

        ; Generic Chromium layout: <Product>\Application\app.exe → <Product>\User Data
        if RegExMatch(path, "i)^(.+)\\Application\\[^\\]+$", &m) {
            candidate := m[1] "\User Data"
            if DirExist(candidate)
                return candidate
        }
        return ""
    }

    static DefaultUserDataDir(exeName) {
        localApp := EnvGet("LOCALAPPDATA")
        if (localApp = "")
            return ""
        switch StrLower(exeName) {
            case "chrome.exe":
                return localApp "\Google\Chrome\User Data"
            case "msedge.exe":
                return localApp "\Microsoft\Edge\User Data"
            case "brave.exe":
                return localApp "\BraveSoftware\Brave-Browser\User Data"
            case "vivaldi.exe":
                return localApp "\Vivaldi\User Data"
            case "opera.exe":
                return localApp "\Opera Software\Opera Stable"
            default:
                return ""
        }
    }

    ; Identity for one profile folder:
    ; - profileName = local profile name (always, when available)
    ; - account = signed-in Google account for *this* profile only
    ; Prefer Local State info_cache.user_name (scoped to profile key) over Preferences,
    ; because Preferences can contain many emails (secondary accounts, history, etc.).
    static ResolveProfileIdentity(userDataDir, profileDirectory, profilePath := "") {
        out := Map(
            "profileName", "",
            "account", "",
            "signedIn", false,
            "gaiaName", "",
            "userName", ""
        )
        if (userDataDir = "" || profileDirectory = "")
            return out

        localState := BrowserActions.ReadLocalStateProfileFields(userDataDir, profileDirectory)
        prefs := BrowserActions.ReadProfilePreferencesFields(profilePath)

        profileName := localState["name"]
        if (profileName = "" && prefs["profileName"] != "")
            profileName := prefs["profileName"]

        gaia := localState["gaiaName"]
        userName := localState["userName"]

        out["profileName"] := profileName
        out["gaiaName"] := gaia
        out["userName"] := userName

        ; Account priority: Local State user_name → Preferences account_info → gaia_name.
        account := ""
        if BrowserActions.LooksLikeEmail(userName)
            account := userName
        else if BrowserActions.LooksLikeEmail(prefs["email"])
            account := prefs["email"]
        else if BrowserActions.LooksLikeEmail(prefs["lastUsername"])
            account := prefs["lastUsername"]
        else if BrowserActions.LooksLikeEmail(gaia)
            account := gaia
        else if (userName != "")
            account := userName
        else if (gaia != "")
            account := gaia

        out["account"] := account
        out["signedIn"] := (account != "")
        return out
    }

    static ReadLocalStateProfileFields(userDataDir, profileDirectory) {
        out := Map("name", "", "gaiaName", "", "userName", "")
        localStatePath := userDataDir "\Local State"
        if !FileExist(localStatePath)
            return out
        try {
            text := FileRead(localStatePath, "UTF-8")
        } catch {
            return out
        }

        cache := text
        if RegExMatch(text, "s)`"info_cache`"\s*:\s*(\{)", &cacheStart) {
            cache := SubStr(text, cacheStart.Pos(1))
        }

        esc := RegExReplace(profileDirectory, "[\.\*\+\?\^\$\{\}\(\)\|\[\]\\]", "\$0")
        if !RegExMatch(cache, "s)`"" esc "`"\s*:\s*(\{)", &blockStart)
            return out

        chunk := SubStr(cache, blockStart.Pos(1), 5000)
        if RegExMatch(chunk, "`"name`"\s*:\s*`"([^`"]*)`"", &m)
            out["name"] := m[1]
        if RegExMatch(chunk, "`"gaia_name`"\s*:\s*`"([^`"]*)`"", &m)
            out["gaiaName"] := m[1]
        if RegExMatch(chunk, "`"user_name`"\s*:\s*`"([^`"]*)`"", &m)
            out["userName"] := m[1]
        return out
    }

    static ReadProfilePreferencesFields(profilePath) {
        out := Map("profileName", "", "email", "", "lastUsername", "")
        if (profilePath = "")
            return out
        prefsPath := profilePath "\Preferences"
        if !FileExist(prefsPath)
            return out
        try {
            text := FileRead(prefsPath, "UTF-8")
        } catch {
            return out
        }

        ; Local profile name inside Preferences.
        if RegExMatch(text, "s)`"profile`"\s*:\s*\{.*?`"name`"\s*:\s*`"([^`"]*)`"", &m)
            out["profileName"] := m[1]

        ; Only read emails from account_info — a global "email" scan can hit the wrong account
        ; when multiple Google accounts exist in one Preferences file.
        if RegExMatch(text, "s)`"account_info`"\s*:\s*\[(.*?)\]", &ai) {
            if RegExMatch(ai[1], "`"email`"\s*:\s*`"([^`"]+@[^`"]+)`"", &m)
                out["email"] := m[1]
        }

        ; google.services.last_username (scoped-ish); avoid other last_username keys if possible.
        if RegExMatch(text, "s)`"google`"\s*:\s*\{.*?`"last_username`"\s*:\s*`"([^`"]+)`"", &m)
            out["lastUsername"] := m[1]
        else if RegExMatch(text, "`"last_username`"\s*:\s*`"([^`"]+@[^`"]+)`"", &m)
            out["lastUsername"] := m[1]
        return out
    }

    static LooksLikeEmail(text) {
        t := Trim(text)
        if (t = "")
            return false
        return RegExMatch(t, "i)^[^@\s]+@[^@\s]+\.[^@\s]+$")
    }

    ; Simplest confirmed way (Chrome / Edge / Firefox / Brave / etc.):
    ; Activate browser → Ctrl+L (address bar) → Ctrl+C → read clipboard → restore focus/clipboard.
    static CollectBrowserUrl(hwnd, restoreHwnd := 0) {
        result := Map(
            "url", "",
            "source", "",
            "note", ""
        )
        if !hwnd || !DllCall("IsWindow", "Ptr", hwnd) {
            result["note"] := "No valid browser window for URL lookup."
            return result
        }

        clipSaved := ClipboardAll()
        A_Clipboard := ""

        try {
            WinActivate("ahk_id " hwnd)
            if !WinWaitActive("ahk_id " hwnd, , 1.5) {
                result["note"] := "Could not activate browser to read URL."
                return result
            }

            Sleep(100)
            SendInput("^l")   ; focus address / omnibox
            Sleep(150)
            SendInput("^c")   ; copy URL
            if !ClipWait(1.2) {
                result["note"] := "Timed out waiting for URL from address bar."
                return result
            }

            url := Trim(A_Clipboard)
            SendInput("{Esc}")  ; leave address bar selection

            if (url = "") {
                result["note"] := "Address bar copy returned empty."
                return result
            }

            result["url"] := url
            result["source"] := "address-bar (Ctrl+L, Ctrl+C)"
            result["note"] := ""
        } catch as err {
            result["note"] := "URL read failed: " err.Message
        } finally {
            try A_Clipboard := clipSaved
            if restoreHwnd && DllCall("IsWindow", "Ptr", restoreHwnd) {
                WinActivate("ahk_id " restoreHwnd)
                WinWaitActive("ahk_id " restoreHwnd, , 1)
            }
        }

        return result
    }

    static FormatBrowserDetails(details) {
        if !IsObject(details) {
            return "Unable to collect browser details."
        }

        lines := []
        lines.Push("Browser details")
        lines.Push("")
        lines.Push("Context enabled: " (details.Has("contextEnabled") && details["contextEnabled"] ? "true" : "false"))
        lines.Push("Kind: " BrowserActions.StrOr(details, "kind", "(none)"))
        lines.Push("Browser: " BrowserActions.StrOr(details, "browserName", "(unknown)"))

        if details.Has("error") && details["error"] != "" {
            lines.Push("")
            lines.Push("Error: " details["error"])
            return BrowserActions.JoinLines(lines)
        }

        ; Target window first — if Title/HWND stay the same across Chrome windows, context picked the wrong one.
        lines.Push("")
        lines.Push("--- Target window ---")
        lines.Push("Title: " BrowserActions.StrOr(details, "titleLive", BrowserActions.StrOr(details, "title")))
        lines.Push("HWND: " BrowserActions.StrOr(details, "hwnd"))
        lines.Push("Window PID: " BrowserActions.StrOr(details, "pid"))
        mainPid := BrowserActions.StrOr(details, "profileMainPid", "")
        if (mainPid != "" && mainPid != BrowserActions.StrOr(details, "pid"))
            lines.Push("Browser main PID: " mainPid)

        lines.Push("")
        lines.Push("--- Identity ---")
        lines.Push("Exe: " BrowserActions.StrOr(details, "exeLive", BrowserActions.StrOr(details, "exe")))
        lines.Push("Path: " BrowserActions.StrOr(details, "processPath"))
        lines.Push("Class: " BrowserActions.StrOr(details, "classLive", BrowserActions.StrOr(details, "class")))
        urlText := details.Has("url") ? Trim(String(details["url"])) : ""
        lines.Push("URL: " (urlText != "" ? urlText : "(not available)"))
        if (urlText != "" && details.Has("urlSource") && details["urlSource"] != "")
            lines.Push("URL source: " details["urlSource"])
        if (urlText = "" && details.Has("urlNote") && details["urlNote"] != "")
            lines.Push("URL note: " details["urlNote"])

        lines.Push("")
        lines.Push("--- Profile ---")
        signedIn := details.Has("profileSignedIn") && details["profileSignedIn"]
        lines.Push("Signed in: " (signedIn ? "yes" : "no"))
        if signedIn {
            lines.Push("Account: " BrowserActions.StrOr(details, "profileAccount", "(n/a)"))
            lines.Push("Profile name: " BrowserActions.StrOr(details, "profileName", "(n/a)"))
        } else {
            lines.Push("Account: (not signed in)")
            lines.Push("Profile name: " BrowserActions.StrOr(details, "profileName", BrowserActions.StrOr(details, "profileDisplayName", "(n/a)")))
        }
        lines.Push("Primary label: " BrowserActions.StrOr(details, "profileDisplayName", "(n/a)"))
        lines.Push("Directory: " BrowserActions.StrOr(details, "profileDirectory", "(n/a)"))
        lines.Push("User data dir: " BrowserActions.StrOr(details, "userDataDir", "(n/a)"))
        lines.Push("Profile path: " BrowserActions.StrOr(details, "profilePath", "(n/a)"))
        lines.Push("Profile source: " BrowserActions.StrOr(details, "profileSource", "(n/a)"))
        if details.Has("profileAppId") && details["profileAppId"] != ""
            lines.Push("AppUserModelID: " details["profileAppId"])
        if details.Has("profileNote") && details["profileNote"] != ""
            lines.Push("Profile note: " details["profileNote"])
        cmd := details.Has("profileCommandLine") ? String(details["profileCommandLine"]) : ""
        if (cmd != "") {
            lines.Push("Profile switches: " BrowserActions.SummarizeProfileSwitches(cmd))
        } else {
            lines.Push("Profile switches: (command line unavailable)")
        }

        lines.Push("")
        lines.Push("--- Window state ---")
        lines.Push("Valid: " BrowserActions.BoolStr(details, "windowValid"))
        lines.Push("Visible: " BrowserActions.BoolStr(details, "isVisible"))
        lines.Push("Minimized: " BrowserActions.BoolStr(details, "isMinimized"))
        lines.Push("Maximized: " BrowserActions.BoolStr(details, "isZoomed"))
        lines.Push("MinMax: " BrowserActions.StrOr(details, "minMax") " (" BrowserActions.StrOr(details, "minMaxLabel") ")")
        lines.Push("Transparent: " BrowserActions.StrOr(details, "transparent", "(opaque/default)"))
        lines.Push("Style: " BrowserActions.StrOr(details, "style"))
        lines.Push("ExStyle: " BrowserActions.StrOr(details, "exStyle"))

        lines.Push("")
        lines.Push("--- Geometry ---")
        lines.Push("Pos: " BrowserActions.StrOr(details, "x") ", " BrowserActions.StrOr(details, "y"))
        lines.Push("Size: " BrowserActions.StrOr(details, "width") " x " BrowserActions.StrOr(details, "height"))
        lines.Push("Client pos: " BrowserActions.StrOr(details, "clientX") ", " BrowserActions.StrOr(details, "clientY"))
        lines.Push("Client size: " BrowserActions.StrOr(details, "clientWidth") " x " BrowserActions.StrOr(details, "clientHeight"))

        lines.Push("")
        lines.Push("--- Controls ---")
        lines.Push("Control count: " BrowserActions.StrOr(details, "controlCount"))
        lines.Push("Active control: " BrowserActions.StrOr(details, "activeControl", "(none)"))

        return BrowserActions.JoinLines(lines)
    }

    static GuessBrowserName(exeName, processPath := "") {
        p := StrLower(processPath)
        if InStr(p, "\chrome sxs\")
            return "Google Chrome Canary"
        if InStr(p, "\chrome beta\")
            return "Google Chrome Beta"
        if InStr(p, "\chrome dev\")
            return "Google Chrome Dev"
        if InStr(p, "\edge sxs\")
            return "Microsoft Edge Canary"
        if InStr(p, "\edge beta\")
            return "Microsoft Edge Beta"
        if InStr(p, "\edge dev\")
            return "Microsoft Edge Dev"

        e := StrLower(exeName)
        switch e {
            case "chrome.exe":
                return "Google Chrome"
            case "msedge.exe":
                return "Microsoft Edge"
            case "firefox.exe":
                return "Mozilla Firefox"
            case "brave.exe":
                return "Brave"
            case "opera.exe":
                return "Opera"
            case "vivaldi.exe":
                return "Vivaldi"
            default:
                return exeName != "" ? exeName : "(unknown)"
        }
    }

    static MinMaxLabel(minMax) {
        switch minMax {
            case -1:
                return "minimized"
            case 0:
                return "normal"
            case 1:
                return "maximized"
            default:
                return "unknown"
        }
    }

    static SummarizeProfileSwitches(commandLine) {
        parts := []
        profileDir := BrowserActions.ParseChromiumSwitch(commandLine, "profile-directory")
        userDataDir := BrowserActions.ParseChromiumSwitch(commandLine, "user-data-dir")
        if (profileDir != "")
            parts.Push("--profile-directory=" profileDir)
        if (userDataDir != "")
            parts.Push("--user-data-dir=" userDataDir)
        if (parts.Length = 0)
            return "(no profile switches in command line; assuming Default)"
        out := ""
        for i, p in parts
            out .= (i > 1 ? " " : "") p
        return out
    }

    static StrOr(details, key, fallback := "") {
        if !details.Has(key) || details[key] = ""
            return fallback != "" ? fallback : "(n/a)"
        return String(details[key])
    }

    static BoolStr(details, key) {
        if !details.Has(key) || details[key] = ""
            return "(n/a)"
        return details[key] ? "true" : "false"
    }

    static JoinLines(lines) {
        out := ""
        for i, line in lines {
            out .= (i > 1 ? "`n" : "") line
        }
        return out
    }

    static ShowOwnedMessage(text, title := unset, ownerHwnd := 0) {
        if !IsSet(title)
            title := ConfigApp.APP_NAME
        if ownerHwnd {
            MsgBox(text, title, "Owner" ownerHwnd)
        } else {
            MsgBox(text, title)
        }
    }
}
