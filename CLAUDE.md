# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Floato is a macOS SwiftUI application built with Xcode 16.4, targeting macOS 14.0+. It uses SwiftData for persistence and follows standard Apple development patterns.

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

The application follows a standard SwiftUI + SwiftData architecture:

1. **Entry Point**: `FloatoApp.swift` - Configures the SwiftData ModelContainer and sets up the main WindowGroup
2. **Data Model**: `Item.swift` - Defines the SwiftData model with a timestamp property
3. **Main UI**: `ContentView.swift` - Implements a NavigationSplitView with list/detail layout
4. **Persistence**: SwiftData handles all data persistence automatically through the ModelContainer

The app is sandboxed with read-only file access permissions and uses the bundle identifier `afei.Floato`.

## SwiftData Integration

The app uses SwiftData for persistence with:
- ModelContainer configured in `FloatoApp.swift`
- @Query property wrapper for fetching data
- @Environment(\.modelContext) for data operations
- Automatic persistence (not in-memory only)

## Key Development Considerations

- The app targets macOS 14.0+ and requires features from that SDK
- Swift 5.0 is the minimum language version
- The project uses Xcode's new file system synchronized groups (objectVersion 77)
- All three targets (app, unit tests, UI tests) are configured and ready for development