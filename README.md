# Chored

A roommate chore-coordination app for iOS. SwiftUI, iOS 17+, MVVM. Built
local-first: SwiftData is the offline source of truth and the entire app runs
with zero CloudKit access. iCloud (CloudKit private + shared databases) adds
sharing, multi-device sync, and roommate push on top — additively, never as a
requirement.

- **Bundle ID (app):** `com.yourcompany.chored`
- **Bundle ID (widget):** `com.yourcompany.chored.ChoreWidget`
- **App Group:** `group.com.yourcompany.chored`
- **CloudKit container:** `iCloud.com.yourcompany.chored`

## Generating & running the project

There is no checked-in `.xcodeproj`; it is generated from `project.yml` with
[XcodeGen](https://github.com/yonyz/XcodeGen) so the multi-target layout
(app + widget + shared Core) stays declarative.

```bash
brew install xcodegen      # one-time
cd chored
xcodegen generate          # produces Chored.xcodeproj
open Chored.xcodeproj
```

### Local-only (no Apple Developer account)

The app builds and runs on the Simulator with no signing and no iCloud. With no
account, it falls back to a device-scoped identity and an in-memory/App-Group
SwiftData store. Calendar, task CRUD, completion, recurrence/alternating, local
notifications, and the widget all work. CloudKit calls fail gracefully to no-ops.

### Full features (CloudKit, push, App Groups, widget data sharing)

1. Set `DEVELOPMENT_TEAM` in `project.yml`, re-run `xcodegen generate`.
2. In Signing & Capabilities for **both** targets, confirm: iCloud → CloudKit
   (container `iCloud.com.yourcompany.chored`), App Groups
   (`group.com.yourcompany.chored`), and Push Notifications (app target).
3. First run creates the CloudKit record types from the saved records; promote
   them to Production in the CloudKit Dashboard before shipping.

## Architecture (strict layering)

```
View  →  ViewModel  →  Repository  →  Service  →  (CloudKit / SwiftData / UNUser…)
                                   ↘  Model (pure, Foundation-only)
```

Enforced separation:

- **Core/Models** — pure Swift structs, `import Foundation` only. Includes pure
  completion/recurrence logic (`ChoreTask+Logic.swift`) since Services may not
  hold business logic.
- **Core/Services** — side effects only (`CloudKitService`, `NotificationService`,
  `SyncService`). No SwiftUI.
- **Core/Repositories** — compose Services, return Models. No SwiftUI.
- **Core/Persistence** — SwiftData `@Model` mirrors + the shared App-Group
  `ModelContainer`, plus small UserDefaults-backed stores for groups/identity.
- **Features/** — `View` + `ViewModel` per feature. ViewModels avoid SwiftUI/UIKit
  layout types.
- **DesignSystem/** — visual tokens + components, SwiftUI only, zero logic. All
  spacing/type/color come from `DESIGN.md`.
- **ChoreWidget/** — its own target; shares only `Chored/Core` (not DesignSystem,
  Features, or App). Reuses the exact app completion flow via `TaskRepository`.

## The shared "complete task" flow

`TaskRepository.completeTask` is the single code path used by both the app and the
widget's `CompleteTaskIntent`: write `TaskLog` → rotate assignee if alternating →
reopen + advance if recurring → reschedule the elapsed-time nudge → persist to
SwiftData immediately → push to CloudKit, or mark `pendingSync` when offline (the
app flushes pending items on next foreground via `SyncService`).

## CloudKit data model

Each group is its own `CKRecordZone`, shared to roommates via `CKShare`; owned
zones live in the private DB, joined ones surface in the shared DB. Record types:
`User`, `ChoreGroup`, `ChoreTask`, `TaskLog`. Per-zone `CKQuerySubscription`s on
`TaskLog` creation and `ChoreTask` changes drive roommate push.

## Deliberate deviations from the spec layout

All additions exist because the listed structure could not otherwise satisfy a
hard requirement; each stays within the separation rules:

- **`Core/Persistence/`** — SwiftData `@Model`s require `import SwiftData`, so they
  cannot live in the Foundation-only `Models/`. Holds the shared container and the
  group/user/local stores.
- **`Core/Models/ChoreTask+Logic.swift`, `Core/Utilities/NotificationCopy.swift`** —
  pure business logic / copy with nowhere valid to live in Services.
- **`App/RootView.swift`, `App/SessionViewModel.swift`, `App/AppContainer.swift`** —
  the composition root, identity gate (iCloud-unavailable / display-name prompt),
  and DI container referenced by `ChoreApp` (`@main`).
- **UIKit in three Views** — `UIImpactFeedbackGenerator` (haptic on completion, per
  DESIGN.md) and `UICloudSharingController` (invite flow) are HIG requirements with
  no SwiftUI equivalent.
- **CloudKit types in `GroupRepository`/`GroupViewModel`** — a `CKShare` must reach
  the View to hand to the sharing controller; it is not a SwiftUI/UIKit dependency.

## Design

The UI follows `DESIGN.md` exactly: base-8 spacing, SF Pro system type roles,
system semantic chrome everywhere, and the six `TaskColorPreset` hex values as the
only custom color in the app (the "chromatic silence" rule).
