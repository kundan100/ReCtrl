; ===== MainSearchBox Configuration =====
; Configuration settings for the main searchbox feature

#Requires AutoHotkey v2

/**
 * MainSearchBox configuration class
 * Centralizes all configuration for the main searchbox feature
 */
class MainSearchBoxConfig {
    ; UI Mode: "HTML" or "NATIVE"
    ; HTML = Modern web-based UI with HTML/CSS/JS
    ; NATIVE = Traditional AHK GUI controls
    static UI_MODE := "HTML"  ; Default to HTML
    
    ; Window settings
    static WINDOW := {
        WIDTH: 600,
        HEIGHT: 120,
        ALWAYS_ON_TOP: true
    }
}
