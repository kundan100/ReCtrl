#Requires AutoHotkey v2

; Shared Chromium/browser profile identity helpers (used by tip + open-in-browser actions).
class BrowserProfile {
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

        winProps := BrowserProfile.GetWindowAppUserModelProps(hwnd)
        out["appId"] := winProps["appId"]
        if (winProps["relaunchCommand"] != "") {
            profileDir := BrowserProfile.ParseChromiumSwitch(winProps["relaunchCommand"], "profile-directory")
            userDataDir := BrowserProfile.ParseChromiumSwitch(winProps["relaunchCommand"], "user-data-dir")
            out["commandLine"] := winProps["relaunchCommand"]
            if (profileDir != "" || userDataDir != "")
                source := "window-relaunch-command"
        }

        procInfo := BrowserProfile.ResolveBrowserMainProcess(pid, exeName)
        out["mainPid"] := procInfo["pid"]
        procCmd := procInfo["commandLine"]
        if (out["commandLine"] = "" && procCmd != "")
            out["commandLine"] := procCmd

        if (profileDir = "" && procCmd != "") {
            profileDir := BrowserProfile.ParseChromiumSwitch(procCmd, "profile-directory")
            if (userDataDir = "")
                userDataDir := BrowserProfile.ParseChromiumSwitch(procCmd, "user-data-dir")
            if (profileDir != "")
                source := "process-command-line"
        }

        if (userDataDir = "")
            userDataDir := BrowserProfile.ResolveUserDataDir(exeName, processPath)

        if (profileDir = "" && winProps["appId"] != "") {
            fromAppId := BrowserProfile.ResolveProfileDirFromAppId(userDataDir, winProps["appId"])
            if (fromAppId != "") {
                profileDir := fromAppId
                source := "window-app-user-model-id"
            }
        }

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

        names := BrowserProfile.ResolveProfileIdentity(userDataDir, profileDir, profilePath)
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

    ; Resolve --profile-directory from primary label (display name / account / profile name).
    ; Blank primaryLabel → "" (caller may omit --profile-directory).
    static ResolveDirectoryByPrimaryLabel(browserName, primaryLabel) {
        wanted := Trim(primaryLabel)
        if (wanted = "")
            return ""

        exeName := BrowserWindows.ExeFilterForBrowserName(browserName)
        if (exeName = "")
            throw Error("Unsupported browser for profile resolve: " browserName)

        userDataDir := BrowserProfile.DefaultUserDataDir(exeName)
        if (userDataDir = "" || !DirExist(userDataDir))
            throw Error("Browser User Data folder not found for: " browserName)

        for profileDir in BrowserProfile.ListProfileDirectories(userDataDir) {
            profilePath := userDataDir "\" profileDir
            names := BrowserProfile.ResolveProfileIdentity(userDataDir, profileDir, profilePath)
            displayName := names["signedIn"] ? names["account"] : names["profileName"]
            if BrowserProfile.LabelMatches(wanted, displayName, names["account"], names["profileName"])
                return profileDir
        }

        throw Error("No profile matches primary label:`n" wanted)
    }

    static ListProfileDirectories(userDataDir) {
        dirs := []
        if DirExist(userDataDir "\Default")
            dirs.Push("Default")
        loop files userDataDir "\Profile *", "D"
            dirs.Push(A_LoopFileName)
        return dirs
    }

    static LabelMatches(wanted, displayName := "", account := "", profileName := "") {
        return BrowserProfile.LabelEquals(displayName, wanted)
            || BrowserProfile.LabelEquals(account, wanted)
            || BrowserProfile.LabelEquals(profileName, wanted)
    }

    static LabelEquals(actual, wanted) {
        return (actual != "" && StrLower(actual) = StrLower(wanted))
    }

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
            out["appId"] := BrowserProfile.PropertyStoreGetString(store, BrowserProfile.PKEY_AppUserModel(5))
            out["relaunchCommand"] := BrowserProfile.PropertyStoreGetString(store, BrowserProfile.PKEY_AppUserModel(2))
        } finally {
            try ComCall(2, store)  ; IUnknown::Release
        }
        return out
    }

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

    static ResolveProfileDirFromAppId(userDataDir, appId) {
        if (appId = "" || userDataDir = "")
            return ""
        if !DirExist(userDataDir)
            return ""

        userDataBase := BrowserProfile.SanitizeAumidPart(BrowserProfile.FileBaseName(userDataDir))
        if (userDataBase = "")
            return ""

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
            suffix := userDataBase "." BrowserProfile.SanitizeAumidPart(folder)
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

    static ResolveBrowserMainProcess(pid, exeName := "") {
        pid := Integer(pid)
        if !pid
            return Map("pid", 0, "commandLine", "")

        if (exeName = "")
            exeName := BrowserProfile.GetProcessName(pid)
        if (exeName = "")
            return Map("pid", pid, "commandLine", BrowserProfile.GetProcessCommandLine(pid))

        parentOf := Map()
        cmdOf := Map()
        try {
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
            cmd := BrowserProfile.GetProcessCommandLine(pid)
            if BrowserProfile.IsBrowserMainCommandLine(cmd)
                return Map("pid", pid, "commandLine", cmd)
            parentPid := BrowserProfile.GetParentProcessId(pid)
            if parentPid {
                parentCmd := BrowserProfile.GetProcessCommandLine(parentPid)
                if BrowserProfile.IsBrowserMainCommandLine(parentCmd)
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
                if BrowserProfile.IsBrowserMainCommandLine(cmd)
                    return Map("pid", current, "commandLine", cmd)
                if (bestWithProfile["pid"] = 0 && BrowserProfile.ParseChromiumSwitch(cmd, "profile-directory") != "")
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
        pattern := "i)--" switchName "=(?:`"([^`"]+)`"|(.+?)(?=\s+--|$))"
        if RegExMatch(commandLine, pattern, &m) {
            if (m[1] != "")
                return Trim(m[1])
            if (m[2] != "")
                return Trim(m[2])
        }
        return ""
    }

    static ResolveUserDataDir(exeName, processPath := "") {
        fromPath := BrowserProfile.UserDataDirFromProcessPath(processPath)
        if (fromPath != "")
            return fromPath
        return BrowserProfile.DefaultUserDataDir(exeName)
    }

    static UserDataDirFromProcessPath(processPath) {
        if (processPath = "")
            return ""
        path := StrReplace(processPath, "/", "\")
        localApp := EnvGet("LOCALAPPDATA")
        if (localApp = "")
            return ""

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

        localState := BrowserProfile.ReadLocalStateProfileFields(userDataDir, profileDirectory)
        prefs := BrowserProfile.ReadProfilePreferencesFields(profilePath)

        profileName := localState["name"]
        if (profileName = "" && prefs["profileName"] != "")
            profileName := prefs["profileName"]

        gaia := localState["gaiaName"]
        userName := localState["userName"]

        out["profileName"] := profileName
        out["gaiaName"] := gaia
        out["userName"] := userName

        account := ""
        if BrowserProfile.LooksLikeEmail(userName)
            account := userName
        else if BrowserProfile.LooksLikeEmail(prefs["email"])
            account := prefs["email"]
        else if BrowserProfile.LooksLikeEmail(prefs["lastUsername"])
            account := prefs["lastUsername"]
        else if BrowserProfile.LooksLikeEmail(gaia)
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

        if RegExMatch(text, "s)`"profile`"\s*:\s*\{.*?`"name`"\s*:\s*`"([^`"]*)`"", &m)
            out["profileName"] := m[1]

        if RegExMatch(text, "s)`"account_info`"\s*:\s*\[(.*?)\]", &ai) {
            if RegExMatch(ai[1], "`"email`"\s*:\s*`"([^`"]+@[^`"]+)`"", &m)
                out["email"] := m[1]
        }

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

    static SummarizeProfileSwitches(commandLine) {
        parts := []
        profileDir := BrowserProfile.ParseChromiumSwitch(commandLine, "profile-directory")
        userDataDir := BrowserProfile.ParseChromiumSwitch(commandLine, "user-data-dir")
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
}
