# Centralized Theme System

## Overview

The app now has a **centralized theme system** that makes it easy to change the app-wide aesthetic. All colors are defined in one place (`AppTheme` in `Models.swift`), and views use theme colors instead of hardcoded values.

## How It Works

### 1. Theme Structure

The `AppTheme` struct in `Models.swift` defines all colors used throughout the app:

- **Accent Colors**: Primary accent, light, and dark variants
- **Background Colors**: Primary, secondary, tertiary, card, and overlay
- **Text Colors**: Primary, secondary, tertiary, and disabled
- **Border Colors**: Primary, secondary, and divider
- **Button Colors**: Primary, secondary, and disabled states
- **Status Colors**: Success, warning, error, and info
- **Shadow Colors**: Light, medium, and heavy

### 2. Accessing the Theme

Views access the theme through `TimerViewModel`:

```swift
private var theme: AppTheme {
    viewModel.theme
}
```

### 3. Using Theme Colors

Instead of hardcoded colors like `.white` or `.black`, use theme colors:

```swift
// Before
.foregroundColor(.white)
.background(Color.black)

// After
.foregroundColor(theme.text(.primary))
.background(theme.background(.primary))
```

### 4. Theme Color Selection

Users can change the accent color in Settings, which automatically updates all accent-colored elements throughout the app. The theme system supports:
- **Red** (default)
- **Blue**
- **Green**

## Customizing the Theme

### Adding New Colors

To add new colors to the theme:

1. Add the color property to `AppTheme` struct
2. Initialize it in the `AppTheme.init()` method
3. Use it in your views via `theme.yourNewColor`

### Changing Default Colors

Edit the `AppTheme.init()` method in `Models.swift` to change:
- Background colors
- Text colors
- Border colors
- Any other theme properties

### Adding New Theme Variants

To add new theme options (e.g., Purple, Orange):

1. Add the case to `ThemeColor` enum in `Models.swift`
2. Add the color mapping in `AppTheme.init()` switch statement
3. The new theme will automatically appear in Settings

## Updated Views

The following views have been updated to use the theme system:

- ✅ `TimerView` - Main timer interface
- ✅ `SettingsView` - Settings page
- ✅ `MainTabView` - Tab bar navigation
- ✅ `CategoryChipView` - Category selection chips
- ✅ `SessionBlockView` - Session progress blocks

## Benefits

1. **Single Source of Truth**: All colors defined in one place
2. **Easy Customization**: Change the entire app aesthetic by editing `AppTheme`
3. **Consistent Styling**: All views use the same color system
4. **Future-Proof**: Easy to add new themes or color schemes
5. **Maintainable**: No more searching for hardcoded colors across files

## Example: Changing App-Wide Colors

To change the app's color scheme:

1. Open `Models.swift`
2. Find the `AppTheme.init()` method
3. Modify the color values:

```swift
// Change background from black to dark gray
self.backgroundPrimary = Color(white: 0.1)  // Instead of .black

// Change text opacity
self.textSecondary = Color.white.opacity(0.8)  // Instead of 0.7
```

All views will automatically use the new colors!

## Migration Notes

- The `accentColor` property in `TimerViewModel` is still available for backward compatibility
- Views should gradually migrate to use `theme.accentColor` instead
- Hardcoded colors in other views (CalendarView, StatsView, etc.) can be updated to use the theme system as needed


