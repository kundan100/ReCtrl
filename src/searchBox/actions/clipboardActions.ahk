#Requires AutoHotkey v2

class ClipboardActions {
    static GetClipboardFilePath() {
        userHome := EnvGet("USERPROFILE")
        if (userHome = "") {
            throw Error("USERPROFILE could not be resolved.")
        }
        return userHome "\__cyk\ahk\ReCtrl\userData\clipboardLatest.txt"
    }

    static CreateClipboardFileFromText() {
        text := A_Clipboard
        if (Trim(text) = "") {
            return Map(
                "ok", false,
                "title", "Clipboard Save",
                "message", "Clipboard has no text to save."
            )
        }

        filePath := ClipboardActions.GetClipboardFilePath()
        SplitPath(filePath, , &dirPath)
        if !DirExist(dirPath) {
            DirCreate(dirPath)
        }

        ; Overwrite with latest clipboard text snapshot.
        FileDelete(filePath)
        FileAppend(text, filePath, "UTF-8")

        return Map(
            "ok", true,
            "title", "Clipboard Save",
            "message", "Saved clipboard text to:`n" filePath
        )
    }

    static LoadClipboardTextFromFile() {
        filePath := ClipboardActions.GetClipboardFilePath()
        if !FileExist(filePath) {
            return Map(
                "ok", false,
                "title", "Clipboard Load",
                "message", "Clipboard file not found.`nRun 'create clipboard file' first.`n`nPath:`n" filePath
            )
        }

        text := FileRead(filePath, "UTF-8")
        if (Trim(text) = "") {
            return Map(
                "ok", false,
                "title", "Clipboard Load",
                "message", "Clipboard file is empty.`nPath:`n" filePath
            )
        }

        A_Clipboard := text
        ClipWait(0.5)

        return Map(
            "ok", true,
            "title", "Clipboard Load",
            "message", "Loaded file text into clipboard.`nChars: " StrLen(text)
        )
    }
}
