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
        ; Fallback height; Show() prefers header + content (search + optional context toggle).
        HEIGHT: 70,
        TITLE: ConfigApp.DisplayNameWithVersion(),
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

; Settings-toggle + toast notification UI gates (code constants; not written to JSON).
class NotifyConfig {
    ; When true: keep Yes/No MsgBox before flipping a searchConfig session flag.
    ; When false: flip immediately on option select (Yes/No code path stays in AppContext).
    static PROMPT_BEFORE_TOGGLE := false

    ; How to show the post-toggle / action result message:
    ;   "show-in-popup"        → owned MsgBox (existing)
    ;   "show-in-notification" → top-right toast via Notify.Show
    static RESULT_FEEDBACK := "show-in-notification"

    ; Auto-dismiss duration for toast notifications (ms).
    static TOAST_DURATION_MS := 10000

    static TOAST := {
        WIDTH: 320,
        MIN_HEIGHT: 72,
        MARGIN: 16,
        PADDING: 12,
        BG_COLOR: "0x2D2D30",
        TITLE_COLOR: "0xFFFFFF",
        BODY_COLOR: "0xD0D0D0",
        CLOSE_COLOR: "0xC8C8C8",
        TITLE_FONT: "s10 Bold",
        BODY_FONT: "s9",
        CLOSE_FONT: "s12"
    }
}
