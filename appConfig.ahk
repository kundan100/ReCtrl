; ===== App Configuration =====
; App-wide settings for ReCtrl

#Requires AutoHotkey v2

class AppConfig {
    static WINDOW := {
        WIDTH: 600,
        HEIGHT: 120,
        TITLE: "ReCtrl",
        SHOW_TITLE_BAR: false,
        ALWAYS_ON_TOP: true,
        BG_COLOR: "0xC3C3C3"
    }

    static HEADER := {
        HEIGHT: 28,
        PADDING_X: 1,
        BG_COLOR: "0xA1A1A1",
        CLOSE_BTN: {
            WIDTH: 20,
            HEIGHT: 20,
            COLOR: "0xAAAAAA",
            FONT_SIZE: "s14",
            TEXT: "✕"
        }
    }

    static CONTENT := {
        BG_COLOR: "0xFFFF00",
        DUMMY_TEXT: "" ; "Placeholder — content area"
    }

    ; Native window transparency behavior for the main app.
    ; - Uses WinSetTransparent on the top-level ReCtrl window only.
    ; - When focused, ACTIVE_ALPHA is used. When visible but unfocused, INACTIVE_ALPHA is used.
    ; - Alpha range: 0..255 (255 = fully opaque, 0 = fully transparent).
    ; - Keep INACTIVE_ALPHA high enough for readable text.
    static TRANSPARENCY := {
        ENABLED: true,          ; Master switch for focus-based transparency behavior
        ACTIVE_ALPHA: 245,      ; Opacity while ReCtrl window is focused/active
        INACTIVE_ALPHA: 190,    ; Opacity while ReCtrl is visible but not focused
        CHECK_INTERVAL_MS: 120  ; Focus polling interval (lower = faster updates, more CPU wakeups)
    }

    static AppHeaderHeight() {
        return AppConfig.WINDOW.SHOW_TITLE_BAR ? 0 : AppConfig.HEADER.HEIGHT
    }
}
