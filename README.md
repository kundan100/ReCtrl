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
│	├── ReCtrl.ahk                         ← coordinator only: includes, init, hotkeys
│	├── shared/
│	│   └── configAppSettingsLoader.ahk    ← config/configAppSettings.json (info/view/functional)
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
1. Load JSON (startup)
	- `config/searchActions.json` (data)
	- `searchActionsLoader.ahk` > `SearchActionsLoader.LoadFromFile`
	- `searchActionsLoader.ahk` > `NormalizeSearchConfig`
	- `searchActionsLoader.ahk` > `NormalizeNodes → NormalizeNode (keeps nested action)`
	- `searchBoxHandler.ahk` > `SearchBoxHandler.__New → LoadMenuTree`
	- `searchBoxHandler.ahk` > `FlattenLeaves`
2. User selects the option
	- `searchBoxHandler.ahk` > `ActivateSelectedOption`
	- `searchBoxHandler.ahk` > `ExecuteAction`
	- `searchBoxHandler.ahk` > `BrowserActions.Run (when actionType = browserActions)`
3. Facade routes by JSON operation
	- `browserActions.ahk` > `BrowserActions.Run`
	- `browserActions.ahk` > `GetActionConfig / CfgStr`
	- `browserActions.ahk` > `operation` (string or array) → `RunOne` / `OpenOrFocus…` / `login`
	- `browserLogin.ahk` > `loginSteps` (often via `reusables.reusable__…`) + `localConfig.LOGIN_DEPENDENCY_PATH` (env id → credential array; 2+ → pick list)
	- `browserLoginUia.ahk` > find / textfieldEntry / click (UIA)
4. Focus tab (if found)
	- `browserTabs.ahk` > `BrowserTabs.FocusByTitle` (optional urlNeedle for title+URL)
	- `browserWindows.ahk` > `ListByBrowserAndLabel`
	- `browserWindows.ahk` > `WindowMatchesPrimaryLabel`
	- `browserProfile.ahk` > `CollectBrowserProfile (+ helpers: GuessBrowserName, ResolveProfileIdentity, …)`
	- `browserTabs.ahk` > `TryFocusTabViaUia` (URL via UIA when matching) or `FocusTabByCycling` (title-only)
	- `browserWindows.ahk` > `Activate`
5. Else open URL
	- `browserActions.ahk` > `OpenUrl`
	- `browserLaunch.ahk` > `BrowserLaunch.OpenUrl`
	- `browserLaunch.ahk` > `ResolveExe`
	- `browserProfile.ahk` > `ResolveDirectoryByPrimaryLabel`
	- `browserLaunch.ahk` > `Run(...) (launch Chrome with profile + URL)`


