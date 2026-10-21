#Requires AutoHotkey v2

; Registers leaf-action hotkeys from searchActions.json.
; Active only while the ReCtrl main window is focused (#HotIf).
; Public API:
;   SearchActionsHotkeys.Register(leafActions, handler)
;   SearchActionsHotkeys.UnregisterAll()
class SearchActionsHotkeys {
    static registeredKeys := []
    static actionsById := Map()
    static handlerRef := ""

    ; leafActions: array of leaf nodes; handler: SearchBoxHandler (ExecuteActionById).
    static Register(leafActions, handler) {
        SearchActionsHotkeys.UnregisterAll()
        SearchActionsHotkeys.handlerRef := handler
        SearchActionsHotkeys.actionsById := Map()

        if !(leafActions is Array) || !IsObject(handler)
            return

        seen := Map()
        bindings := []
        for action in leafActions {
            if !(action is Map) || !action.Has("hotkey")
                continue
            raw := Trim(String(action["hotkey"]))
            if (raw = "")
                continue
            if !action.Has("id") || Trim(String(action["id"])) = ""
                throw Error("Menu item with hotkey '" raw "' is missing 'id'.")

            hk := SearchActionsHotkeys.NormalizeHotkey(raw)
            actionId := String(action["id"])
            if seen.Has(hk) {
                throw Error(
                    "Duplicate hotkey '" raw "' (normalized '" hk "').`n"
                    . "Used by '" seen[hk] "' and '" actionId "'."
                )
            }
            seen[hk] := actionId
            SearchActionsHotkeys.actionsById[actionId] := action
            bindings.Push(Map("hotkey", hk, "id", actionId))
        }

        if bindings.Length = 0
            return

        HotIf SearchActionsHotkeys_IsReCtrlFocused
        for item in bindings {
            actionId := item["id"]
            try {
                Hotkey(item["hotkey"], SearchActionsHotkeys.MakeCallback(actionId), "On")
            } catch as err {
                HotIf()
                SearchActionsHotkeys.UnregisterAll()
                throw Error(
                    "Failed to register hotkey '" item["hotkey"] "' for '" actionId "':`n" err.Message
                )
            }
            SearchActionsHotkeys.registeredKeys.Push(item["hotkey"])
        }
        HotIf()
    }

    static UnregisterAll() {
        if SearchActionsHotkeys.registeredKeys.Length > 0 {
            HotIf SearchActionsHotkeys_IsReCtrlFocused
            for hk in SearchActionsHotkeys.registeredKeys {
                try Hotkey(hk, "Off")
            }
            HotIf()
        }
        SearchActionsHotkeys.registeredKeys := []
        SearchActionsHotkeys.actionsById := Map()
        SearchActionsHotkeys.handlerRef := ""
    }

    static MakeCallback(actionId) {
        return (*) => SearchActionsHotkeys.OnHotkey(actionId)
    }

    static OnHotkey(actionId) {
        handler := SearchActionsHotkeys.handlerRef
        if !IsObject(handler)
            return
        try {
            handler.ExecuteActionById(actionId, true)
        } catch as err {
            try Notify.Feedback(ConfigAppSettings.APP_NAME, err.Message, 0, "error")
            catch {
                try MsgBox(err.Message, ConfigAppSettings.APP_NAME " — Hotkey", "Iconx")
            }
        }
    }

    ; Accepts AHK form (^!c) or friendly form (Ctrl+Alt+C).
    static NormalizeHotkey(raw) {
        s := Trim(String(raw))
        if (s = "")
            throw Error("Hotkey value is empty.")

        lower := StrLower(s)
        ; Raw AHK syntax (modifiers + key, no Ctrl/Alt/Shift/Win words).
        if !RegExMatch(lower, "ctrl|control|alt|shift|win|windows") {
            return s
        }

        mods := ""
        key := ""
        for part in StrSplit(s, "+") {
            p := StrLower(Trim(part))
            if (p = "")
                continue
            switch p {
                case "ctrl", "control":
                    mods .= "^"
                case "alt":
                    mods .= "!"
                case "shift":
                    mods .= "+"
                case "win", "windows":
                    mods .= "#"
                default:
                    if (key != "") {
                        throw Error("Invalid hotkey '" raw "': multiple key names.")
                    }
                    key := Trim(part)
            }
        }
        if (key = "")
            throw Error("Invalid hotkey '" raw "': missing key.")
        return mods . key
    }
}

; HotIf callback: ReCtrl main window visible and active.
SearchActionsHotkeys_IsReCtrlFocused(name := "") {
    global mainAppInstance
    if !IsSet(mainAppInstance) || !IsObject(mainAppInstance)
        return false
    if !IsObject(mainAppInstance.container)
        return false
    try {
        if !mainAppInstance.container.IsVisible()
            return false
        hwnd := mainAppInstance.container.GetHwnd()
        if !hwnd
            return false
        return !!WinActive("ahk_id " hwnd)
    } catch {
        return false
    }
}
