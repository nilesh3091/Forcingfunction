# Widget Extension Setup Guide

This guide will help you set up the Widget Extension in Xcode.

## Prerequisites

- Xcode 14.0 or later
- iOS 16.0+ deployment target

## Steps to Add Widget Extension

1. **Open the Project in Xcode**
   - Open `ForcingFunction.xcodeproj` in Xcode

2. **Add Widget Extension Target**
   - Go to File → New → Target
   - Select "Widget Extension"
   - Click "Next"
   - Product Name: `ForcingFunctionWidget`
   - Organization Identifier: (use your existing one)
   - Language: Swift
   - **Uncheck** "Include Configuration Intent" (we're using StaticConfiguration)
   - Click "Finish"
   - When prompted, click "Activate" to activate the scheme

3. **Configure App Groups**
   - Select the **ForcingFunction** target (main app)
   - Go to "Signing & Capabilities" tab
   - Click "+ Capability"
   - Add "App Groups"
   - Click "+" and add: `group.com.forcingfunction.shared`
   - Check the box next to it
   
   - Select the **ForcingFunctionWidget** target (widget extension)
   - Go to "Signing & Capabilities" tab
   - Click "+ Capability"
   - Add "App Groups"
   - Add the same group: `group.com.forcingfunction.shared`
   - Check the box next to it

4. **Configure Info.plist for URL Scheme** (for widget tap to open app)
   - Select the **ForcingFunction** target
   - Go to "Info" tab
   - Expand "URL Types"
   - Click "+" to add a new URL Type
   - Set Identifier: `com.forcingfunction`
   - Set URL Schemes: `forcingfunction`
   - Set Role: `Editor`

5. **Add Files to Widget Target**
   - The widget files are already created in `ForcingFunctionWidget/` directory:
     - `WeeklyPomodoroWidget.swift`
     - `ForcingFunctionWidgetBundle.swift`
   
   - In Xcode, select these files
   - In the File Inspector (right panel), under "Target Membership"
   - Make sure **ForcingFunctionWidget** is checked

6. **Share Models with Widget** (if needed)
   - The widget uses its own `WeeklyWidgetData` struct
   - If you want to share `Models.swift` and `PomodoroDataStore.swift`:
     - Select these files in Xcode
     - In File Inspector, check **ForcingFunctionWidget** under Target Membership
   - **Note**: Currently the widget has its own data structure to avoid dependencies

7. **Build and Run**
   - Select the **ForcingFunctionWidget** scheme
   - Build (Cmd+B) to ensure it compiles
   - Switch back to **ForcingFunction** scheme
   - Build and run the main app

8. **Add Widget to Home Screen**
   - Long press on home screen
   - Tap "+" button
   - Search for "ForcingFunction"
   - Select "Weekly Pomodoro" widget
   - Choose medium size
   - Tap "Add Widget"

## Testing

1. Complete a Pomodoro work session in the app
2. The widget should automatically update to show the new data
3. Tap the widget to open the app and navigate to Stats tab

## Troubleshooting

- **Widget shows empty data**: Make sure App Groups are configured correctly for both targets
- **Widget doesn't update**: Check that `WidgetDataManager.shared.updateWidgetData()` is called when sessions complete
- **Build errors**: Ensure both targets have the same iOS deployment target (16.0+)

## Files Created

- `ForcingFunction/WidgetDataManager.swift` - Shared data manager
- `ForcingFunctionWidget/WeeklyPomodoroWidget.swift` - Widget implementation
- `ForcingFunctionWidget/ForcingFunctionWidgetBundle.swift` - Widget bundle entry point

## App Group Identifier

The App Group identifier is: `group.com.forcingfunction.shared`

Make sure this matches in:
- WidgetDataManager.swift
- WeeklyPomodoroWidget.swift
- Xcode project settings for both targets

