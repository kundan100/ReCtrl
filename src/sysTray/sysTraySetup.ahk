; ===== System Tray Setup Module =====
; Handles custom tray icon and tooltip configuration

#Requires AutoHotkey v2

/**
 * Sets up custom tray icon and tooltip for the application
 * Icon file should be located at: assets\appIcon\favicon_io\favicon.ico
 */
SetupTrayIcon() {
	; Set custom tray icon and custom tooltip.
	; You can also compile this script to an EXE embedding the same ICO (see README instructions).
	iconPath := A_ScriptDir "\assets\appIcon\favicon_io\favicon.ico"
	iconTooltip := "ReCtrl (v1.0.0) `n# Launched. Press 'Ctrl' twice (quickly), to see it in action..."

	if FileExist(iconPath) {
		; MsgBox(iconPath)
		try {
			; set app-icon in system-tray
			TraySetIcon(iconPath)
			; set hover tooltip (for system-tray's app-icon)
			A_IconTip := iconTooltip
			; MsgBox("iconPath: " iconPath)
			MsgBox("# iconTooltip: " iconTooltip)
		} catch {
			; TBD (future): find a way to pass "e" and print e.Message
			MsgBox("Failed to set tray icon!")
		}
	}
}
