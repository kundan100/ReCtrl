#Requires AutoHotkey v2

class SearchBoxHandler {
    guiInstance := ""

    __New(guiInstance) {
        this.guiInstance := guiInstance
        this.SetupHandlers()
    }

    SetupHandlers() {
        this.guiInstance.SetSubmitCallback((searchText) => this.ProcessSearch(searchText))
    }

    ProcessSearch(searchText) {
        if (searchText = "") {
            return
        }

        ownerHwnd := 0
        try ownerHwnd := this.guiInstance.GetOwnerHwnd()

        if (ownerHwnd) {
            MsgBox(
                "Search functionality coming soon!`nYou searched for: " searchText,
                "ReCtrl Search",
                "Owner" ownerHwnd
            )
        } else {
            MsgBox("Search functionality coming soon!`nYou searched for: " searchText)
        }

        this.guiInstance.ClearSearch()
        this.guiInstance.Hide()
    }
}
