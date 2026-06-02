; ===== MainSearchBox GUI Native Module =====
; Handles the visual presentation using native AHK GUI controls

#Requires AutoHotkey v2

/**
 * Creates and returns a styled GUI with a centered main searchbox
 * Uses native AHK GUI controls
 */
class MainSearchBoxGuiNative {
    gui := ""
    searchEdit := ""
    searchChangeCallback := ""  ; Callback function for search changes
    
    ; All styling constants organized in nested structure
    static _STYLES := {
        LAYOUT: {
            CONTENT_WIDTH: 540,
            MARGIN_X: 20,
            MARGIN_Y: 20,
            RIGHT_GAP: 2
        },
        CLOSE_BTN: {
            WIDTH: 20,
            HEIGHT: 20,
            COLOR: "0xAAAAAA",
            FONT_SIZE: "s14",
            TEXT: "✕"
        }
    }
    
    __New() {
        this.CreateGui()
    }
    
    /**
     * Creates the main GUI window with styling
     */
    CreateGui() {
        ; Create GUI with no title bar, border, and always on top
        this.gui := Gui("+AlwaysOnTop -Caption +Border", "ReCtrl Main Search")
        this.gui.Name := "ReCtrlMainSearchBox"  ; Unique name for HotIf context

        ; Dark theme
        this.gui.BackColor := "0xc3c3c3"
        this.gui.SetFont("s10", "Segoe UI")
        
        ; No margins - use absolute positioning
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        
        ; Calculate positions based on layout constants
        contentX := MainSearchBoxGuiNative._STYLES.LAYOUT.MARGIN_X
        contentY := MainSearchBoxGuiNative._STYLES.LAYOUT.MARGIN_Y + 30
        totalWidth := (2 * MainSearchBoxGuiNative._STYLES.LAYOUT.MARGIN_X) + MainSearchBoxGuiNative._STYLES.LAYOUT.CONTENT_WIDTH
        closeBtnX := totalWidth - MainSearchBoxGuiNative._STYLES.CLOSE_BTN.WIDTH - MainSearchBoxGuiNative._STYLES.LAYOUT.RIGHT_GAP
        
        ; Close button at top-right
        closeBtn := this.gui.Add("Text", 
            "x" closeBtnX " y2 w" MainSearchBoxGuiNative._STYLES.CLOSE_BTN.WIDTH " h" MainSearchBoxGuiNative._STYLES.CLOSE_BTN.HEIGHT " Border Center 0x200 c" MainSearchBoxGuiNative._STYLES.CLOSE_BTN.COLOR, 
            MainSearchBoxGuiNative._STYLES.CLOSE_BTN.TEXT)
        closeBtn.SetFont(MainSearchBoxGuiNative._STYLES.CLOSE_BTN.FONT_SIZE)
        closeBtn.OnEvent("Click", (*) => this.Hide())
        
        ; Search input field
        this.searchEdit := this.gui.Add("Edit", "x" contentX " y" contentY " w" MainSearchBoxGuiNative._STYLES.LAYOUT.CONTENT_WIDTH " h50 Background0x2D2D30 c0xFFFFFF")
        this.searchEdit.SetFont("s16", "Segoe UI")
        
        ; Bind events
        this.gui.OnEvent("Escape", (*) => this.Hide())
        this.searchEdit.OnEvent("Change", (ctrl, *) => this.OnSearchChange(ctrl))
        
        ; Set up Enter key submission callback
        this.searchEdit.OnEvent("Focus", (*) => this.OnFocus())
        this.searchEdit.OnEvent("LoseFocus", (*) => this.OnLoseFocus())
        
        return this.gui
    }
    
    /**
     * Called when search edit gets focus
     */
    OnFocus() {
        ; Will be used by hotkey context
    }
    
    /**
     * Called when search edit loses focus
     */
    OnLoseFocus() {
        ; Will be used by hotkey context
    }
    
    /**
     * Shows the GUI centered on screen
     */
    Show() {
        this.gui.Show("AutoSize Center")
        ; Focus the search box
        this.searchEdit.Focus()
    }
    
    /**
     * Hides the GUI
     */
    Hide() {
        this.gui.Hide()
    }
    
    /**
     * Toggles GUI visibility
     */
    Toggle() {
        if WinExist("ahk_id " this.gui.Hwnd) {
            this.Hide()
        } else {
            this.ClearSearch()
            this.Show()
        }
    }
    
    /**
     * Checks if the GUI is currently visible
     */
    IsVisible() {
        return WinExist("ahk_id " this.gui.Hwnd)
    }
    
    /**
     * Gets the GUI window ID
     */
    GetHwnd() {
        return this.gui.Hwnd
    }
    
    /**
     * Gets the current search text
     */
    GetSearchText() {
        return this.searchEdit.Value
    }
    
    /**
     * Clears the search field
     */
    ClearSearch() {
        this.searchEdit.Value := ""
    }
    
    /**
     * Sets the callback function for search text changes
     */
    SetSearchChangeCallback(callbackFunc) {
        this.searchChangeCallback := callbackFunc
    }
    
    /**
     * Event handler for search text changes
     * Calls the registered callback if available
     */
    OnSearchChange(ctrl) {
        if (this.searchChangeCallback) {
            this.searchChangeCallback.Call(ctrl)
        }
    }
}
