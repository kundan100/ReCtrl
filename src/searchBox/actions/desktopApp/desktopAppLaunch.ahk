#Requires AutoHotkey v2

; Launch a desktop app from JSON filePath (or known defaults for appIdentifier).
; OpenDocument: open a document path with that app (e.g. JSON in Notepad++).
class DesktopAppLaunch {
    static Open(appIdentifier, filePath := "", launchArgs := "") {
        exePath := DesktopAppLaunch.ResolveExe(appIdentifier, filePath)
        if (exePath = "")
            throw Error("Could not find executable for: " appIdentifier)

        args := Trim(launchArgs)
        if (args != "")
            Run(Format('"{1}" {2}', exePath, args))
        else
            Run(Format('"{1}"', exePath))
    }

    ; Open documentPath with appIdentifier (exe resolved separately; path is the document).
    static OpenDocument(appIdentifier, documentPath) {
        exePath := DesktopAppLaunch.ResolveExe(appIdentifier, "")
        if (exePath = "")
            throw Error("Could not find executable for: " appIdentifier)

        doc := DesktopAppLaunch.ResolveDocumentPath(documentPath)
        if (doc = "")
            throw Error("desktopAppActions openFile requires a non-empty action.filePath.")
        if !FileExist(doc)
            throw Error("File not found:`n" doc)

        Run(Format('"{1}" "{2}"', exePath, doc))
    }

    static ResolveExe(appIdentifier, filePath := "") {
        path := DesktopAppLaunch.ExpandPath(Trim(filePath))
        if (path != "" && FileExist(path))
            return path

        exeName := DesktopAppWindows.ExeFilterForApp(appIdentifier)
        if (exeName != "") {
            for hwnd in WinGetList("ahk_exe " exeName) {
                try {
                    processPath := WinGetProcessPath(hwnd)
                    if (processPath != "" && FileExist(processPath))
                        return processPath
                } catch {
                    ; try next
                }
            }
        }

        for candidate in DesktopAppLaunch.DefaultExeCandidates(appIdentifier) {
            expanded := DesktopAppLaunch.ExpandPath(candidate)
            if (expanded != "" && FileExist(expanded))
                return expanded
        }
        return ""
    }

    ; Expand env vars; resolve relative paths against A_ScriptDir.
    static ResolveDocumentPath(path) {
        path := DesktopAppLaunch.ExpandPath(Trim(path))
        if (path = "")
            return ""
        path := StrReplace(path, "/", "\")
        if RegExMatch(path, "i)^[a-z]:\\") || SubStr(path, 1, 2) = "\\"
            return path
        if SubStr(path, 1, 1) = "\"
            return A_ScriptDir path
        return A_ScriptDir "\" path
    }

    static ExpandPath(path) {
        path := Trim(path)
        if (path = "")
            return ""
        ; Expand %ENV% tokens (e.g. %LOCALAPPDATA%\Programs\cursor\Cursor.exe).
        while RegExMatch(path, "%([^%]+)%", &m) {
            envVal := EnvGet(m[1])
            path := StrReplace(path, m[0], envVal)
        }
        return path
    }

    static DefaultExeCandidates(appIdentifier) {
        localApp := EnvGet("LOCALAPPDATA")
        pf := EnvGet("ProgramFiles")
        pf86 := EnvGet("ProgramFiles(x86)")
        switch Trim(appIdentifier) {
            case "Cursor":
                return [
                    localApp "\Programs\cursor\Cursor.exe",
                    localApp "\Programs\Cursor\Cursor.exe",
                    pf "\Cursor\Cursor.exe"
                ]
            case "Microsoft Teams", "Teams":
                return [
                    localApp "\Microsoft\WindowsApps\ms-teams.exe",
                    pf "\WindowsApps\MSTeams_8wekyb3d8bbwe\ms-teams.exe"
                ]
            case "Outlook", "Microsoft Outlook":
                return [
                    pf "\Microsoft Office\root\Office16\OUTLOOK.EXE",
                    pf86 "\Microsoft Office\root\Office16\OUTLOOK.EXE"
                ]
            case "OneNote", "Microsoft OneNote":
                return [
                    pf "\Microsoft Office\root\Office16\ONENOTE.EXE",
                    pf86 "\Microsoft Office\root\Office16\ONENOTE.EXE",
                    localApp "\Microsoft\WindowsApps\onenote.exe"
                ]
            case "Notepad++", "notepad++":
                return [
                    pf "\Notepad++\notepad++.exe",
                    pf86 "\Notepad++\notepad++.exe",
                    localApp "\Programs\Notepad++\notepad++.exe"
                ]
            default:
                return []
        }
    }
}
