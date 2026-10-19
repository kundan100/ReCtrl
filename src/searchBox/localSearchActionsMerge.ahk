#Requires AutoHotkey v2

; In-memory overlay of localSearchActions.json onto repo searchActions root.
; Public API:
;   LocalSearchActionsMerge.Apply(root) → Map
; Local always wins. Missing/invalid local file → error toast, return repo root unchanged.
class LocalSearchActionsMerge {
    ; Read localConfig.LOCAL_SEARCH_ACTIONS_PATH, load twin JSON, deep-merge onto root.
    static Apply(root) {
        if !(root is Map)
            return root
        if !root.Has("localConfig") || !(root["localConfig"] is Map)
            return root
        localConfig := root["localConfig"]
        if !localConfig.Has("LOCAL_SEARCH_ACTIONS_PATH")
            return root

        localPath := LocalSearchActionsMerge.ExpandEnvPath(String(localConfig["LOCAL_SEARCH_ACTIONS_PATH"]))
        if (Trim(localPath) = "")
            return root

        if !FileExist(localPath) {
            LocalSearchActionsMerge.ToastLoadError(
                "Local search actions file not found:`n" localPath
            )
            return root
        }

        try {
            localText := FileRead(localPath, "UTF-8")
            if (SubStr(localText, 1, 1) = Chr(0xFEFF))
                localText := SubStr(localText, 2)
            localRoot := JsonParse.Parse(localText)
        } catch as err {
            LocalSearchActionsMerge.ToastLoadError(
                "Failed to load local search actions:`n" localPath "`n`n" err.Message
            )
            return root
        }

        if !(localRoot is Map) {
            LocalSearchActionsMerge.ToastLoadError(
                "Local search actions root must be a JSON object:`n" localPath
            )
            return root
        }

        return LocalSearchActionsMerge.DeepMerge(root, localRoot)
    }

    ; Deep merge Maps; node arrays (searchOptions / children) merge by id; other values: overlay wins.
    static DeepMerge(base, overlay) {
        if !(base is Map) || !(overlay is Map)
            return overlay

        result := Map()
        for key, value in base
            result[key] := value

        for key, overlayVal in overlay {
            if !result.Has(key) {
                result[key] := overlayVal
                continue
            }
            baseVal := result[key]
            if (baseVal is Map) && (overlayVal is Map) {
                result[key] := LocalSearchActionsMerge.DeepMerge(baseVal, overlayVal)
            } else if (baseVal is Array) && (overlayVal is Array)
                && LocalSearchActionsMerge.IsIdNodeArray(baseVal) {
                result[key] := LocalSearchActionsMerge.MergeNodeArrays(baseVal, overlayVal)
            } else {
                result[key] := overlayVal
            }
        }
        return result
    }

    static IsIdNodeArray(arr) {
        if !(arr is Array) || arr.Length = 0
            return false
        first := arr[1]
        return (first is Map) && first.Has("id")
    }

    ; Keep base order; deep-merge matching ids; append local-only ids.
    static MergeNodeArrays(baseArr, overlayArr) {
        out := []
        indexById := Map()
        for node in baseArr {
            out.Push(node)
            if (node is Map) && node.Has("id")
                indexById[String(node["id"])] := out.Length
        }

        for overlayNode in overlayArr {
            if !(overlayNode is Map) || !overlayNode.Has("id")
                continue
            id := String(overlayNode["id"])
            if indexById.Has(id) {
                idx := indexById[id]
                baseNode := out[idx]
                if (baseNode is Map)
                    out[idx] := LocalSearchActionsMerge.DeepMerge(baseNode, overlayNode)
                else
                    out[idx] := overlayNode
            } else {
                out.Push(overlayNode)
                indexById[id] := out.Length
            }
        }
        return out
    }

    static ExpandEnvPath(path) {
        path := Trim(path)
        if (path = "")
            return ""
        while RegExMatch(path, "%([^%]+)%", &m) {
            envVal := EnvGet(m[1])
            path := StrReplace(path, m[0], envVal)
        }
        return path
    }

    static ToastLoadError(message) {
        title := "ReCtrl"
        try title := ConfigAppSettings.APP_NAME
        try {
            Notify.Show(title, message, "error")
        } catch {
            try Notify.Feedback(title, message, 0, "error")
            catch {
                ; May run before Notify is available; avoid hard fail.
            }
        }
    }
}
