#Requires AutoHotkey v2

class SearchActionsConfig {
    ; Maximum recent actions shown when query is empty.
    static RECENT_LIMIT := 10

    ; Available actions for search suggestions and execution.
    static ACTIONS := [
        Map(
            "id", "run-pater",
            "label", "Run pater command",
            "actionType", "terminalCommand",
            "command", "pater",
            "keywords", ["pater", "npm", "package", "tooling", "command"]
        ),
        Map(
            "id", "temporary-message",
            "label", "temporary",
            "actionType", "messageBox",
            "message", "temporary",
            "keywords", ["temporary", "temp", "demo"]
        ),
        Map(
            "id", "temporary2-message",
            "label", "temporary2",
            "actionType", "messageBox",
            "message", "temporary2",
            "keywords", ["temporary2", "temp", "demo"]
        ),
        Map(
            "id", "temporary3-message",
            "label", "temporary3",
            "actionType", "messageBox",
            "message", "temporary3",
            "keywords", ["temporary3", "temp", "demo"]
        ),
        Map(
            "id", "temporary4-message",
            "label", "temporary4",
            "actionType", "messageBox",
            "message", "temporary4",
            "keywords", ["temporary4", "temp", "demo"]
        ),
        Map(
            "id", "temporary5-message",
            "label", "temporary5",
            "actionType", "messageBox",
            "message", "temporary5",
            "keywords", ["temporary5", "temp", "demo"]
        ),
        Map(
            "id", "clipboard-create-file",
            "label", "create clipboard file",
            "actionType", "clipboardWriteText",
            "keywords", ["clipboard", "create", "save", "text", "file", "latest"]
        ),
        Map(
            "id", "clipboard-read-file",
            "label", "read clipboard file",
            "actionType", "clipboardReadText",
            "keywords", ["clipboard", "read", "load", "text", "file", "latest"]
        )
    ]
}
