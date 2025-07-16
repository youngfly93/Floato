# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Floato is a macOS Pomodoro timer application built with SwiftUI that displays as a floating always-on-top window. It features a menu bar interface, task categorization, 7-segment LCD-style timer display, and premium glassmorphism UI design. The app is built with Xcode 16.4, targeting macOS 14.0+.

## Build and Development Commands

### Building the Application
```bash
# Build for Debug
xcodebuild -scheme Floato -configuration Debug build

# Build for Release
xcodebuild -scheme Floato -configuration Release build

# Clean build folder
xcodebuild -scheme Floato clean
```

### Running Tests
```bash
# Run all tests
xcodebuild test -scheme Floato -destination 'platform=macOS'

# Run unit tests only
xcodebuild test -scheme Floato -destination 'platform=macOS' -only-testing:FloatoTests

# Run UI tests only
xcodebuild test -scheme Floato -destination 'platform=macOS' -only-testing:FloatoUITests

# Run a specific test
xcodebuild test -scheme Floato -destination 'platform=macOS' -only-testing:FloatoTests/FloatoTests/testExample
```

### Opening in Xcode
```bash
open Floato.xcodeproj
```

## Architecture Overview

### Core Architecture Pattern
The application follows an **MVVM + Observable** pattern with actor-based concurrency:

1. **Entry Point**: `FloatoApp.swift` - MenuBarExtra configuration with floating window management
2. **Data Layer**: `TodoStore.swift` - Observable data model using Swift's `@Observable` macro, persisted via UserDefaults JSON
3. **Timer Engine**: `PomodoroClock.swift` - Actor-based timer for thread-safe time management
4. **Main UI**: `OverlayView.swift` - Floating window with collapse/expand functionality and glassmorphism design
5. **Window Management**: `FloatingPanel.swift` - Custom NSPanel subclass for advanced floating window behavior
6. **System Integration**: `SystemHelpers.swift` - Notifications, auto-launch, and haptic feedback

### Key Design Patterns
- **Observable State Management**: Uses Swift's new `@Observable` macro instead of traditional ObservableObject
- **Actor-based Concurrency**: PomodoroClock actor ensures thread-safe timer operations
- **Custom Window Management**: FloatingPanel extends NSPanel for always-on-top, non-activating behavior
- **Manual Persistence**: JSON encoding/decoding to UserDefaults rather than Core Data or SwiftData

### State Management Flow
- **Global State**: Single TodoStore instance shared via Environment injection
- **Timer State**: PomodoroClock actor manages timer state with AsyncStream updates
- **UI State**: Component-level @State for interactions, @AppStorage for user preferences
- **Persistence**: TodoStore automatically saves/loads task data as JSON to UserDefaults

## Technology Stack and Dependencies

### Core Technologies
- **SwiftUI**: Primary UI framework with latest features (AsyncStream, WindowGroup modifiers)
- **AppKit Integration**: NSPanel, NSVisualEffectView for advanced window management
- **UserNotifications**: System notifications with custom sounds
- **AVFoundation**: Sound playback for timer alerts
- **ServiceManagement**: Auto-launch functionality

### Project Configuration
- **No External Dependencies**: Self-contained project using only system frameworks
- **Custom Fonts**: Includes "7segment.ttf" for authentic digital display
- **Bundle ID**: `afei.Floato`
- **Deployment Target**: macOS 14.0+
- **App Sandbox**: Enabled with read-only file access

## Key Development Considerations

### UI/UX Architecture
- **Floating Window Design**: Always-on-top, non-activating window that doesn't steal focus
- **Glassmorphism Effects**: Custom implementation using NSVisualEffectView and SwiftUI overlays
- **7-Segment Display**: Custom font integration for authentic digital clock appearance
- **Responsive Collapse/Expand**: Dynamic window resizing with smooth animations

### Timer System
- **Actor-based Timer**: PomodoroClock actor prevents race conditions and ensures accurate timing
- **State Persistence**: Timer state survives app restarts and system events
- **Notification Integration**: System notifications with custom sounds and haptic feedback
- **Task Completion Flow**: Automatic task advancement with immediate completion capability

### Task Management
- **5 Predefined Categories**: Work, Study, Exercise, Break, Personal with distinct colors
- **JSON Persistence**: Manual serialization to UserDefaults for simplicity and control
- **Observable Updates**: Real-time UI updates via Swift's Observable framework
- **Task Completion Logic**: Sophisticated flow handling task progression and completion

### Window Management
- **FloatingPanel**: Custom NSPanel subclass for specialized floating behavior
- **Focus Management**: Window doesn't activate or steal focus from other apps
- **Level Management**: Proper window level handling for always-on-top behavior
- **Resize Animations**: Smooth transitions between collapsed and expanded states