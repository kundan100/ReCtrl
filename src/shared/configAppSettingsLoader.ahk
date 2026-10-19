#Requires AutoHotkey v2

; Loads config/configAppSettings.json (info / view / functional).
; JSON Maps are converted to objects so call sites use cfg.HEIGHT (not cfg["HEIGHT"]).
; View: ConfigAppSettings.WINDOW.ALWAYS_ON_TOP
; Notify: ConfigAppSettings.FUNCTIONAL.NOTIFY.RESULT_FEEDBACK
; WINDOW.TITLE is derived (not stored in JSON).
; User JSON is deep-merged over ViewDefaults(); omitted keys keep defaults.
class ConfigAppSettings {
    static CONFIG_JSON_PATH := A_ScriptDir "\config\configAppSettings.json"

    static APP_NAME := ""
    static APP_VERSION := ""
    static INFO := {}
    static WINDOW := {}
    static HEADER := {}
    static CONTENT := {}
    ; Convenience alias of WINDOW.TRANSPARENCY after Load().
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
        ConfigAppSettings.NormalizeViewAliases(view)
        view := ConfigAppSettings.DeepMergeMap(ConfigAppSettings.ViewDefaults(), view)

        ConfigAppSettings.WINDOW := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "WINDOW"))
        ConfigAppSettings.HEADER := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "HEADER"))
        ConfigAppSettings.CONTENT := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "CONTENT"))
        ConfigAppSettings.TRANSPARENCY := ConfigAppSettings.WINDOW.TRANSPARENCY

        functional := ConfigAppSettings.RequireMap(root, "functional")
        ConfigAppSettings.FUNCTIONAL := ConfigAppSettings.MapToObject(functional)

        ; Derived — not stored in JSON.
        ConfigAppSettings.WINDOW.TITLE := ConfigAppSettings.DisplayNameWithVersion()
    }

    ; Built-in view defaults (user JSON overlays these).
    static ViewDefaults() {
        return Map(
            "WINDOW", Map(
                "WIDTH", 600,
                "HEIGHT", 70,
                "BG_COLOR", "0xC3C3C3",
                "ALWAYS_ON_TOP", true,
                "USE_NATIVE_TITLE_BAR", false,
                "DROP_SHADOW", Map(
                    "SHOW", false,
                    "STYLE", "dwm"
                ),
                "TRANSPARENCY", Map(
                    "ENABLED", true,
                    "ACTIVE_ALPHA", 255,
                    "INACTIVE_ALPHA", 100,
                    "CHECK_INTERVAL_MS", 120
                )
            ),
            "HEADER", Map(
                "SHOW", true,
                "WIDTH", "100%",
                "HEIGHT", 28,
                "PADDING_X", 1,
                "PADDING_Y", 0,
                "BG_COLOR", "0xA1A1A1",
                "ICON", Map(
                    "SHOW", true,
                    "PATH", "assets/appIcon/favicon_io/favicon.ico",
                    "WIDTH", 16,
                    "HEIGHT", 16,
                    "GAP", 6
                ),
                "TITLE", Map(
                    "SHOW", true,
                    "TEXT", "",
                    "FONT", "s10",
                    "FONT_NAME", "Segoe UI",
                    "COLOR", ""
                ),
                "CLOSE_BTN", Map(
                    "SHOW", true,
                    "WIDTH", 20,
                    "HEIGHT", 20,
                    "COLOR", "0xAAAAAA",
                    "FONT_SIZE", "s14",
                    "TEXT", "✕"
                )
            ),
            "CONTENT", Map(
                "SHOW", true,
                "WIDTH", "100%",
                "BG_COLOR", "0xFFFF00",
                "PADDING_X", 20,
                "PADDING_Y", 8,
                "DUMMY_TEXT", "",
                "CONTEXT_TOGGLE", Map(
                    "SHOW", true,
                    "MARGIN_TOP", 0,
                    "HEIGHT", 20
                ),
                "SEARCH_BOX", Map(
                    "SHOW", true,
                    "MARGIN_TOP", 4,
                    "MAX_WIDTH", 0,
                    "HEIGHT", 32,
                    "BG_COLOR", "0xE3F2FD",
                    "TEXT_COLOR", "0x000000"
                ),
                "OPTIONS_LIST", Map(
                    "SHOW", "auto",
                    "MARGIN_TOP", 4,
                    "MARGIN_BOTTOM", 0,
                    "ITEM_HEIGHT", 22,
                    "MAX_VISIBLE_COUNT", 10,
                    "HEIGHT_PADDING", 0,
                    "MIN_EXTRA_HEIGHT", 0
                ),
                "HIGHLIGHT_MATCHED_TOKEN", Map(
                    "SHOW", "auto",
                    "MARGIN_TOP", 2,
                    "HEIGHT", 20,
                    "BG_COLOR", "0xFFFF00",
                    "TEXT_COLOR", "0x000000",
                    "BLANK_LIST", Map(
                        "SHOW", true,
                        "RECENTS_TEXT", "Enter → recent actions",
                        "MENU_TEXT", "Ctrl+Enter → full menu · Esc / Backspace goes up"
                    )
                )
            )
        )
    }

    ; One-release aliases: SHOW_TITLE_BAR → USE_NATIVE_TITLE_BAR; top-level TRANSPARENCY → WINDOW.TRANSPARENCY.
    static NormalizeViewAliases(view) {
        if !(view is Map)
            return

        window := view.Has("WINDOW") && (view["WINDOW"] is Map) ? view["WINDOW"] : Map()
        if !view.Has("WINDOW") || !(view["WINDOW"] is Map)
            view["WINDOW"] := window

        if window.Has("SHOW_TITLE_BAR") && !window.Has("USE_NATIVE_TITLE_BAR")
            window["USE_NATIVE_TITLE_BAR"] := !!window["SHOW_TITLE_BAR"]
        if window.Has("SHOW_TITLE_BAR")
            window.Delete("SHOW_TITLE_BAR")

        ; DROP_SHADOW: true/false → object (off unless explicitly true → dwm).
        if window.Has("DROP_SHADOW") && !(window["DROP_SHADOW"] is Map) {
            window["DROP_SHADOW"] := Map(
                "SHOW", !!window["DROP_SHADOW"],
                "STYLE", "dwm"
            )
        }

        if view.Has("TRANSPARENCY") && (view["TRANSPARENCY"] is Map) {
            if !window.Has("TRANSPARENCY") || !(window["TRANSPARENCY"] is Map)
                window["TRANSPARENCY"] := view["TRANSPARENCY"]
            else
                window["TRANSPARENCY"] := ConfigAppSettings.DeepMergeMap(view["TRANSPARENCY"], window["TRANSPARENCY"])
            view.Delete("TRANSPARENCY")
        }

        header := view.Has("HEADER") && (view["HEADER"] is Map) ? view["HEADER"] : Map()
        if !view.Has("HEADER") || !(view["HEADER"] is Map)
            view["HEADER"] := header
        if !header.Has("SHOW") && window.Has("USE_NATIVE_TITLE_BAR")
            header["SHOW"] := !window["USE_NATIVE_TITLE_BAR"]
    }

    ; Deep-merge: override values win; nested Maps merge recursively. Arrays replace.
    static DeepMergeMap(base, override) {
        if !(base is Map)
            base := Map()
        if !(override is Map)
            return ConfigAppSettings.CloneMap(base)

        out := ConfigAppSettings.CloneMap(base)
        for key, value in override {
            if (value is Map) && out.Has(key) && (out[key] is Map)
                out[key] := ConfigAppSettings.DeepMergeMap(out[key], value)
            else if (value is Map)
                out[key] := ConfigAppSettings.CloneMap(value)
            else if (value is Array)
                out[key] := value.Clone()
            else
                out[key] := value
        }
        return out
    }

    static CloneMap(src) {
        if !(src is Map)
            return src
        out := Map()
        for key, value in src {
            if (value is Map)
                out[key] := ConfigAppSettings.CloneMap(value)
            else if (value is Array)
                out[key] := value.Clone()
            else
                out[key] := value
        }
        return out
    }

    ; e.g. ReCtrl (v2.0.0)
    static DisplayNameWithVersion() {
        return ConfigAppSettings.APP_NAME " (v" ConfigAppSettings.APP_VERSION ")"
    }

    ; Read APP_VERSION from disk without changing in-memory settings (for reload check).
    static ReadDiskAppVersion(filePath := unset) {
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
        return ConfigAppSettings.RequireNonEmptyString(infoMap, "APP_VERSION")
    }

    static ShouldShowCustomHeader() {
        return ConfigAppSettings.HEADER.SHOW && !ConfigAppSettings.WINDOW.USE_NATIVE_TITLE_BAR
    }

    static AppHeaderHeight() {
        return ConfigAppSettings.ShouldShowCustomHeader() ? ConfigAppSettings.HEADER.HEIGHT : 0
    }

    ; Resolve HEADER.ICON.PATH relative to script dir when not absolute.
    static ResolveAssetPath(path) {
        path := Trim(String(path))
        if (path = "")
            return ""
        if RegExMatch(path, "i)^[a-z]:\\") || SubStr(path, 1, 2) = "\\"
            return path
        path := StrReplace(path, "/", "\")
        if SubStr(path, 1, 1) = "\"
            return A_ScriptDir path
        return A_ScriptDir "\" path
    }

    ; Header title: TITLE.TEXT if set, else derived WINDOW.TITLE.
    static HeaderTitleText() {
        titleCfg := ConfigAppSettings.HEADER.TITLE
        custom := Trim(String(titleCfg.TEXT))
        return custom != "" ? custom : ConfigAppSettings.WINDOW.TITLE
    }

    ; SHOW: false/"false"/"off" → disabled; "auto"/true/other → enabled
    static IsShowFlagEnabled(showValue, defaultOn := true) {
        if !IsSet(showValue)
            return defaultOn
        if (showValue = false || showValue = 0)
            return false
        s := StrLower(Trim(String(showValue)))
        if (s = "false" || s = "off" || s = "0" || s = "no")
            return false
        return true
    }

    static OptionsListEnabled() {
        try return ConfigAppSettings.IsShowFlagEnabled(ConfigAppSettings.CONTENT.OPTIONS_LIST.SHOW, true)
        catch
            return true
    }

    static OptionsListInt(key, fallback) {
        try {
            cfg := ConfigAppSettings.CONTENT.OPTIONS_LIST
            if !cfg.HasOwnProp(key)
                return fallback
            return Integer(cfg.%key%)
        } catch
            return fallback
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
