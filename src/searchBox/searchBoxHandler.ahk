#Requires AutoHotkey v2

class SearchBoxHandler {
    guiInstance := ""
    menuRoot := []
    leafActions := []
    visibleActions := []
    recentActionIds := []
    menuStack := []
    isBrowsing := false
    recentLimit := 0

    __New(guiInstance) {
        this.guiInstance := guiInstance
        this.LoadMenuTree()
        this.SetupHandlers()
    }

    LoadMenuTree() {
        try {
            loaded := SearchActionsLoader.LoadFromFile()
            this.menuRoot := loaded["searchOptions"]
            this.recentLimit := loaded["searchConfig"]["DEFAULT_RECENT_LIMIT"]
            AppContext.ApplySearchConfig(loaded["searchConfig"])
            this.leafActions := SearchActionsLoader.FlattenLeaves(this.menuRoot)
        } catch as err {
            this.menuRoot := []
            this.leafActions := []
            this.recentLimit := 0
            detail := err.Message
            try detail .= "`n(" err.What " @ line " err.Line ")"
            this.ShowOwnedMessage(
                "Failed to load searchActions.json:`n" detail "`n`nPath:`n" SearchActionsConfig.ACTIONS_JSON_PATH,
                ConfigAppSettings.APP_NAME
            )
        }
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

        ; Typing leaves browse mode; search flattened leaf actions.
        this.ExitBrowseMode()
        results := []
        leafActionsTemp := this.leafActions
        if AppContext.GetSearchConfigFlag("TYPING_RESPECTS_CONTEXT") {
            this.RefreshContextBeforeFilter()
            leafActionsTemp := SearchActionsLoader.FilterByActiveContext(this.leafActions)
        }
        for action in leafActionsTemp {
            if this.IsActionMatch(query, action) {
                results.Push(action)
            }
        }
        this.visibleActions := results
        this.guiInstance.SetSuggestionOptions(this.BuildOptionLabels(results), 1)
    }

    ShowRecentSuggestions() {
        this.ExitBrowseMode()
        recent := this.GetRecentActions()
        if AppContext.GetSearchConfigFlag("RECENTS_RESPECTS_CONTEXT") {
            this.RefreshContextBeforeFilter()
            recent := SearchActionsLoader.FilterByActiveContext(recent)
        }
        this.visibleActions := recent
        this.guiInstance.SetSuggestionOptions(this.BuildOptionLabels(recent), 1)
    }

    ; Ctrl+Enter: show first-level items from JSON only (context-filtered when enabled).
    ShowAllSuggestions() {
        this.isBrowsing := true
        this.menuStack := []
        this.ShowMenuLevel(this.menuRoot)
    }

    ShowMenuLevel(nodes) {
        this.RefreshContextBeforeFilter()
        this.visibleActions := SearchActionsLoader.FilterByActiveContext(nodes)
        this.guiInstance.SetSuggestionOptions(this.BuildOptionLabels(this.visibleActions), 1)
    }

    ; Re-detect app under ReCtrl so menus don't stick to a closed/minimized window.
    RefreshContextBeforeFilter() {
        if !AppContext.IsEnabled()
            return
        ownerHwnd := 0
        try ownerHwnd := this.guiInstance.GetOwnerHwnd()
        AppContext.RefreshUnderlying(ownerHwnd)
    }

    DrillInto(node) {
        this.menuStack.Push(this.visibleActions)
        this.ShowMenuLevel(node["children"])
    }

    ; Returns true if navigated up one menu level.
    TryNavigateBack() {
        if !this.isBrowsing || this.menuStack.Length = 0
            return false
        previous := this.menuStack.Pop()
        this.ShowMenuLevel(previous)
        return true
    }

    ExitBrowseMode() {
        this.isBrowsing := false
        this.menuStack := []
    }

    BuildOptionLabels(actions) {
        labels := []
        for action in actions {
            label := action["label"]
            if SearchActionsLoader.IsSeparator(action) {
                labels.Push(label)
            } else {
                flagKey := this.ResolveSearchConfigFlagKey(action)
                if (flagKey != "") {
                    labels.Push(label " (" (AppContext.GetSearchConfigFlag(flagKey) ? "true" : "false") ")")
                } else if SearchActionsLoader.IsBranch(action) {
                    labels.Push(label "  >")
                } else if (action.Has("command") && action["command"] != "") {
                    labels.Push(label "  [" action["command"] "]")
                } else {
                    labels.Push(label)
                }
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
            if InStr(h, q)
                return true
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
        if this.TryNavigateBack()
            return
        this.ClearSuggestions()
    }

    ; Esc: up one level if browsing nested menu; else dismiss list.
    DismissOrNavigateBack() {
        if this.TryNavigateBack()
            return true
        if (this.visibleActions.Length > 0) {
            this.ClearSuggestions()
            return true
        }
        return false
    }

    ActivateSelectedOption(selectedIndex := 0) {
        if (selectedIndex <= 0) {
            selectedIndex := this.guiInstance.GetSelectedIndex()
        }
        if (selectedIndex <= 0 || selectedIndex > this.visibleActions.Length) {
            return
        }
        node := this.visibleActions[selectedIndex]
        if SearchActionsLoader.IsSeparator(node) {
            return
        }
        if SearchActionsLoader.IsBranch(node) {
            this.isBrowsing := true
            this.DrillInto(node)
            return
        }
        this.ExecuteAction(node)
    }

    ProcessSearch(searchText) {
        searchText := Trim(searchText)
        selectedIndex := this.guiInstance.GetSelectedIndex()
        if (selectedIndex > 0 && selectedIndex <= this.visibleActions.Length) {
            this.ActivateSelectedOption(selectedIndex)
            return
        }

        if (searchText = "") {
            this.ShowRecentSuggestions()
            return
        }
    }

    ClearSuggestions() {
        this.ExitBrowseMode()
        this.visibleActions := []
        this.guiInstance.SetSuggestionOptions([])
    }

    ExecuteAction(action) {
        this.MarkActionAsRecent(action["id"])
        actionType := this.ResolveActionType(action)
        result := ""

        if (actionType = "messageBox") {
            messageText := action.Has("message") ? action["message"] : action["label"]
            this.ShowOwnedMessage(messageText, ConfigAppSettings.APP_NAME)
        } else if (actionType = "showContext" || actionType = "toggleSearchConfig") {
            ownerHwnd := 0
            try ownerHwnd := this.guiInstance.GetOwnerHwnd()
            flagKey := this.ResolveSearchConfigFlagKey(action)
            if (flagKey = "")
                flagKey := "CONTEXT_ENABLED"
            result := AppContext.PromptToggleSearchConfigFlag(flagKey, ownerHwnd)
            this.ShowActionResult(result)
        } else if (actionType = "browserActions") {
            ownerHwnd := 0
            try ownerHwnd := this.guiInstance.GetOwnerHwnd()
            try {
                result := BrowserActions.Run(action, ownerHwnd)
                if !(IsObject(result) && result.Has("silent") && result["silent"])
                    this.ShowActionResult(result)
            } catch as err {
                this.ShowOwnedMessage(err.Message, ConfigAppSettings.APP_NAME " — Browser")
            }
        } else if (actionType = "desktopAppActions") {
            ownerHwnd := 0
            try ownerHwnd := this.guiInstance.GetOwnerHwnd()
            try {
                result := DesktopAppActions.Run(action, ownerHwnd)
                if !(IsObject(result) && result.Has("silent") && result["silent"])
                    this.ShowActionResult(result)
            } catch as err {
                this.ShowOwnedMessage(err.Message, ConfigAppSettings.APP_NAME " — Desktop App")
            }
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
        this.ClearSuggestions()
        if !this.ShouldKeepFocusOnTargetWindow(action)
            this.FocusOwner()
    }

    ; Bring ReCtrl back after an action that may have focused another window (browser, terminal, …).
    FocusOwner() {
        ownerHwnd := 0
        try ownerHwnd := this.guiInstance.GetOwnerHwnd()
        if ownerHwnd {
            try WinActivate("ahk_id " ownerHwnd)
        }
    }

    ; true = leave focus on target; false = FocusOwner (ReCtrl).
    ; Built-in default is always ReCtrl. Per-task focusThisWinIfMainOverideALlows
    ; is honored only when FOCUS_OVERRIDE_ALLOWED_BY_INDIVIDUAL_TASK is true.
    ShouldKeepFocusOnTargetWindow(menuItem) {
        if !AppContext.GetSearchConfigFlag("FOCUS_OVERRIDE_ALLOWED_BY_INDIVIDUAL_TASK")
            return false
        override := this.ResolveFocusThisWinIfMainOverideALlows(menuItem)
        if (override = "")
            return false
        return !!override
    }

    ; Explicit focusThisWinIfMainOverideALlows from nested action or top-level; "" if unset.
    ResolveFocusThisWinIfMainOverideALlows(menuItem) {
        if IsObject(menuItem) && menuItem.Has("action") && IsObject(menuItem["action"]) {
            nested := menuItem["action"]
            if nested.Has("focusThisWinIfMainOverideALlows")
                return !!nested["focusThisWinIfMainOverideALlows"]
        }
        if IsObject(menuItem) && menuItem.Has("focusThisWinIfMainOverideALlows")
            return !!menuItem["focusThisWinIfMainOverideALlows"]
        return ""
    }

    ; Prefer nested action.actionType (JSON-driven); fall back to top-level actionType.
    ResolveActionType(menuItem) {
        if IsObject(menuItem) && menuItem.Has("action") && IsObject(menuItem["action"]) {
            nested := menuItem["action"]
            if nested.Has("actionType") && Trim(String(nested["actionType"])) != ""
                return Trim(String(nested["actionType"]))
        }
        if menuItem.Has("actionType") && Trim(String(menuItem["actionType"])) != ""
            return Trim(String(menuItem["actionType"]))
        return "terminalCommand"
    }

    ; For toggleSearchConfig / showContext: which searchConfig flag to show/toggle.
    ResolveSearchConfigFlagKey(menuItem) {
        actionType := this.ResolveActionType(menuItem)
        if (actionType = "showContext")
            return "CONTEXT_ENABLED"
        if (actionType != "toggleSearchConfig")
            return ""
        if IsObject(menuItem) && menuItem.Has("action") && IsObject(menuItem["action"]) {
            nested := menuItem["action"]
            if nested.Has("key") && Trim(String(nested["key"])) != ""
                return Trim(String(nested["key"]))
        }
        if menuItem.Has("key") && Trim(String(menuItem["key"])) != ""
            return Trim(String(menuItem["key"]))
        return ""
    }

    ShowActionResult(result) {
        if !IsObject(result) {
            this.ShowResultFeedback("Action finished.", ConfigAppSettings.APP_NAME)
            return
        }
        title := result.Has("title") ? result["title"] : ConfigAppSettings.APP_NAME
        text := result.Has("message") ? result["message"] : "Done."
        this.ShowResultFeedback(text, title)
    }

    ; Route action result via ConfigAppSettings.FUNCTIONAL.NOTIFY.RESULT_FEEDBACK (popup vs toast).
    ShowResultFeedback(text, title := unset) {
        if !IsSet(title)
            title := ConfigAppSettings.APP_NAME
        ownerHwnd := 0
        try ownerHwnd := this.guiInstance.GetOwnerHwnd()
        Notify.Feedback(title, text, ownerHwnd)
    }

    ShowOwnedMessage(text, title := unset) {
        if !IsSet(title)
            title := ConfigAppSettings.APP_NAME
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
            if (nextRecent.Length >= this.recentLimit)
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
        for action in this.leafActions {
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
