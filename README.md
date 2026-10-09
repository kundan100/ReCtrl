# ReCtrl
**`personal assistant` in windows, triggered by double-press of `Ctrl` key.**

# <mark>how to use</mark>
1. for installation / activation / Launching, 
	1. clone this repo.
	2. Activate (Option-1): using bat file (ReCtrl_installation_activation.bat):
        1. Run the BAT file from any terminal, as below:
        2. CMD: `ReCtrl_installation_activation.bat`
        3. PowerShell: `.\ReCtrl_installation_activation.bat`
        4. Git Bash: `./ReCtrl_installation_activation.bat`
        5. If you have custom path for "AutoHotkey64.exe", you can set AHK_EXE_MyCustomPath="D:\path-to\AutoHotkey64.exe"
	3. Activate (Option-2): using shortcut (so that we can double-click to run the activation easily):
 		1. Create a shortcut file (at the same level of project-folder), by following below steps:
   		2. right-click > select "Shortcut".
		3. provide the location (e.g. D:\kk\AutoHotkey_2.0.19\AutoHotkey64.exe "D:\path-to-project-folder\ReCtrl.ahk").
		4. provide name for your shortcut (e.g. ReCtrl.exe).
		5. Click "Finish".
		6. right-click (on shortcut) > click "Properties" > assign the shortcut-key (same which has been mentioned in your main-ahk-file).
		7. double-click this shortcut to activate your ahk utility.
	4. Activate (Option-3): using core command in terminal:
        1. Command: `start "" "%AHK_EXE%" "%AHK_SCRIPT%"`
        2. Replace `%AHK_EXE%` with `D:\path-to\AutoHotkey64.exe`
        3. Replace `%AHK_SCRIPT%` with `D:\path-to\index.ahk`
2. Verify your running ahk-utility.
   1. System Tray > app-icon > hover to see the tooltip.
3. <mark>To Run: double-press `Ctrl` key.</mark>
4. Reload your utility (after updating)
	1. System Tray > app-icon (tooltip showing main-ahk-file-name) > right click > "Reload Script".
5. Pre-requisites:
	1. Using AHK V2.
	2. Get/download the lib (AutoHotkey_2.0.19.zip) and extract anywhere (preferably outside project).
6. Done!
 

# Project Structure
```
ReCtrl/
├── index.ahk                          → Entry point (includes src/ReCtrl.ahk)
├── assets/
│   └── appIcon/favicon_io/
│       └── favicon.ico                → System tray icon
├── src/
│	├── appConfig.ahk                      ← app-wide settings (width, colors, title, etc.)
│	├── ReCtrl.ahk                         ← coordinator only: includes, init, hotkeys
│	├── sysTray/
│	│   └── sysTraySetup.ahk               ← tray icon + tooltip setup
│	├── currentWin/
│	│   └── currentWinInfo.ahk             → Window info display logic
│	│
│	├── mainApp/                           ← NEW feature (replaces mainSearchBox at runtime)
│	│   ├── mainApp.ahk                    ← thin orchestrator + ShowMainApp() for hotkey
│	│   ├── mainAppContainer.ahk           ← owns the single Gui, composes header + content
│	│   ├── appHeaderContainer.ahk         ← custom header with icon/title/close
│	│   └── appContentContainer.ahk        ← content background + embedded searchBox
│	│
│	└── mainSearchBox/                     ← PARKED — no deletions, left as-is
│   	└── ...                            ← disconnected only via comments in ReCtrl.ahk
├── ReCtrl_installation_activation.bat → Launcher script (cross-terminal compatible)
```

# Project Code Flow
1. Run index.ahk
	→ includes src/ReCtrl.ahk
2. src/ReCtrl.ahk
	→ includes all modules (sysTray/sysTraySetup.ahk, currentWin/currentWinInfo.ahk); 
	→ Sets system tray icon: by calling SetupTrayIcon();
	→ Creates the main window object: mainAppInstance := MainApp()
	→ Registers double-press Ctrl hotkey.
3. window info logic separated into clean functions

# Examples to add a new searchBox's option
## Open: Oreo tracker
1. In file (`config/searchActions.json`), add the option as below:
{
	"id": "open-oreo-tracker",
	"label": "Open: Oreo tracker",
	"actionType": "openInBrowser__OreoTracker",
	"context": [],
	"keywords": ["open", "oreo", "tracker", "browser"]
},
2. In file (`src/searchBox/actions/openInBrowser/openInBrowser__OreoTracker.ahk`), create a new ahk file to achive the functionality:
#Requires AutoHotkey v2
; Open Oreo tracker in browser (actionType: openInBrowser__OreoTracker).
class OpenInBrowser__OreoTracker {
    static Run(action := unset, ownerHwnd := 0) {
        return Map(
            "ok", true,
            "title", ConfigApp.APP_NAME,
            "message", "work in progress"
        )
    }
}
3. In file (`src/searchBox/searchBox.ahk`), include the newly created ahk file (as in above step)
#Include actions\openInBrowser\openInBrowser__OreoTracker.ahk
4. In file (`src/searchBox/searchBoxHandler.ahk`), add the trigger block for `actionType = "openInBrowser__OreoTracker"`
else if (actionType = "openInBrowser__OreoTracker") {
	ownerHwnd := 0
	try ownerHwnd := this.guiInstance.GetOwnerHwnd()
	result := OpenInBrowser__OreoTracker.Run(action, ownerHwnd)
	this.ShowActionResult(result)
}

