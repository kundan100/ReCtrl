; ===== MainSearchBox Module =====
; Main orchestrator for the main searchbox feature
; Coordinates GUI and handler components

#Requires AutoHotkey v2

; Include configuration
#Include config.ahk

; Include GUI implementations
#Include guiNative\mainSearchBoxGuiNative.ahk
#Include guiHtml\mainSearchBoxGuiHtml.ahk

; Include handler
#Include mainSearchBoxHandler.ahk

/**
 * Main MainSearchBox class that orchestrates the feature
 * Uses factory pattern to choose GUI implementation
 */
class MainSearchBox {
    gui := ""
    handler := ""
    
    __New() {
        this.Initialize()
    }
    
    /**
     * Initializes the main searchbox feature
     * Chooses GUI based on configuration
     */
    Initialize() {
        ; Create GUI instance based on config
        if (MainSearchBoxConfig.UI_MODE = "HTML") {
            this.gui := MainSearchBoxGuiHtml()
        } else {
            this.gui := MainSearchBoxGuiNative()
        }
        
        ; Create handler instance
        this.handler := MainSearchBoxHandler(this.gui)
    }
    
    /**
     * Processes search when Enter is pressed
     */
    ProcessSearch() {
        this.handler.ProcessSearch()
    }
    
    /**
     * Shows the searchbox
     */
    Show() {
        this.gui.Show()
    }
    
    /**
     * Hides the searchbox
     */
    Hide() {
        this.gui.Hide()
    }
    
    /**
     * Toggles searchbox visibility
     */
    Toggle() {
        this.gui.Toggle()
    }
}

/**
 * Global function to show the main searchbox
 * Called by hotkey in ReCtrl.ahk
 */
ShowMainSearchBox() {
    global mainSearchBoxInstance
    mainSearchBoxInstance.Toggle()
}
