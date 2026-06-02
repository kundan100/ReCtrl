; ===== MainSearchBox GUI HTML Module =====
; HTML/CSS/JS-based UI using WebView2

#Requires AutoHotkey v2

/**
 * MainSearchBox GUI using WebView2 (Edge Chromium)
 * Provides modern HTML/CSS/JS-based interface
 */
class MainSearchBoxGuiHtml {
    gui := ""
    webView := ""
    searchChangeCallback := ""
    htmlPath := ""
    
    __New() {
        this.htmlPath := A_ScriptDir "\src\mainSearchBox\guiHtml\ui\index.html"
        this.CreateGui()
    }
    
    ; Styling constants
    static _STYLES := {
        LAYOUT: {
            CONTENT_WIDTH: 560,
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
    
    /**
     * Creates the WebView2-based GUI
     */
    CreateGui() {
        ; Create GUI window with border
        this.gui := Gui("+AlwaysOnTop -Caption +Border", "ReCtrl Main Search")
        this.gui.Name := "ReCtrlMainSearchBox"
        this.gui.BackColor := "0x1E1E1E"
        
        ; No margins - use absolute positioning
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        
        ; Calculate positions based on layout constants
        contentX := MainSearchBoxGuiHtml._STYLES.LAYOUT.MARGIN_X
        contentY := MainSearchBoxGuiHtml._STYLES.LAYOUT.MARGIN_Y + 30
        totalWidth := (2 * MainSearchBoxGuiHtml._STYLES.LAYOUT.MARGIN_X) + MainSearchBoxGuiHtml._STYLES.LAYOUT.CONTENT_WIDTH
        closeBtnX := totalWidth - MainSearchBoxGuiHtml._STYLES.CLOSE_BTN.WIDTH - MainSearchBoxGuiHtml._STYLES.LAYOUT.RIGHT_GAP
        
        ; Close button at top-right
        closeBtn := this.gui.Add("Text", 
            "x" closeBtnX " y2 w" MainSearchBoxGuiHtml._STYLES.CLOSE_BTN.WIDTH " h" MainSearchBoxGuiHtml._STYLES.CLOSE_BTN.HEIGHT " Border Center 0x200 c" MainSearchBoxGuiHtml._STYLES.CLOSE_BTN.COLOR, 
            MainSearchBoxGuiHtml._STYLES.CLOSE_BTN.TEXT)
        closeBtn.SetFont(MainSearchBoxGuiHtml._STYLES.CLOSE_BTN.FONT_SIZE)
        closeBtn.OnEvent("Click", (*) => this.Hide())
        
        ; Add HTML control for search input
        this.webView := this.gui.Add("ActiveX", "x" contentX " y" contentY " w" MainSearchBoxGuiHtml._STYLES.LAYOUT.CONTENT_WIDTH " h80", "Shell.Explorer")
        this.webView.value.Navigate("file:///" StrReplace(this.htmlPath, "\\", "/"))
        
        ; Wait for page to load
        while (this.webView.value.readyState != 4) {
            Sleep(50)
        }
        
        ; Bind ESC key to close
        this.gui.OnEvent("Escape", (*) => this.Hide())
        
        return this.gui
    }
    
    /**
     * Sets up two-way communication between AHK and HTML
     */
    SetupWebViewCommunication() {
        ; This requires WebView2, for now using basic navigation
        ; Future: Implement proper WebView2 CoreWebView2 if needed
    }
    
    /**
     * Shows the GUI centered on screen
     */
    Show() {
        this.gui.Show("AutoSize Center")
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
        ; Would need WebView2 communication to get value from HTML
        return ""
    }
    
    /**
     * Clears the search field
     */
    ClearSearch() {
        ; Execute JavaScript in WebView to clear input
        try {
            this.webView.value.document.parentWindow.clearSearch()
        }
    }
    
    /**
     * Sets the callback function for search text changes
     */
    SetSearchChangeCallback(callbackFunc) {
        this.searchChangeCallback := callbackFunc
    }
    
    /**
     * Dummy methods for compatibility with native GUI interface
     */
    OnSearchChange(ctrl) {
        if (this.searchChangeCallback) {
            this.searchChangeCallback.Call(ctrl)
        }
    }
    
    OnFocus() {
        ; Compatibility stub
    }
    
    OnLoseFocus() {
        ; Compatibility stub
    }
}
