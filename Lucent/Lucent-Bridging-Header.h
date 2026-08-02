//
//  Lucent-Bridging-Header.h
//  Lucent
//
//  Exposes system APIs that Swift's Darwin module does not surface.
//
//  fs_snapshot_create / _list / _delete live in <sys/snapshot.h>, which is part
//  of the macOS SDK but is NOT modularized into the Swift `Darwin` overlay.
//  Including it here makes those functions visible to all Swift code in the
//  Lucent target (used by SnapshotInspector and the test-only volume helper).
//

#include <sys/snapshot.h>
#include <sys/attr.h>
