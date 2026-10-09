#Requires AutoHotkey v2

class SearchActionsConfig {
    ; Path to user-editable JSON (relative to script root / index.ahk folder).
    ; Tunables like DEFAULT_RECENT_LIMIT live only in that JSON (searchConfig).
    static ACTIONS_JSON_PATH := A_ScriptDir "\config\searchActions.json"
}

class SearchActionsLoader {
    ; Load JSON object { searchConfig, searchOptions }.
    ; Returns Map("searchConfig", Map, "searchOptions", Array).
    static LoadFromFile(filePath := unset) {
        if !IsSet(filePath)
            filePath := SearchActionsConfig.ACTIONS_JSON_PATH

        if !FileExist(filePath) {
            throw Error("Search actions file not found:`n" filePath)
        }
        text := FileRead(filePath, "UTF-8")
        ; Strip UTF-8 BOM if present.
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)

        root := JsonParse.Parse(text)
        if !(root is Map) {
            throw Error("searchActions.json root must be a JSON object with searchConfig and searchOptions.")
        }
        if !root.Has("searchOptions") || !(root["searchOptions"] is Array) {
            throw Error("searchActions.json must contain a 'searchOptions' array.")
        }

        if !root.Has("searchConfig") {
            throw Error("searchActions.json must contain a 'searchConfig' object.")
        }
        searchConfig := SearchActionsLoader.NormalizeSearchConfig(root["searchConfig"])
        searchOptions := SearchActionsLoader.NormalizeNodes(root["searchOptions"])

        return Map(
            "searchConfig", searchConfig,
            "searchOptions", searchOptions
        )
    }

    static NormalizeSearchConfig(configNode) {
        if !(configNode is Map) {
            throw Error("searchActions.json must contain a 'searchConfig' object.")
        }
        if !configNode.Has("DEFAULT_RECENT_LIMIT") {
            throw Error("searchConfig.DEFAULT_RECENT_LIMIT is required in searchActions.json.")
        }
        if !configNode.Has("CONTEXT_ENABLED") {
            throw Error("searchConfig.CONTEXT_ENABLED is required in searchActions.json.")
        }

        config := Map()
        for key, value in configNode {
            config[key] := value
        }

        try {
            recentLimit := Integer(config["DEFAULT_RECENT_LIMIT"])
        } catch {
            throw Error("searchConfig.DEFAULT_RECENT_LIMIT must be a positive integer.")
        }
        if (recentLimit <= 0) {
            throw Error("searchConfig.DEFAULT_RECENT_LIMIT must be a positive integer.")
        }
        config["DEFAULT_RECENT_LIMIT"] := recentLimit
        config["CONTEXT_ENABLED"] := SearchActionsLoader.NormalizeBool(
            config["CONTEXT_ENABLED"],
            "searchConfig.CONTEXT_ENABLED"
        )
        return config
    }

    static NormalizeBool(value, fieldName) {
        if (value = true || value = 1)
            return true
        if (value = false || value = 0)
            return false
        if (value is String) {
            v := StrLower(Trim(value))
            if (v = "true" || v = "1")
                return true
            if (v = "false" || v = "0")
                return false
        }
        throw Error(fieldName " must be a boolean (true/false).")
    }

    static NormalizeNodes(nodes) {
        out := []
        for node in nodes {
            out.Push(SearchActionsLoader.NormalizeNode(node))
        }
        return out
    }

    static NormalizeNode(node) {
        if !(node is Map) {
            throw Error("Each menu item must be a JSON object.")
        }
        if !node.Has("id") || Trim(node["id"]) = "" {
            throw Error("Menu item missing required 'id'.")
        }

        if SearchActionsLoader.IsSeparator(node) {
            normalized := Map()
            for key, value in node {
                normalized[key] := value
            }
            normalized["itemType"] := "separator"
            if !normalized.Has("label") || Trim(normalized["label"]) = "" {
                normalized["label"] := "────────────"
            }
            return normalized
        }

        if !node.Has("label") || Trim(node["label"]) = "" {
            throw Error("Menu item missing required 'label': " node["id"])
        }

        normalized := Map()
        for key, value in node {
            if (key = "children") {
                continue
            }
            normalized[key] := value
        }

        if node.Has("context") {
            normalized["context"] := SearchActionsLoader.NormalizeContextList(
                node["context"],
                normalized["id"]
            )
        }

        if node.Has("children") && (node["children"] is Array) && node["children"].Length > 0 {
            normalized["children"] := SearchActionsLoader.NormalizeNodes(node["children"])
        }
        return normalized
    }

    static NormalizeContextList(contextValue, nodeId) {
        if !(contextValue is Array) {
            throw Error("Menu item '" nodeId "' field 'context' must be an array of strings.")
        }
        out := []
        for item in contextValue {
            text := StrLower(Trim(String(item)))
            if (text != "")
                out.Push(text)
        }
        return out
    }

    ; Flatten leaf nodes (no children) for typeahead search + recent lookup.
    static FlattenLeaves(nodes, results := unset) {
        if !IsSet(results)
            results := []
        for node in nodes {
            if SearchActionsLoader.IsSeparator(node) {
                continue
            }
            if SearchActionsLoader.IsBranch(node) {
                SearchActionsLoader.FlattenLeaves(node["children"], results)
            } else {
                results.Push(node)
            }
        }
        return results
    }

    ; When context filtering is on:
    ; - "context": [] (or missing) => always visible (context-independent)
    ; - "context": ["browser", ...] => only when current kind matches
    static FilterByActiveContext(nodes) {
        if !AppContext.IsEnabled() {
            return SearchActionsLoader.CloneNodeList(nodes)
        }
        kind := StrLower(Trim(AppContext.GetCurrentKind()))
        out := []
        for node in nodes {
            if SearchActionsLoader.IsVisibleForKind(node, kind)
                out.Push(node)
        }
        return out
    }

    static IsVisibleForKind(node, kind) {
        ; Empty context list = option is irrespective of specific app context.
        if !node.Has("context") || !(node["context"] is Array) || node["context"].Length = 0
            return true
        if (kind = "")
            return false
        for ctx in node["context"] {
            if (ctx = kind)
                return true
        }
        return false
    }

    static CloneNodeList(nodes) {
        out := []
        for node in nodes
            out.Push(node)
        return out
    }

    static IsSeparator(node) {
        return node.Has("itemType") && node["itemType"] = "separator"
    }

    static IsBranch(node) {
        if SearchActionsLoader.IsSeparator(node)
            return false
        return node.Has("children") && (node["children"] is Array) && node["children"].Length > 0
    }
}
