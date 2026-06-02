; ===== MainSearchBox Handler Module =====
; Handles business logic and event processing for the main searchbox

#Requires AutoHotkey v2

/**
 * Handles main searchbox events and business logic
 * Separates logic from presentation
 */
class MainSearchBoxHandler {
    guiInstance := ""
    
    __New(guiInstance) {
        this.guiInstance := guiInstance
        this.SetupHandlers()
    }
    
    /**
     * Sets up event handlers
     */
    SetupHandlers() {
        ; Register the search change callback
        this.guiInstance.SetSearchChangeCallback((ctrl) => this.HandleSearchChange(ctrl))
    }
    
    /**
     * Handles search text changes
     * @param ctrl - The Edit control that changed
     */
    HandleSearchChange(ctrl) {
        searchText := ctrl.Value
        
        ; Future: Implement search logic here
        ; For now, just log to OutputDebug (can be viewed with DebugView)
        if (searchText != "") {
            OutputDebug("ReCtrl Search: " searchText)
        }
        
        ; Future enhancements:
        ; - File search
        ; - Application launcher
        ; - Command execution
        ; - Web search
    }
    
    /**
     * Processes the current search (when Enter is pressed)
     */
    ProcessSearch() {
        searchText := this.guiInstance.GetSearchText()
        
        if (searchText = "") {
            return
        }
        
        ; Future: Implement search execution logic
        MsgBox("Search functionality coming soon!`nYou searched for: " searchText)
        
        this.guiInstance.Hide()
        this.guiInstance.ClearSearch()
    }
}
