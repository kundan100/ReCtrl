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

    static AppHeaderHeight() {
        return AppConfig.WINDOW.SHOW_TITLE_BAR ? 0 : AppConfig.HEADER.HEIGHT
    }
}
