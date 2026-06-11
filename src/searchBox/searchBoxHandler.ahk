#Requires AutoHotkey v2

class SearchBoxHandler {
    guiInstance := ""
    allActions := []
    visibleActions := []
    recentActionIds := []

    __New(guiInstance) {
        this.guiInstance := guiInstance
        this.allActions := SearchActionsConfig.ACTIONS
        this.SetupHandlers()
    }

    SetupHandlers() {
        this.guiInstance.SetSubmitCallback((searchText) => this.ProcessSearch(searchText))
        this.guiInstance.SetQueryChangeCallback((query) => this.UpdateSuggestions(query))
        this.guiInstance.SetInputFocusCallback((query) => this.OnInputFocus(query))
        this.guiInstance.SetOptionActivateCallback((selectedIndex) => this.ActivateSelectedOption(selectedIndex))
    }

    OnInputFocus(query) {
        if (Trim(query) = "") {
            this.ClearSuggestions()
            return
        }
        this.UpdateSuggestions(query)
    }

    UpdateSuggestions(query) {
        query := Trim(query)
        if (query = "") {
            this.ClearSuggestions()
            return
        }

        results := []
        for action in this.allActions {
            if this.IsActionMatch(query, action) {
                results.Push(action)
            }
        }
        this.visibleActions := results
        this.guiInstance.SetSuggestionOptions(this.BuildOptionLabels(results), 1)
    }

    ShowRecentSuggestions() {
        recent := this.GetRecentActions()
        this.visibleActions := recent
        this.guiInstance.SetSuggestionOptions(this.BuildOptionLabels(recent), 1)
    }

    ShowAllSuggestions() {
        all := []
        for action in this.allActions {
            all.Push(action)
        }
        this.visibleActions := all
        this.guiInstance.SetSuggestionOptions(this.BuildOptionLabels(all), 1)
    }

    BuildOptionLabels(actions) {
        labels := []
        for action in actions {
            if (action.Has("command") && action["command"] != "") {
                labels.Push(action["label"] "  [" action["command"] "]")
            } else {
                labels.Push(action["label"])
            }
        }
        return labels
    }

    IsActionMatch(query, action) {
        haystacks := [StrLower(action["label"])]
        if action.Has("command") {
            haystacks.Push(StrLower(action["command"]))
        }
        if action.Has("keywords") {
            for kw in action["keywords"] {
                haystacks.Push(StrLower(kw))
            }
        }

        q := StrLower(query)
        for h in haystacks {
            if InStr(h, q) || this.IsFuzzyMatch(q, h)
                return true
        }
        return false
    }

    IsFuzzyMatch(query, target) {
        qi := 1
        qLen := StrLen(query)
        if (qLen = 0)
            return true

        Loop Parse, target {
            if (SubStr(query, qi, 1) = A_LoopField) {
                qi += 1
                if (qi > qLen)
                    return true
            }
        }
        return false
    }

    MoveSelection(step) {
        return this.guiInstance.MoveSelection(step)
    }

    SubmitCurrent() {
        this.ProcessSearch(this.guiInstance.GetSearchText())
    }

    ShowAllOptionsShortcut() {
        this.ShowAllSuggestions()
    }

    OnEmptyEraseKey() {
        this.ClearSuggestions()
    }

    ActivateSelectedOption(selectedIndex := 0) {
        if (selectedIndex <= 0) {
            selectedIndex := this.guiInstance.GetSelectedIndex()
        }
        if (selectedIndex <= 0 || selectedIndex > this.visibleActions.Length) {
            return
        }
        this.ExecuteAction(this.visibleActions[selectedIndex])
    }

    ProcessSearch(searchText) {
        searchText := Trim(searchText)
        if (searchText = "") {
            this.ShowRecentSuggestions()
            return
        }

        selectedIndex := this.guiInstance.GetSelectedIndex()
        if (selectedIndex > 0 && selectedIndex <= this.visibleActions.Length) {
            this.ExecuteAction(this.visibleActions[selectedIndex])
            return
        }
    }

    ClearSuggestions() {
        this.visibleActions := []
        this.guiInstance.SetSuggestionOptions([])
    }

    ExecuteAction(action) {
        this.MarkActionAsRecent(action["id"])
        actionType := action.Has("actionType") ? action["actionType"] : "terminalCommand"

        if (actionType = "messageBox") {
            messageText := action.Has("message") ? action["message"] : action["label"]
            this.ShowOwnedMessage(messageText, "ReCtrl")
        } else if (actionType = "clipboardWriteText") {
            result := ClipboardActions.CreateClipboardFileFromText()
            this.ShowActionResult(result)
        } else if (actionType = "clipboardReadText") {
            result := ClipboardActions.LoadClipboardTextFromFile()
            this.ShowActionResult(result)
        } else {
            this.RunCommandInTerminal(action["command"])
        }
        this.guiInstance.ClearSearch()
    }

    ShowActionResult(result) {
        if !IsObject(result) {
            this.ShowOwnedMessage("Action finished.", "ReCtrl")
            return
        }
        title := result.Has("title") ? result["title"] : "ReCtrl"
        text := result.Has("message") ? result["message"] : "Done."
        this.ShowOwnedMessage(text, title)
    }

    ShowOwnedMessage(text, title := "ReCtrl") {
        ownerHwnd := 0
        try ownerHwnd := this.guiInstance.GetOwnerHwnd()
        if ownerHwnd {
            MsgBox(text, title, "Owner" ownerHwnd)
        } else {
            MsgBox(text, title)
        }
    }

    MarkActionAsRecent(actionId) {
        nextRecent := [actionId]
        for existingId in this.recentActionIds {
            if (existingId != actionId) {
                nextRecent.Push(existingId)
            }
            if (nextRecent.Length >= SearchActionsConfig.RECENT_LIMIT)
                break
        }
        this.recentActionIds := nextRecent
    }

    GetRecentActions() {
        results := []
        for recentId in this.recentActionIds {
            action := this.FindActionById(recentId)
            if IsObject(action) {
                results.Push(action)
            }
        }
        return results
    }

    FindActionById(actionId) {
        for action in this.allActions {
            if (action["id"] = actionId) {
                return action
            }
        }
        return ""
    }

    RunCommandInTerminal(command) {
        ownerHwnd := 0
        try ownerHwnd := this.guiInstance.GetOwnerHwnd()
        if ownerHwnd {
            WinActivate("ahk_id " ownerHwnd)
        }

        cmdLine := StrReplace(command, '"', '\"')
        try {
            Run('wt.exe new-tab cmd /k "' cmdLine '"')
        } catch {
            Run(A_ComSpec ' /k "' cmdLine '"')
        }
    }
}
