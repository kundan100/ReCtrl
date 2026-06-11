; ===== Current Window Info Module =====
; Retrieves and displays information about the active window

#Requires AutoHotkey v2

/**
 * Displays information about the currently active window
 * Shows: Exe name, Class name, Title, and HWND
 */
DisplayWindowInfo() {
	; Explicitly get the active window handle
	hwnd := WinExist("A")

	; return if no active window
	if !hwnd {
		MsgBox("No active window detected.")
		return
	}

	; get current window details
	className := WinGetClass(hwnd)
	title := WinGetTitle(hwnd)
	exeName := WinGetProcessName(hwnd)

	MsgBox("Exe: " exeName "`nClass: " className "`nTitle: " title "`nHWND: " hwnd)
}
