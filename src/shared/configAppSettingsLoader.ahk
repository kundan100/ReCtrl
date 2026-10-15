#Requires AutoHotkey v2

; Loads config/configAppSettings.json (info / view / functional).
; JSON Maps are converted to objects so call sites use cfg.HEIGHT (not cfg["HEIGHT"]).
; View: ConfigAppSettings.WINDOW.ALWAYS_ON_TOP
; Notify: ConfigAppSettings.FUNCTIONAL.NOTIFY.RESULT_FEEDBACK
; WINDOW.TITLE is derived (not stored in JSON).
class ConfigAppSettings {
    static CONFIG_JSON_PATH := A_ScriptDir "\config\configAppSettings.json"

    static APP_NAME := ""
    static APP_VERSION := ""
    static INFO := {}
    static WINDOW := {}
    static HEADER := {}
    static CONTENT := {}
    static TRANSPARENCY := {}
    static FUNCTIONAL := { NOTIFY: {} }

    static Load(filePath := unset) {
        if !IsSet(filePath)
            filePath := ConfigAppSettings.CONFIG_JSON_PATH

        if !FileExist(filePath)
            throw Error("App settings file not found:`n" filePath)

        text := FileRead(filePath, "UTF-8")
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)

        root := JsonParse.Parse(text)
        if !(root is Map)
            throw Error("configAppSettings.json root must be a JSON object.")

        infoMap := ConfigAppSettings.RequireMap(root, "info")
        ConfigAppSettings.APP_NAME := ConfigAppSettings.RequireNonEmptyString(infoMap, "APP_NAME")
        ConfigAppSettings.APP_VERSION := ConfigAppSettings.RequireNonEmptyString(infoMap, "APP_VERSION")
        ConfigAppSettings.INFO := ConfigAppSettings.MapToObject(infoMap)

        view := ConfigAppSettings.RequireMap(root, "view")
        ConfigAppSettings.WINDOW := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "WINDOW"))
        ConfigAppSettings.HEADER := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "HEADER"))
        ConfigAppSettings.CONTENT := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "CONTENT"))
        ConfigAppSettings.TRANSPARENCY := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "TRANSPARENCY"))

        functional := ConfigAppSettings.RequireMap(root, "functional")
        ConfigAppSettings.FUNCTIONAL := ConfigAppSettings.MapToObject(functional)

        ; Derived — not stored in JSON.
        ConfigAppSettings.WINDOW.TITLE := ConfigAppSettings.DisplayNameWithVersion()
    }

    ; e.g. ReCtrl (v2.0.0)
    static DisplayNameWithVersion() {
        return ConfigAppSettings.APP_NAME " (v" ConfigAppSettings.APP_VERSION ")"
    }

    static AppHeaderHeight() {
        return ConfigAppSettings.WINDOW.SHOW_TITLE_BAR ? 0 : ConfigAppSettings.HEADER.HEIGHT
    }

    ; Recursively turn JSON Maps into objects (dot-access friendly).
    static MapToObject(value) {
        if (value is Map) {
            obj := {}
            for key, item in value
                obj.%key% := ConfigAppSettings.MapToObject(item)
            return obj
        }
        if (value is Array) {
            out := []
            for item in value
                out.Push(ConfigAppSettings.MapToObject(item))
            return out
        }
        return value
    }

    static RequireMap(parent, key) {
        if !parent.Has(key) || !(parent[key] is Map)
            throw Error("configAppSettings.json missing object '" key "'.")
        return parent[key]
    }

    static RequireNonEmptyString(parent, key) {
        if !parent.Has(key)
            throw Error("configAppSettings.json missing required '" key "'.")
        value := Trim(String(parent[key]))
        if (value = "")
            throw Error("configAppSettings.json '" key "' must be a non-empty string.")
        return value
    }
}
