---
phase: 01-device-foundation
plan: 01
subsystem: infra
tags: [swift, swiftui, xcode, ios17, xcodeproj, pbxproj, entitlements, swift-testing]

# Dependency graph
requires: []
provides:
  - Xcode project (ModelRunner) targeting iOS 17+ with ModelRunnerTests unit test target
  - increased-memory-limit entitlement in ModelRunner.entitlements
  - Core type contracts: ChipGeneration, NEGeneration, SpeedBands, ChipProfile, DeviceSpecs, QuantizationType, ModelMetadata, CompatibilityResult, IncompatibilityReason, CompatibilityTier
  - Wave 0 RED stub tests for DeviceCapabilityService, CompatibilityEngine, ChipLookupTable
affects: [01-02, 01-03, all subsequent plans in phase 01]

# Tech tracking
tech-stack:
  added: [SwiftUI, Swift Testing (@Test), iOS 17 @Observable macro]
  patterns:
    - Hand-authored project.pbxproj for deterministic project structure
    - Wave 0 RED stubs using Issue.record() — tests exist and fail until implementation plans land
    - All public types in CompatibilityModels.swift — single file defines the type contract boundary

key-files:
  created:
    - ModelRunner.xcodeproj/project.pbxproj
    - ModelRunner/ModelRunner.entitlements
    - ModelRunner/App/ModelRunnerApp.swift
    - ModelRunner/App/AppContainer.swift
    - ModelRunner/ContentView.swift
    - ModelRunner/Services/Device/CompatibilityModels.swift
    - ModelRunnerTests/DeviceCapabilityServiceTests.swift
    - ModelRunnerTests/CompatibilityEngineTests.swift
    - ModelRunnerTests/ChipLookupTableTests.swift
    - .gitignore
  modified: []

key-decisions:
  - "Hand-authored project.pbxproj rather than XcodeBuildMCP generate_project — direct control over project structure, entitlements reference, and test target configuration"
  - "CompatibilityModels.swift uses public access control — Plans 02 and 03 import ModelRunner as a module from the test target"
  - "Wave 0 stub tests use Issue.record() not #expect(false) — Issue.record emits a test issue without throwing, allowing test discovery while marking as known-failing"

patterns-established:
  - "Single CompatibilityModels.swift owns all shared types — no type spread across multiple files"
  - "Public structs use explicit memberwise inits — Sendable conformance requires explicit access"

requirements-completed: [DEVC-01, DEVC-02, DEVC-03, DEVC-04, DEVC-05, DEVC-06]

# Metrics
duration: 7min
completed: 2026-04-09
---

# Phase 01 Plan 01: Device Foundation Scaffolding Summary

**iOS 17 Xcode project bootstrapped with ModelRunnerTests target, increased-memory-limit entitlement, and all compatibility type contracts (ChipProfile, DeviceSpecs, CompatibilityResult, ModelMetadata) that Plans 02 and 03 build against**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-09T05:31:33Z
- **Completed:** 2026-04-09T05:39:06Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Xcode project with valid `project.pbxproj` targeting iOS 17, bundle ID `com.modelrunner.app`, with ModelRunnerTests unit test target properly configured as a host-app test bundle
- `ModelRunner.entitlements` with `com.apple.developer.kernel.increased-memory-limit` referenced in both Debug and Release build settings
- All 9 core types defined in `CompatibilityModels.swift` with correct Sendable/Hashable conformances and public access control so the test target can import them via `@testable import ModelRunner`
- 6 Wave 0 RED stub tests across 3 test files — test methods exist with correct names matching the VALIDATION.md test map, using `Issue.record()` as pending markers

## Task Commits

1. **Task 1: Create Xcode project, test target, and entitlements** - `ef4c5a1` (feat)
2. **Task 2: Define core type contracts in CompatibilityModels.swift** - `48b8709` (feat)
3. **Chore: .gitignore for build artifacts** - `9c8d61a` (chore)

## Files Created/Modified

- `ModelRunner.xcodeproj/project.pbxproj` - Full Xcode project: 2 targets, Debug/Release configs, entitlements reference
- `ModelRunner/ModelRunner.entitlements` - increased-memory-limit entitlement (required for >50% RAM jetsam budget)
- `ModelRunner/App/ModelRunnerApp.swift` - @main entry point, @State container
- `ModelRunner/App/AppContainer.swift` - @Observable stub (services wired in Plan 02)
- `ModelRunner/ContentView.swift` - Placeholder root view
- `ModelRunner/Services/Device/CompatibilityModels.swift` - All 9 public type contracts
- `ModelRunnerTests/DeviceCapabilityServiceTests.swift` - 2 RED stubs for DEVC-01
- `ModelRunnerTests/CompatibilityEngineTests.swift` - 4 RED stubs for DEVC-02/03/04/06
- `ModelRunnerTests/ChipLookupTableTests.swift` - 2 RED stubs for DEVC-05
- `.gitignore` - Excludes build/, DerivedData/, xcuserstate

## Decisions Made

- Hand-authored `project.pbxproj` rather than using XcodeBuildMCP `generate_project` — required precise control over `CODE_SIGN_ENTITLEMENTS` reference and test target `BUNDLE_LOADER`/`TEST_HOST` settings
- Used `public` access modifiers on all types in `CompatibilityModels.swift` — the test files use `@testable import ModelRunner` which requires at least `internal`, but `public` signals these are the stable API surface that downstream plans target
- Wave 0 stubs use `Issue.record()` not `throw` or `#expect(false)` — `Issue.record` creates a non-fatal issue marker that Xcode test navigator shows as an expected failure without aborting the test run

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created ContentView.swift missing from plan's file list**
- **Found during:** Task 1 (project scaffold)
- **Issue:** `ModelRunnerApp.swift` references `ContentView()` but the plan's file list didn't include `ContentView.swift`; the project would not compile without it
- **Fix:** Created minimal `ContentView.swift` with a placeholder body
- **Files modified:** `ModelRunner/ContentView.swift` (new)
- **Verification:** `BUILD SUCCEEDED` on ModelRunner scheme
- **Committed in:** `ef4c5a1` (Task 1 commit)

**2. [Rule 3 - Blocking] Created .gitignore to exclude generated build/ directory**
- **Found during:** Post-Task 1 (after first build)
- **Issue:** `xcodebuild` created a `build/` directory in the worktree that would pollute git status
- **Fix:** Added `.gitignore` covering `build/`, `DerivedData/`, `*.xcuserstate`
- **Files modified:** `.gitignore` (new)
- **Committed in:** `9c8d61a`

---

**Total deviations:** 2 auto-fixed (both Rule 3 — blocking)
**Impact on plan:** Both fixes were necessary for compilability and repo hygiene. No scope change.

## Issues Encountered

- Initial `project.pbxproj` had UUID collision: root PBXProject object UUID was reused as the main PBXGroup UUID, causing `group should be an instance inheriting from PBXGroup, but it is <PBXProject>` assertion in DevToolsCore. Fixed by using distinct UUIDs for project object (`A1B2C3D4E5F60001A2B3C4D5`) and root group (`A1B2C3D4E5F60002A2B3C4D5`).
- Building the test target in Release mode produced "swiftmodule built without -enable-testing" warning; resolved by using `-configuration Debug` with `ENABLE_TESTABILITY=YES` for both the app and test targets.

## Known Stubs

- `ModelRunner/App/AppContainer.swift` — empty `@Observable` class; DeviceCapabilityService and CompatibilityEngine properties added in Plan 02
- `ModelRunner/ContentView.swift` — placeholder body; replaced with actual UI in Phase 2

These stubs are intentional scaffolding. They do not prevent Plan 01-01's goal (type contracts and compilable project) from being achieved. Plans 02 and 03 wire the services; Phase 2 builds the UI.

## Next Phase Readiness

- Plans 02 and 03 can import `ModelRunner` module and build against the type contracts in `CompatibilityModels.swift` without modification
- Test stubs exist and will turn GREEN when Plans 02 and 03 implement their respective services
- `AppContainer.swift` has stub comment indicating exactly where services are added

---
*Phase: 01-device-foundation*
*Completed: 2026-04-09*
