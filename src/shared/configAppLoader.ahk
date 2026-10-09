#Requires AutoHotkey v2

class ConfigApp {
    ; Path to user-editable app identity config.
    static CONFIG_JSON_PATH := A_ScriptDir "\config\configApp.json"

    static APP_NAME := ""
    static APP_VERSION := ""

    static Load(filePath := unset) {
        if !IsSet(filePath)
            filePath := ConfigApp.CONFIG_JSON_PATH

        if !FileExist(filePath) {
            throw Error("App config file not found:`n" filePath)
        }
        text := FileRead(filePath, "UTF-8")
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)

        root := JsonParse.Parse(text)
        if !(root is Map) {
            throw Error("configApp.json root must be a JSON object.")
        }

        ConfigApp.APP_NAME := ConfigApp.RequireNonEmptyString(root, "APP_NAME")
        ConfigApp.APP_VERSION := ConfigApp.RequireNonEmptyString(root, "APP_VERSION")
    }

    static RequireNonEmptyString(root, key) {
        if !root.Has(key) {
            throw Error("configApp.json missing required '" key "'.")
        }
        value := Trim(String(root[key]))
        if (value = "") {
            throw Error("configApp.json '" key "' must be a non-empty string.")
        }
        return value
    }

    ; e.g. ReCtrl (v1.0.2)
    static DisplayNameWithVersion() {
        return ConfigApp.APP_NAME " (v" ConfigApp.APP_VERSION ")"
    }
}
