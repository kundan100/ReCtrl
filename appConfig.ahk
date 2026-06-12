; ===== App Configuration =====
; App-wide settings for ReCtrl

#Requires AutoHotkey v2

class AppColors {
    static BG_WINDOW := "0xC3C3C3"            ; Light gray: main app window background
    static BG_HEADER := "0xA1A1A1"            ; Medium gray: header bar background
    static BG_HEADER_CLOSE_BTN := "0xAAAAAA"  ; Gray: header close button background
    static BG_CONTENT := "0xFFFF00"           ; Yellow: content area background
}

class AppConfig {
    static WINDOW := {
        WIDTH: 600,
        HEIGHT: 120,
        TITLE: "ReCtrl",
        SHOW_TITLE_BAR: false,
        ALWAYS_ON_TOP: true,
        BG_COLOR: AppColors.BG_WINDOW
    }

    static HEADER := {
        HEIGHT: 28,
        PADDING_X: 1,
        BG_COLOR: AppColors.BG_HEADER,
        CLOSE_BTN: {
            WIDTH: 20,
            HEIGHT: 20,
            COLOR: AppColors.BG_HEADER_CLOSE_BTN,
            FONT_SIZE: "s14",
            TEXT: "✕"
        }
    }

    static CONTENT := {
        BG_COLOR: AppColors.BG_CONTENT,
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
