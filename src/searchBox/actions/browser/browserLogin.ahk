#Requires AutoHotkey v2

; Declarative login via loginSteps + localConfig.LOGIN_DEPENDENCY_PATH.
;
; localConfig:
;   "LOGIN_DEPENDENCY_PATH": "%USERPROFILE%\\__cyk\\ahk\\ReCtrl\\oreoLogins.json"
; Prefer shared steps under root reusables (e.g. reusable__oreo-login-shellapp), referenced from
; action.operation. Inline action.loginSteps still works for one-offs.
;
; Env action:
;   "operation": ["openOrFocusByTitleAndUrl", "reusable__oreo-login-shellapp"]
; Reusable:
;   "operation": "login",
;   "loginSteps": [ … ]
; messageChannel: "show-in-notification" | "msgbox" | "" (blank/omit = no per-step message)
; Success → "Success: {note}"  |  Failure → "Error: {note} — {detail}"
;
; oreoLogins.json keys = env search action ids (not reusable ids);
; values = array of credential objects: { tenantId, username, password, userPersona }.
; 1 credential → use it; 2+ → modal list (↑/↓, Enter select, Esc cancel).
class BrowserLogin {
    ; Entry from browserActions operation "login".
    static Run(cfg, actionId := "") {
        browserName := BrowserActions.CfgStr(cfg, "appIdentifier")
        if (browserName = "")
            throw Error("browserActions login requires action.appIdentifier.")

        steps := BrowserLogin.GetLoginSteps(cfg)
        if (steps.Length = 0)
            throw Error("browserActions login requires a non-empty action.loginSteps array.")

        loginCfg := BrowserLogin.LoadLoginDependency(actionId, true)
        if !(loginCfg is Map)
            return Map("ok", false, "silent", true, "aborted", true, "error", "Login cancelled.")

        primaryLabel := BrowserActions.CfgStr(cfg, "multiWinIdentifier")

        hwnd := BrowserLogin.ResolveBrowserHwnd(browserName, primaryLabel)
        if !hwnd
            throw Error("browserActions login: no open window for " browserName
                . (primaryLabel != "" ? " / " primaryLabel : ""))

        BrowserWindows.Activate(hwnd)
        Sleep(200)

        results := []
        for step in steps {
            stepResult := BrowserLogin.RunStep(hwnd, step, loginCfg, actionId)
            results.Push(stepResult)
            BrowserLogin.ShowStepFeedback(step, stepResult)

            if !stepResult["ok"] {
                if stepResult["skippable"] {
                    BrowserWindows.Activate(hwnd)
                    continue
                }
                ; Hard stop. If messageChannel already notified, stay silent to avoid a second dialog.
                channel := BrowserLogin.NormalizeMessageChannel(
                    BrowserLogin.CfgStr(step, "messageChannel", ""))
                note := stepResult.Has("note") ? stepResult["note"] : ""
                detail := stepResult.Has("detail") ? stepResult["detail"] : "failed"
                errText := "Login step failed"
                    . (note != "" ? " (" note ")" : "")
                    . ": " detail
                    . "`nFurther loginSteps were stopped."
                if (channel = "")
                    throw Error(errText)
                return Map("ok", false, "silent", true, "aborted", true, "loginSteps", results, "error", errText)
            }
            BrowserWindows.Activate(hwnd)
        }

        return Map("ok", true, "silent", true, "loginSteps", results)
    }

    ; messageChannel blank/omit → no message.
    ; "show-in-notification" → toast; "msgbox" → MsgBox.
    ; Text always from note: Success: {note} | Error: {note} — {detail}
    static ShowStepFeedback(step, stepResult) {
        channel := BrowserLogin.NormalizeMessageChannel(
            BrowserLogin.CfgStr(step, "messageChannel", ""))
        if (channel = "")
            return

        note := stepResult.Has("note") ? Trim(String(stepResult["note"])) : ""
        if (note = "")
            note := "(unnamed step)"
        detail := stepResult.Has("detail") ? Trim(String(stepResult["detail"])) : ""
        ok := stepResult.Has("ok") && stepResult["ok"]

        if ok {
            title := ConfigAppSettings.APP_NAME " — Login"
            message := "Success: " note
            type := "success"
        } else {
            title := ConfigAppSettings.APP_NAME " — Login"
            message := "Error: " note
            if (detail != "")
                message .= " — " detail
            type := "error"
        }

        if (channel = "show-in-notification") {
            Notify.Show(title, message, type)
            return
        }
        if (channel = "msgbox") {
            iconOpt := Notify.MsgBoxIconOpt(type)
            MsgBox(message, title, iconOpt)
        }
    }

    static NormalizeMessageChannel(channel) {
        c := StrLower(Trim(channel))
        if (c = "" || c = "none" || c = "off" || c = "omit")
            return ""
        if (c = "show-in-notification" || c = "notification" || c = "toast")
            return "show-in-notification"
        if (c = "msgbox" || c = "messagebox" || c = "popup")
            return "msgbox"
        return ""
    }

    static GetLoginSteps(cfg) {
        if !IsObject(cfg) || !cfg.Has("loginSteps")
            return []
        raw := cfg["loginSteps"]
        if !(raw is Array)
            throw Error("browserActions login: action.loginSteps must be an array.")
        out := []
        for step in raw {
            if (step is Map)
                out.Push(step)
        }
        return out
    }

    ; One declarative step. On failure: skippable=true → ok=false (caller continues);
    ; skippable=false (default) → caller throws and stops.
    static RunStep(hwnd, step, loginCfg, actionId := "") {
        note := BrowserLogin.CfgStr(step, "note", "")
        waitMs_maxTimeForFieldToShowUp := BrowserLogin.CfgInt(step, "waitMs_maxTimeForFieldToShowUp", 3000)
        waitMs_afterAction := BrowserLogin.CfgInt(step, "waitMs_afterAction", 0)
        skippable := BrowserLogin.CfgBool(step, "skippable", false)
        fieldAction := StrLower(BrowserLogin.CfgStr(step, "fieldAction", ""))
        valueKey := BrowserLogin.CfgStr(step, "fieldValueFromKeyInLoginDependency", "NA")
        fieldId := (step.Has("fieldIdentifier") && step["fieldIdentifier"] is Map)
            ? step["fieldIdentifier"]
            : Map()

        result := Map(
            "note", note,
            "fieldAction", fieldAction,
            "skippable", skippable,
            "ok", false,
            "detail", ""
        )

        el := BrowserLoginUia.WaitFind(hwnd, fieldId, waitMs_maxTimeForFieldToShowUp)
        if !el {
            result["detail"] := "field not found within waitMs_maxTimeForFieldToShowUp"
            return result
        }

        switch fieldAction {
            case "textfieldentry":
                if BrowserLogin.IsNa(valueKey)
                    throw Error("browserActions login step '" note "': textfieldEntry needs a loginDependency key (not NA).")
                value := BrowserLogin.CfgStr(loginCfg, valueKey, "")
                if (value = "")
                    throw Error("browserActions login step '" note "': loginDependency key '" valueKey
                        . "' is empty for id: " actionId)
                if !BrowserLoginUia.SetEditValue(el, value) {
                    result["detail"] := "textfieldEntry failed"
                    return result
                }
                result["ok"] := true
                result["detail"] := "entered " valueKey

            case "click":
                if !BrowserLoginUia.Click(el) {
                    result["detail"] := "click failed"
                    return result
                }
                result["ok"] := true
                result["detail"] := "clicked"

            default:
                throw Error("browserActions login step '" note "': unknown fieldAction: " fieldAction)
        }

        if (result["ok"] && waitMs_afterAction > 0)
            Sleep(waitMs_afterAction)
        return result
    }

    static IsNa(valueKey) {
        k := StrUpper(Trim(valueKey))
        return (k = "" || k = "NA" || k = "N/A" || k = "NOTAPPLICABLE")
    }

    ; Resolve localConfig.LOGIN_DEPENDENCY_PATH → one credential Map for this actionId.
    ; Entry must be a non-empty array of credential objects.
    ; required=false → returns "" when path/entry missing or user cancels the picker.
    static LoadLoginDependency(actionId, required := true) {
        actionId := Trim(actionId)
        depPath := ""
        lc := SearchActionsConfig.LocalConfig
        if (lc is Map) && lc.Has("LOGIN_DEPENDENCY_PATH")
            depPath := Trim(String(lc["LOGIN_DEPENDENCY_PATH"]))
        if (depPath = "") {
            if required
                throw Error("browserActions login requires localConfig.LOGIN_DEPENDENCY_PATH (path to oreoLogins.json).")
            return ""
        }
        if (actionId = "") {
            if required
                throw Error("browserActions login requires the search action id.")
            return ""
        }

        path := LocalSearchActionsMerge.ExpandEnvPath(depPath)
        if (path = "" || !FileExist(path)) {
            if required
                throw Error("browserActions login: LOGIN_DEPENDENCY_PATH file not found:`n" path)
            return ""
        }

        try {
            text := FileRead(path, "UTF-8")
            if (SubStr(text, 1, 1) = Chr(0xFEFF))
                text := SubStr(text, 2)
            root := JsonParse.Parse(text)
        } catch as err {
            if required
                throw Error("browserActions login: failed to load LOGIN_DEPENDENCY_PATH:`n" path "`n`n" err.Message)
            return ""
        }

        if !(root is Map) || !root.Has(actionId) {
            if required
                throw Error("browserActions login: no entry for id '" actionId "' in:`n" path)
            return ""
        }

        entries := root[actionId]
        if !(entries is Array) || (entries.Length = 0) {
            if required
                throw Error("browserActions login: id '" actionId "' must be a non-empty credential array in:`n" path)
            return ""
        }

        return BrowserLogin.PickCredentialEntry(entries, actionId, required)
    }

    ; 1 Map → use it; 2+ Maps → modal picker; 0 → error / "".
    static PickCredentialEntry(entries, actionId := "", required := true) {
        maps := []
        for item in entries {
            if (item is Map)
                maps.Push(item)
        }
        if (maps.Length = 0) {
            if required
                throw Error("browserActions login: id '" actionId "' credential array has no object entries.")
            return ""
        }
        if (maps.Length = 1)
            return maps[1]

        ; Cancel → "" (Run aborts silently); do not throw.
        return BrowserLogin.PromptCredentialPick(maps, actionId)
    }

    ; Modal ListBox: ↑/↓ move, Enter select, Esc cancel. Returns Map or "".
    static PromptCredentialPick(maps, actionId := "") {
        labels := []
        for item in maps
            labels.Push(BrowserLogin.FormatCredentialLabel(item))

        selectedIndex := 0
        title := ConfigAppSettings.APP_NAME " — Select login"
        g := Gui("+AlwaysOnTop -MinimizeBox +OwnDialogs", title)
        g.SetFont("s10", "Consolas")
        hint := "Select credential"
        if (actionId != "")
            hint .= " for " actionId
        hint .= "`n↑/↓ move · Enter select · Esc cancel"
        g.SetFont("s9", "Segoe UI")
        g.AddText("w560", hint)
        g.SetFont("s10", "Consolas")
        rowCount := maps.Length
        if (rowCount > 12)
            rowCount := 12
        lb := g.Add("ListBox", "w560 r" rowCount " vCredList", labels)
        lb.Choose(1)

        confirm(*) {
            idx := Integer(lb.Value)
            if (idx >= 1 && idx <= maps.Length)
                selectedIndex := idx
            g.Destroy()
        }
        cancel(*) {
            selectedIndex := 0
            g.Destroy()
        }

        g.AddButton("Default w1 h1 Hidden", "OK").OnEvent("Click", confirm)
        lb.OnEvent("DoubleClick", confirm)
        g.OnEvent("Close", cancel)
        g.OnEvent("Escape", cancel)

        g.Show("Center")
        lb.Focus()
        WinWaitClose(g)

        if (selectedIndex >= 1 && selectedIndex <= maps.Length)
            return maps[selectedIndex]
        return ""
    }

    ; "tenantId --- username --- userPersona" (blank persona → "-").
    static FormatCredentialLabel(item) {
        tenant := BrowserLogin.CfgStr(item, "tenantId", "")
        user := BrowserLogin.CfgStr(item, "username", "")
        persona := BrowserLogin.CfgStr(item, "userPersona", "")
        if (persona = "")
            persona := "-"
        return tenant " --- " user " --- " persona
    }

    static ResolveBrowserHwnd(browserName, primaryLabel := "") {
        hwnds := BrowserWindows.ListByBrowserAndLabel(browserName, primaryLabel)
        if (hwnds.Length = 0)
            return 0
        return hwnds[1]
    }

    static CfgStr(cfg, key, fallback := "") {
        if !IsObject(cfg) || !cfg.Has(key)
            return fallback
        v := Trim(String(cfg[key]))
        return v != "" ? v : fallback
    }

    static CfgInt(cfg, key, fallback := 0) {
        if !IsObject(cfg) || !cfg.Has(key)
            return fallback
        try {
            return Integer(cfg[key])
        } catch {
            return fallback
        }
    }

    static CfgBool(cfg, key, fallback := false) {
        if !IsObject(cfg) || !cfg.Has(key)
            return fallback
        v := cfg[key]
        if (v = true || v = 1)
            return true
        if (v = false || v = 0)
            return false
        s := StrLower(Trim(String(v)))
        if (s = "true" || s = "1" || s = "yes")
            return true
        if (s = "false" || s = "0" || s = "no")
            return false
        return fallback
    }
}
