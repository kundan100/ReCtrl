#Requires AutoHotkey v2

; Launch a URL/file path in a target browser + profile (by primary label).
class BrowserLaunch {
    static OpenUrl(url, browserName, primaryLabel := "") {
        url := Trim(url)
        if (url = "")
            throw Error("URL/path is empty; nothing to open.")

        exePath := BrowserLaunch.ResolveExe(browserName)
        if (exePath = "")
            throw Error("Could not find browser executable for: " browserName)

        profileDir := BrowserProfile.ResolveDirectoryByPrimaryLabel(browserName, primaryLabel)
        if (profileDir != "")
            Run(Format('"{1}" --profile-directory="{2}" "{3}"', exePath, profileDir, url))
        else
            Run(Format('"{1}" "{2}"', exePath, url))
    }

    static ResolveExe(browserName) {
        exeName := BrowserWindows.ExeFilterForBrowserName(browserName)
        if (exeName = "")
            return ""

        for hwnd in WinGetList("ahk_exe " exeName) {
            try {
                processPath := WinGetProcessPath(hwnd)
                if (processPath != "" && FileExist(processPath)
                    && BrowserProfile.GuessBrowserName(exeName, processPath) = browserName) {
                    return processPath
                }
            } catch {
                ; try next window
            }
        }

        for path in BrowserLaunch.DefaultExeCandidates(browserName) {
            if (path != "" && FileExist(path))
                return path
        }
        return ""
    }

    static DefaultExeCandidates(browserName) {
        pf := EnvGet("ProgramFiles")
        pf86 := EnvGet("ProgramFiles(x86)")
        localApp := EnvGet("LOCALAPPDATA")
        switch browserName {
            case "Google Chrome":
                return [
                    pf "\Google\Chrome\Application\chrome.exe",
                    pf86 "\Google\Chrome\Application\chrome.exe",
                    localApp "\Google\Chrome\Application\chrome.exe"
                ]
            case "Google Chrome Beta":
                return [pf "\Google\Chrome Beta\Application\chrome.exe", localApp "\Google\Chrome Beta\Application\chrome.exe"]
            case "Google Chrome Dev":
                return [pf "\Google\Chrome Dev\Application\chrome.exe", localApp "\Google\Chrome Dev\Application\chrome.exe"]
            case "Google Chrome Canary":
                return [pf "\Google\Chrome SxS\Application\chrome.exe", localApp "\Google\Chrome SxS\Application\chrome.exe"]
            case "Microsoft Edge":
                return [
                    pf "\Microsoft\Edge\Application\msedge.exe",
                    pf86 "\Microsoft\Edge\Application\msedge.exe",
                    localApp "\Microsoft\Edge\Application\msedge.exe"
                ]
            case "Brave":
                return [
                    pf "\BraveSoftware\Brave-Browser\Application\brave.exe",
                    localApp "\BraveSoftware\Brave-Browser\Application\brave.exe"
                ]
            default:
                return []
        }
    }
}
