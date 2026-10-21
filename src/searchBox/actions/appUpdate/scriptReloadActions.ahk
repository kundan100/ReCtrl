#Requires AutoHotkey v2

; Compare running APP_VERSION (memory) vs disk configAppSettings.json, then Reload if user confirms.
; Public API:
;   ScriptReloadActions.CheckAndPrompt(ownerHwnd := 0) → Map(ok, title, message [, reloaded])
class ScriptReloadActions {
    static CheckAndPrompt(ownerHwnd := 0) {
        running := Trim(String(ConfigAppSettings.APP_VERSION))
        try {
            disk := ConfigAppSettings.ReadDiskAppVersion()
        } catch as err {
            return Map(
                "ok", false,
                "title", ConfigAppSettings.APP_NAME " — Reload",
                "message", "Could not read version from disk:`n" err.Message
            )
        }

        title := ConfigAppSettings.APP_NAME " — Reload"
        options := "YesNo Iconi"
        if ownerHwnd
            options .= " Owner" ownerHwnd

        if (running = disk) {
            prompt :=
                "Version is unchanged (v" running ").`n`n"
                . "Force reload anyway?`n(Same as tray → Reload Script.)"
            answer := MsgBox(prompt, title, options)
            if (answer != "Yes") {
                return Map(
                    "ok", true,
                    "title", title,
                    "message", "Force reload cancelled.`n`nRunning: v" running
                )
            }
        } else {
            prompt :=
                "A newer version is on disk.`n`n"
                . "Running:  v" running "`n"
                . "On disk:  v" disk "`n`n"
                . "Reload script now?`n(Same as tray → Reload Script.)"
            answer := MsgBox(prompt, title, options)
            if (answer != "Yes") {
                return Map(
                    "ok", true,
                    "title", title,
                    "message", "Reload cancelled.`n`nRunning: v" running "`nOn disk: v" disk
                )
            }
        }

        Reload
        ; Unreachable if Reload succeeds.
        return Map(
            "ok", true,
            "title", title,
            "message", "Reloading…",
            "reloaded", true
        )
    }
}
