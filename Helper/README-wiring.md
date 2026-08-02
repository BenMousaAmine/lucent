# LucentHelper — Xcode wiring notes (Phase 5 Step 3b)

Scaffold reference. None of this is testable in the dev sandbox — it requires a
signed app + installed daemon on a real machine. Steps to activate the
privileged helper.

## 1. Create the helper target
- New target → **Command Line Tool** named `LucentHelper` (product name must
  match `BundleProgram` in the launchd plist: `Contents/MacOS/LucentHelper`).
- Deployment: macOS, same min version as the app.

## 2. File membership (shared with the app target)
Add to the LucentHelper target:
- `Helper/main.swift`, `Helper/DeletionService.swift`
- Shared from the app: `Lucent/Core/Deletion/DeletionServiceProtocol.swift`,
  `Lucent/Core/Deletion/SIPPathValidator.swift`,
  `Lucent/Core/Deletion/DeletionPlan.swift`, `Lucent/Core/Model/Reclaimable.swift`
  (add each to the helper target's membership, or extract into a shared
  framework if the set grows).

## 3. Config files (in this folder)
- `it.fenix.lucent.LucentHelper.plist` → copy into the app bundle at
  `Contents/Library/LaunchDaemons/` (a Copy Files build phase on the APP target).
- `LucentHelper.entitlements` → set as `CODE_SIGN_ENTITLEMENTS` on the helper.

## 4. Bundle + sign
- Copy the built `LucentHelper` executable into
  `Contents/MacOS/` (or `Contents/Library/…` per your layout) of the app via a
  Copy Files phase.
- Sign the helper with the **same Developer ID Team** as the app + Hardened
  Runtime (Phase 6). SMAppService requires app and helper to share the Team.

## 5. Registration + connection
- App calls `PrivilegedDeletionClient.registerIfNeeded()` — first run prompts
  the user in System Settings > Login Items to approve the daemon.
- `machServiceName` (`it.fenix.lucent.LucentHelper`) must be identical in:
  the launchd plist `MachServices`, `Helper/main.swift`, and
  `PrivilegedDeletionClient`.

## 6. Security to finish (marked TODO in main.swift)
- In `ServiceDelegate.listener(_:shouldAcceptNewConnection:)`, pin the
  connection to the app's code-signing requirement via
  `connection.setCodeSigningRequirement(_:)` (Team ID + app identifier) so only
  the real Lucent app can drive the daemon.

## 7. Route only root-owned paths
- Most Findings are user-owned → keep them on the unprivileged
  `DeletionExecutor`. Send only paths that actually need root through
  `PrivilegedDeletionClient`. Decide the split app-side (task #2 remainder).
