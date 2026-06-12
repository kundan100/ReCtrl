; ===== Main App Module =====
; Orchestrates the main application container

#Requires AutoHotkey v2

#Include ..\..\appConfig.ahk
#Include mainAppContainer.ahk

class MainApp {
    container := ""

    __New() {
        this.container := MainAppContainer()
    }

    Show() {
        this.container.Show()
    }

    Hide() {
        this.container.Hide()
    }

    Toggle() {
        this.container.Toggle()
    }

    Summon() {
        this.container.Summon()
    }
}

ShowMainApp() {
    global mainAppInstance
    mainAppInstance.Summon()
}
