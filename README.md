# ReCtrl
**`personal assistant` in windows, triggered by double-press of `Ctrl` key.**

# <mark>how to use</mark>
1. for installation / activation, 
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
└── src/
    ├── ReCtrl.ahk                     → Main coordinator (includes modules, registers hotkey)
    ├── sysTraySetup.ahk               → Tray icon & tooltip setup
    └── currentWinInfo.ahk             → Window info display logic
├── ReCtrl_installation_activation.bat → Launcher script (cross-terminal compatible)
```

# Project Code Flow
1. Run index.ahk → includes src/ReCtrl.ahk
2. src/ReCtrl.ahk → includes all modules (sysTraySetup.ahk, currentWinInfo.ahk); calls SetupTrayIcon(); and registers double-press Ctrl hotkey.
3. window info logic separated into clean functions
