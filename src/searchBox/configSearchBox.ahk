; ===== Configuration for searchBox =====

#Requires AutoHotkey v2

/**
 * searchBox configuration class
 * Centralizes all configuration for the searchbox feature
 */
class SearchBoxConfig {
    ; UI Mode: "NATIVE" or "HTML"
    ; NATIVE = Traditional AHK GUI controls
    ; HTML = Modern web-based UI with HTML/CSS/JS
    ; "HTML" mode will be built later
    static UI_MODE := "NATIVE" ; Default to NATIVE
}

class NativeUiConfig {
    ; Controls whether a visible submit button is rendered next to the input.
    ; Enter key submission works in both modes.
    static SHOW_SUBMIT_BUTTON := false

    ; Native submit button styling/layout (used when SHOW_SUBMIT_BUTTON = true)
    static SUBMIT_BUTTON_TEXT := "Search"
    ; Width is auto-sized from button text. This is only a lower bound.
    static SUBMIT_BUTTON_MIN_WIDTH := 20
    static SUBMIT_BUTTON_GAP := 5
    static SEARCH_INPUT_HEIGHT := 32
    static SEARCH_PLACEHOLDER_TEXT := "Type to search... (Enter=Recent, Ctrl+Enter=All)"
    static SEARCH_PLACEHOLDER_SHOW_WHEN_FOCUSED := true
    static SUGGESTION_LIST_GAP := 4
    static SUGGESTION_BOTTOM_GAP := 0
    static SUGGESTION_LIST_HEIGHT_PADDING := 0
    static SUGGESTION_LIST_MIN_EXTRA_HEIGHT := 0
    static SUGGESTION_ITEM_HEIGHT := 22
    static SUGGESTION_MAX_VISIBLE_COUNT := 10
}
