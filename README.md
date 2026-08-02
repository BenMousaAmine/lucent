# Lucent

**A native macOS app that explains the opaque "System Data" bucket — and never asks you to delete anything you don't understand.**

Lucent is a disk-space tool for developers and power users. Where most cleaners
show you a big number and a "Clean" button, Lucent's differentiator is
**absolute transparency**: every byte it reports is explained — what it is, who
created it, its state, what actually happens if you remove it, and whether it
comes back.

> Status: in active development. The read-only scanning engine and the product
> UI are complete; the privileged deletion path is being finalized. See
> [Roadmap](#roadmap).

---

## Why Lucent

macOS lumps gigabytes of developer detritus into an opaque "System Data"
category. Docker images, Xcode DerivedData, `node_modules`, orphaned app
containers, third-party caches — all invisible, all hard to reason about.

Lucent's principles:

- **Honesty about reclaimable space.** It measures *physically allocated* size,
  not logical size, and is APFS clone/snapshot aware: a cloned or
  snapshot-referenced file reports its true reclaimable amount (often ≈ 0), not
  a misleading total. It distinguishes space freed *inside a container* (e.g.
  `Docker.raw`, which doesn't shrink on its own) from space actually returned to
  macOS.
- **Never destroy what you don't understand.** Every item carries a plain-language
  explanation and a risk tier. Deletion is never automatic, never bulk, always
  reversible (Trash or quarantine, with an undo log).

## Domains covered

Lucent inspects each domain via its own source of truth, not by blindly walking
files:

| Domain | What it finds |
|--------|---------------|
| **Docker** | Dangling images, build cache, stopped containers, volumes |
| **Xcode** | DerivedData, Archives, iOS DeviceSupport, Simulators |
| **Package managers** | npm/pnpm/pip/Yarn caches, `node_modules` folders |
| **Orphaned apps** | `~/Library/Containers` with no matching installed app |
| **System** | Third-party caches in `~/Library/Caches` (Apple's excluded) |

Plus a whole-disk map for everything else.

## Architecture

- **Scanner core** (read-only): bulk attribute traversal, APFS-aware physical
  sizing, clone/snapshot inspection. Produces facts, never interpretations.
- **Domain probes** (plugin model): each queries its domain's source of truth,
  then detects → inspects → classifies → proposes, degrading gracefully when a
  domain is unavailable.
- **Versioned knowledge base**: the tiering rules (safe / conditional /
  never-touch) live in a versioned manifest, updatable separately from the app
  binary.
- **Deletion engine**: an unprivileged action layer (intent → dry-run → plan →
  execute to Trash/quarantine, with undo/restore) plus an isolated privileged
  helper for the few paths that genuinely require root. SIP-protected paths are
  refused by construction.

## Building

Requirements:

- macOS (recent), Xcode 16+.
- Swift 5.

```sh
git clone <this-repo>
cd Lucent
open Lucent.xcodeproj
```

Build and run the **Lucent** scheme. Tests use Swift Testing:

```sh
xcodebuild test -scheme Lucent -destination 'platform=macOS'
```

### Distribution model

Lucent is designed for **Developer ID + notarization + Full Disk Access**, *not*
the Mac App Store — the sandbox would cripple the scanner. The app runs
unprivileged for all scanning; only the deletion helper is privileged, isolated,
and minimal.

## Roadmap

- [x] Phase 1 — Read-only scanner core (APFS-aware sizing)
- [x] Phase 2 — Docker probe
- [x] Phase 3 — Xcode, package-manager, orphan-app, system-cache probes
- [x] Phase 4 — SwiftUI product UI (3-column results + whole-disk map)
- [~] Phase 5 — Deletion engine (unprivileged flow done; privileged helper in progress)
- [~] Phase 6 — Hardening: versioned rules (done), notarization, auto-update, public rules repo

## License

Lucent is released under the **GNU General Public License v3.0**. See
[LICENSE](LICENSE).
