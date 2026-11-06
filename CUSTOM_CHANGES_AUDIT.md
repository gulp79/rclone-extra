# CUSTOM CHANGES AUDIT: Fork Modifications Review

This document provides a comprehensive audit of all fork-specific components within `rclone-extra` as declared in `.custom-merge-manifest.yml` and detected during synchronization with upstream `rclone` `v1.76.0`.

---

## Component Inventory & Classification

| Component | Path | Classification | Purpose |
| :--- | :--- | :--- | :--- |
| **CI/CD Workflow** | `.github/workflows/build.yml` | Feature Extension / Override | Multi-platform build pipeline with static WinFsp MinGW and Android NDK support |
| **Local Object Hash Cache** | `backend/local/local.go` | Performance Optimization | Cache computed checksums directly onto local object instances |
| **Backend Registry** | `backend/all/all.go` | Feature Extension | Blank import registration of custom backends |
| **Remote Override Wrapper** | `fs/override.go` | Feature Extension | Forward hash-caching calls through `OverrideRemote` objects |
| **Core Hash Interfaces** | `fs/types.go` | Feature Extension | Define `HashSetter` interface for cross-component hash passing |
| **ReOpen Stream Accounting** | `fs/operations/reopen.go` | Feature Extension | Manual byte accounting method `Account(n int)` on reopened streams |
| **RC Server Protocol** | `fs/rc/rcserver/rcserver.go` | Behavioral Override | Upstream RC server alignment and request security hardening |
| **Pool RW Accounting** | `lib/pool/reader_writer.go` | Feature Extension | Manual byte accounting method `Account(n int)` on memory pool buffers |
| **TelDrive Backend** | `backend/teldrive/**` | New Backend | Full-featured Telegram-based cloud storage backend |
| **AList Backend** | `backend/alist/**` | New Backend | Storage gateway integration for AList file aggregation |
| **AllDebrid Backend** | `backend/alldebrid/**` | New Backend | Debrid service connector for saved links, magnets, and torrents |
| **TeraBox Backend** | `backend/terabox/**` | New Backend | Baidu international cloud drive integration |
| **Overview Suppressor** | `fs/registry.go` | Bug Fix / Override | Suppress startup error logs for backends lacking embedded overview metadata |

---

## Detailed Component Audits

### 1. `backend/teldrive/**`
- **Classification**: **New Backend**
- **Why It Exists**: Provides seamless integration with Telegram's unlimited cloud file storage via the TelDrive protocol. Includes server-side recursive listing (`ListR`), multi-part chunked uploads, resumable sessions, and deduplication.
- **Upstream Dependencies**:
  - `github.com/rclone/rclone/fs`
  - `github.com/rclone/rclone/fs/config`
  - `github.com/rclone/rclone/fs/hash`
  - `github.com/rclone/rclone/fs/operations`
  - `github.com/rclone/rclone/lib/pacer`
  - `github.com/rclone/rclone/lib/pool`
  - `github.com/rclone/rclone/lib/rest`
- **Internal Cross-Dependencies**:
  - Requires `fs.HashSetter` (defined in `fs/types.go`).
  - Requires `Account(n int)` on `operations.ReOpen` and `pool.RW`.
- **Compatibility Risks**: Upstream changes to `fs.Fs` or `fs.Object` interfaces; low risk in v1.76.0 as core interfaces were completely stable.

---

### 2. `backend/alist/**`
- **Classification**: **New Backend**
- **Why It Exists**: Implements native support for AList, allowing rclone to mount, copy, and sync against 30+ underlying storage services aggregated behind an AList instance.
- **Upstream Dependencies**:
  - `github.com/rclone/rclone/fs`
  - `github.com/rclone/rclone/fs/config`
  - `github.com/rclone/rclone/lib/rest`
  - `github.com/rclone/rclone/lib/pacer`
- **Compatibility Risks**: Standard REST client and FS interface; zero maintenance risk with v1.76.0.

---

### 3. `backend/alldebrid/**`
- **Classification**: **New Backend**
- **Why It Exists**: Connects to the AllDebrid premium debrid API to browse torrent folders, magnet links, and cloud storage files as a virtual filesystem.
- **Upstream Dependencies**:
  - `github.com/rclone/rclone/fs`
  - `github.com/rclone/rclone/lib/rest`
  - `github.com/rclone/rclone/lib/pacer`
- **Compatibility Risks**: Read-mostly streaming backend with standard interfaces; fully compatible.

---

### 4. `backend/terabox/**`
- **Classification**: **New Backend**
- **Why It Exists**: Enables read, write, directory move, rapid upload, and chunked multipart uploads to TeraBox (formerly Dubox) storage.
- **Upstream Dependencies**:
  - `github.com/rclone/rclone/fs`
  - `github.com/rclone/rclone/lib/rest`
  - `github.com/rclone/rclone/lib/pacer`
- **Compatibility Risks**: Adheres to standard rclone optional interfaces (`fs.Mover`, `fs.Copier`, `fs.DirMover`, `fs.Purger`, `fs.PutStreamer`); fully compatible.

---

### 5. `backend/all/all.go`
- **Classification**: **Feature Extension**
- **Why It Exists**: Acts as the master registry driver, ensuring that importing `backend/all` registers all backends into `fs.Registry` via Go `init()` side-effects.
- **Upstream Dependencies**: Package imports for all active backends.
- **Compatibility Risks**: Overwriting this file would drop custom backends. The file has been updated to contain both the new upstream backends (`dosya`, `kdrive`) and all 4 custom backends.

---

### 6. `backend/local/local.go`
- **Classification**: **Performance Optimization**
- **Why It Exists**:
  ```go
  func (o *Object) SetHash(_ context.Context, ty hash.Type, value string) {
      o.fs.objectMetaMu.Lock()
      if o.hashes == nil {
          o.hashes = make(map[hash.Type]string)
      }
      o.hashes[ty] = value
      o.fs.objectMetaMu.Unlock()
  }
  ```
  Allows upload pipelines (e.g. `teldrive`) that calculate hashes on the fly during transfer to cache that hash back onto the local source object. Subsequent calls to `o.Hash(...)` will return the cached hash immediately without reading the disk again.
- **Upstream Dependencies**: `fs.Object`, `o.fs.objectMetaMu`.
- **Compatibility Risks**: Upstream introduced security fixes for planted symlinks (`remove`, `lstatRoot`). `SetHash` was cleanly integrated into the updated file without touching the symlink security logic.

---

### 7. `fs/types.go` & `fs/override.go`
- **Classification**: **Feature Extension**
- **Why It Exists**:
  - `fs/types.go` defines `HashSetter`:
    ```go
    type HashSetter interface {
        SetHash(ctx context.Context, ty hash.Type, value string)
    }
    ```
  - `fs/override.go` forwards `SetHash` through wrapped objects (`OverrideRemote`).
- **Upstream Dependencies**: `fs/hash`.
- **Compatibility Risks**: Minimal; upstream did not alter `fs/types.go` or `fs/override.go`.

---

### 8. `fs/operations/reopen.go` & `lib/pool/reader_writer.go`
- **Classification**: **Feature Extension / Performance Optimization**
- **Why It Exists**:
  ```go
  func (h *ReOpen) Account(n int) *ReOpen {
      if h.account != nil {
          h.account(n)
      }
      return h
  }
  ```
  and
  ```go
  func (rw *RW) Account(n int) *RW {
      if rw.account != nil {
          rw.account(n)
      }
      return rw
  }
  ```
  Enables upload routines to credit progress accounting when parts of a file are skipped (deduplicated or resumed from previous sessions) without physically reading bytes through the reader.
- **Upstream Dependencies**: `fs/accounting`, `lib/pool`.
- **Compatibility Risks**: Low. Both methods are purely additive and do not alter existing reader semantics.

---

### 9. `.github/workflows/build.yml`
- **Classification**: **Feature Extension / Override**
- **Why It Exists**: Upstream's build workflow relies on external packaging scripts, whereas the fork requires automated static binary generation across Linux, Windows (CGO static WinFsp), and Android NDK, with automatic GitHub release publishing.
- **Upstream Dependencies**: Go 1.27 compiler, Ubuntu GitHub Actions runners.
- **Compatibility Risks**: Must remain fork-managed to ensure build artifacts match expectations.

---

### 10. `fs/registry.go`
- **Classification**: **Bug Fix / Override**
- **Why It Exists**: Changes `Errorf` to `Debugf` when overview metadata is absent. Third-party backends not compiled with upstream's static documentation bundle would otherwise trigger console errors during startup.
- **Upstream Dependencies**: `fs/registry`, `docs/data/overview`.
- **Compatibility Risks**: None; integrated cleanly inside upstream's `if info.Overview == nil` block.
