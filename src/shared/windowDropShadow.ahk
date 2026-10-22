#Requires AutoHotkey v2

; Optional window elevation hint.
; Soft multi-Gui “shadow” layers were removed — they read as a broken duplicate window
; in native AHK (hard rects, no real blur). True soft shadow needs HTML/WebView or a PNG.
;
; STYLE "dwm": optional OS edge (often border-like on Win10/11). Off by default.
; Config: ConfigAppSettings.WINDOW.DROP_SHADOW
class WindowDropShadow {
    static hostHwnd := 0

    static Apply(hwnd) {
        WindowDropShadow.CleanupSoftArtifacts()
        if !hwnd || !WindowDropShadow.IsEnabled()
            return

        cfg := WindowDropShadow.Cfg()
        style := StrLower(Trim(String(cfg.STYLE)))
        if (style = "dwm")
            WindowDropShadow.ApplyDwmDropShadow(hwnd)
    }

    static Hide() {
        WindowDropShadow.CleanupSoftArtifacts()
    }

    static Sync(*) {
        ; No soft layers to track.
    }

    static IsEnabled() {
        try {
            cfg := ConfigAppSettings.WINDOW.DROP_SHADOW
            if !IsObject(cfg)
                return !!cfg
            return ConfigAppSettings.IsShowFlagEnabled(cfg.SHOW, false)
        } catch
            return false
    }

    static Cfg() {
        return ConfigAppSettings.WINDOW.DROP_SHADOW
    }

    static CleanupSoftArtifacts() {
        WindowDropShadow.hostHwnd := 0
    }

    static ApplyDwmDropShadow(hwnd) {
        dwmEnabled := 0
        try DllCall("dwmapi\DwmIsCompositionEnabled", "Int*", &dwmEnabled)
        if !dwmEnabled {
            try {
                style := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -26, "Ptr")
                if !(style & 0x20000)
                    DllCall("SetClassLongPtr", "Ptr", hwnd, "Int", -26, "Ptr", style | 0x20000)
            }
            return
        }
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 2, "Int*", 2, "UInt", 4)
        margins := Buffer(16, 0)
        NumPut("Int", 1, "Int", 1, "Int", 1, "Int", 1, margins)
        try DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", hwnd, "Ptr", margins)
        try DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x37)
    }
}
