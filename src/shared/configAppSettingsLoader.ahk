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
    ; Snapshot of view (WINDOW/HEADER/CONTENT) after Load — presets merge onto this.
    static baseViewMap := Map()
    static ACTIVE_PRESET := ""
    static viewPresets := Map()

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
        ConfigAppSettings.LoadViewPresetsFromView(view)

        ConfigAppSettings.WINDOW := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "WINDOW"))
        ConfigAppSettings.HEADER := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "HEADER"))
        ConfigAppSettings.CONTENT := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(view, "CONTENT"))
        ConfigAppSettings.TRANSPARENCY := ConfigAppSettings.WINDOW.TRANSPARENCY
        ; Base for preset overlays (show/hide patches only).
        ConfigAppSettings.baseViewMap := ConfigAppSettings.CloneMap(Map(
            "WINDOW", view["WINDOW"],
            "HEADER", view["HEADER"],
            "CONTENT", view["CONTENT"]
        ))

        functional := ConfigAppSettings.RequireMap(root, "functional")
        ConfigAppSettings.FUNCTIONAL := ConfigAppSettings.MapToObject(functional)

        ; Derived — not stored in JSON.
        ConfigAppSettings.WINDOW.TITLE := ConfigAppSettings.DisplayNameWithVersion()

        ; Apply ACTIVE_PRESET show/hide overlay before UI builds (no live refresh yet).
        if (ConfigAppSettings.ACTIVE_PRESET != "" && ConfigAppSettings.HasViewPreset(ConfigAppSettings.ACTIVE_PRESET))
            ConfigAppSettings.MergeViewPresetOntoBase(ConfigAppSettings.ACTIVE_PRESET)
    }

    ; view.VIEW_PRESETS — show/hide overlays only; removed from view before WINDOW/HEADER/CONTENT bind.
    static LoadViewPresetsFromView(view) {
        ConfigAppSettings.ACTIVE_PRESET := ""
        ConfigAppSettings.viewPresets := Map()
        if !view.Has("VIEW_PRESETS") || !(view["VIEW_PRESETS"] is Map)
            return
        presetsRoot := view["VIEW_PRESETS"]
        view.Delete("VIEW_PRESETS")
        if presetsRoot.Has("ACTIVE_PRESET")
            ConfigAppSettings.ACTIVE_PRESET := Trim(String(presetsRoot["ACTIVE_PRESET"]))
        if presetsRoot.Has("presets") && (presetsRoot["presets"] is Map)
            ConfigAppSettings.viewPresets := presetsRoot["presets"]
    }

    static HasViewPreset(presetId) {
        presetId := Trim(String(presetId))
        return presetId != "" && ConfigAppSettings.viewPresets.Has(presetId)
    }

    static GetViewPresetLabel(presetId) {
        presetId := Trim(String(presetId))
        if !ConfigAppSettings.HasViewPreset(presetId)
            return presetId
        node := ConfigAppSettings.viewPresets[presetId]
        if (node is Map) && node.Has("label") && Trim(String(node["label"])) != ""
            return Trim(String(node["label"]))
        return presetId
    }

    ; Deep-merge preset patch onto baseViewMap → WINDOW / HEADER / CONTENT.
    static MergeViewPresetOntoBase(presetId) {
        presetId := Trim(String(presetId))
        if !ConfigAppSettings.HasViewPreset(presetId)
            throw Error("Unknown app view preset: " presetId)

        node := ConfigAppSettings.viewPresets[presetId]
        if !(node is Map)
            throw Error("Preset '" presetId "' must be a JSON object.")

        patch := ConfigAppSettings.CloneMap(node)
        if patch.Has("label")
            patch.Delete("label")

        merged := ConfigAppSettings.DeepMergeMap(
            ConfigAppSettings.CloneMap(ConfigAppSettings.baseViewMap),
            patch
        )
        ConfigAppSettings.NormalizeViewAliases(merged)
        ConfigAppSettings.WINDOW := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(merged, "WINDOW"))
        ConfigAppSettings.HEADER := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(merged, "HEADER"))
        ConfigAppSettings.CONTENT := ConfigAppSettings.MapToObject(ConfigAppSettings.RequireMap(merged, "CONTENT"))
        ConfigAppSettings.TRANSPARENCY := ConfigAppSettings.WINDOW.TRANSPARENCY
        ConfigAppSettings.WINDOW.TITLE := ConfigAppSettings.DisplayNameWithVersion()
        ConfigAppSettings.ACTIVE_PRESET := presetId
    }

    ; Session apply from menu: merge + live UI refresh.
    static ApplyViewPreset(presetId) {
        ConfigAppSettings.MergeViewPresetOntoBase(presetId)
        ConfigAppSettings.ApplyViewPresetLive()

        return Map(
            "ok", true,
            "title", ConfigAppSettings.APP_NAME " — App view",
            "message", "Preset: " ConfigAppSettings.GetViewPresetLabel(presetId)
                . "`n`nShow/hide overlay applied for this session."
        )
    }

    static ApplyViewPresetLive() {
        try {
            global mainAppInstance
            if !IsSet(mainAppInstance) || !mainAppInstance.container
                return
            container := mainAppInstance.container
            ; Chip bar may not exist yet (e.g. started as minimalist).
            if container.content
                container.content.ApplyChipBarVisibility()
            container.ApplyHeaderVisibility()
            if container.content && container.content.searchBox && container.content.searchBox.gui {
                sb := container.content.searchBox.gui
                sb.ApplyHighlightMatchedSearchTokenConfig()
                sb.ApplySearchEditColors()
            }
            if container.IsVisible() {
                container.gui.GetClientPos(, , &cw, &ch)
                container.OnSize(cw, ch)
            }
        }
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
                "CHIP_BAR", Map(
                    "SHOW", true,
                    "MARGIN_TOP", 0,
                    "HEIGHT", 22,
                    "GAP", 8,
                    "chips", [
                        Map("id", "context", "type", "context", "SHOW", true, "label", "Context"),
                        Map("id", "temp1", "type", "temp", "SHOW", false, "label", "Temp 1"),
                        Map("id", "temp2", "type", "temp", "SHOW", false, "label", "Temp 2")
                    ]
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

        ; CONTEXT_TOGGLE → CHIP_BAR (one-release alias).
        content := view.Has("CONTENT") && (view["CONTENT"] is Map) ? view["CONTENT"] : ""
        if (content is Map) {
            if content.Has("CONTEXT_TOGGLE") && !content.Has("CHIP_BAR") {
                old := content["CONTEXT_TOGGLE"]
                chipBar := Map(
                    "SHOW", true,
                    "MARGIN_TOP", 0,
                    "HEIGHT", 22,
                    "GAP", 8,
                    "chips", [
                        Map("id", "context", "type", "context", "SHOW", true, "label", "Context")
                    ]
                )
                if (old is Map) {
                    if old.Has("SHOW")
                        chipBar["SHOW"] := old["SHOW"]
                    if old.Has("MARGIN_TOP")
                        chipBar["MARGIN_TOP"] := old["MARGIN_TOP"]
                    if old.Has("HEIGHT")
                        chipBar["HEIGHT"] := old["HEIGHT"]
                }
                content["CHIP_BAR"] := chipBar
            }
            if content.Has("CONTEXT_TOGGLE")
                content.Delete("CONTEXT_TOGGLE")
        }
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

    ; Paths used by Settings → This app → App view toggles.
    static GetViewSettingEnabled(path) {
        path := Trim(String(path))
        switch path {
            case "HEADER.SHOW":
                return !!ConfigAppSettings.HEADER.SHOW
            case "HIGHLIGHT_MATCHED_TOKEN.SHOW":
                return ConfigAppSettings.IsShowFlagEnabled(
                    ConfigAppSettings.CONTENT.HIGHLIGHT_MATCHED_TOKEN.SHOW, true)
            default:
                throw Error("Unknown app view setting: " path)
        }
    }

    static SetViewSettingEnabled(path, enabled) {
        path := Trim(String(path))
        enabled := !!enabled
        switch path {
            case "HEADER.SHOW":
                ConfigAppSettings.HEADER.SHOW := enabled
            case "HIGHLIGHT_MATCHED_TOKEN.SHOW":
                ; Prefer "auto" when turning on (match-only strip); false when off.
                ConfigAppSettings.CONTENT.HIGHLIGHT_MATCHED_TOKEN.SHOW := enabled ? "auto" : false
            default:
                throw Error("Unknown app view setting: " path)
        }
        ConfigAppSettings.ApplyViewSettingLive(path)
    }

    ; Live apply for App view toggles.
    static ApplyViewSettingLive(path) {
        path := Trim(String(path))
        try {
            global mainAppInstance
            if !IsSet(mainAppInstance) || !mainAppInstance.container
                return
            container := mainAppInstance.container
            if (path = "HEADER.SHOW") {
                container.ApplyHeaderVisibility()
                return
            }
            if (path = "HIGHLIGHT_MATCHED_TOKEN.SHOW") {
                if container.content && container.content.searchBox && container.content.searchBox.gui
                    container.content.searchBox.gui.ApplyHighlightMatchedSearchTokenConfig()
            }
        }
    }

    ; Session toggle (does not write JSON). Same confirm gate as searchConfig toggles.
    static PromptToggleViewSetting(path, ownerHwnd := 0) {
        path := Trim(String(path))
        current := ConfigAppSettings.GetViewSettingEnabled(path)
        currentText := current ? "true" : "false"
        nextText := current ? "false" : "true"
        label := path

        if ConfigAppSettings.FUNCTIONAL.NOTIFY.PROMPT_BEFORE_TOGGLE {
            prompt :=
                label ": " currentText "`n`n"
                . "Set it to " nextText " for this session?`n"
                . "(Resets to config/configAppSettings.json when you relaunch "
                . ConfigAppSettings.APP_NAME ".)"

            options := "YesNo"
            if ownerHwnd
                options .= " Owner" ownerHwnd

            answer := MsgBox(prompt, ConfigAppSettings.APP_NAME " — Settings", options)
            if (answer != "Yes") {
                return Map(
                    "ok", true,
                    "title", ConfigAppSettings.APP_NAME " — Settings",
                    "message", label " left as " currentText
                )
            }
        }

        ConfigAppSettings.SetViewSettingEnabled(path, !current)
        nowText := ConfigAppSettings.GetViewSettingEnabled(path) ? "true" : "false"
        return Map(
            "ok", true,
            "title", ConfigAppSettings.APP_NAME " — Settings",
            "message", label " is now " nowText
                . "`n`nThis lasts until you relaunch " ConfigAppSettings.APP_NAME "."
        )
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
