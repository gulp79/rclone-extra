# COMPATIBILITY REPORT: Static Analysis for v1.76.0 Synchronization

This report provides detailed static code analysis of `rclone-extra` following synchronization with upstream `rclone` `v1.76.0`. Per instructions, no build, test, or CI execution was performed; all assessments are based strictly on source code inspection.

---

## 1. Interface & Symbol Compatibility

### A. Core `fs.Fs` and `fs.Object` Interfaces
- **Definition Location**: `fs/types.go`, `fs/fs.go`
- **Analysis**:
  - `fs.Fs` interface: Upstream v1.76.0 introduced zero additions, deletions, or signature modifications to the base `fs.Fs` interface. All 4 custom backends (`alist`, `alldebrid`, `teldrive`, `terabox`) implement all required methods: `Name()`, `Root()`, `String()`, `Precision()`, `Hashes()`, `Features()`, `List()`, `NewObject()`, `Put()`, `Mkdir()`, `Rmdir()`, `Purge()`.
  - `fs.Object` interface: Unchanged. Required methods `String()`, `Remote()`, `ModTime()`, `Size()`, `Fs()`, `Hash()`, `Storable()`, `SetModTime()`, `Open()`, `Update()`, `Remove()` remain fully satisfied across all custom objects.

### B. Optional Interfaces
- **`fs.ListRFinder`**:
  - `fs/features.go` defines `ListR(ctx context.Context, dir string, callback ListRCallback) error`.
  - `backend/teldrive/teldrive.go` implements:
    ```go
    func (f *Fs) ListR(ctx context.Context, dir string, callback fs.ListRCallback) error
    ```
    Signatures match exactly. Fast-listing via `--fast-list` is fully supported.
- **`fs.Mover` & `fs.Copier`**:
  - Implemented in `backend/teldrive`, `backend/alist`, and `backend/terabox`.
  - Signatures:
    ```go
    Move(ctx context.Context, src fs.Object, remote string) (fs.Object, error)
    Copy(ctx context.Context, src fs.Object, remote string) (fs.Object, error)
    ```
    Identical to upstream requirements.
- **`fs.DirMover`**:
  - Implemented in `backend/teldrive`, `backend/alist`, and `backend/terabox`.
  - Signature:
    ```go
    DirMove(ctx context.Context, src fs.Fs, srcRemote, dstRemote string) error
    ```
    Matches upstream specification.
- **`fs.Purger`**:
  - Implemented in `backend/teldrive`, `backend/alist`, and `backend/terabox`.
  - Signature:
    ```go
    Purge(ctx context.Context, dir string) error
    ```
    Matches upstream specification.
- **`fs.PutStreamer`**:
  - Implemented in `backend/alist` and `backend/terabox`.
  - Signature:
    ```go
    PutStream(ctx context.Context, in io.Reader, src fs.ObjectInfo, options ...fs.OpenOption) (fs.Object, error)
    ```
    Matches upstream specification.
- **`fs.CleanUpper`**:
  - Implemented in `backend/teldrive`.
  - Signature:
    ```go
    CleanUp(ctx context.Context) error
    ```
    Matches upstream specification.

---

## 2. Package-by-Package Inspection

### A. `fs` Package
- **Logging APIs**:
  - Upstream added context-aware structured logging functions: `fs.DebugfCtx`, `fs.ErrorfCtx`, `fs.InfofCtx`, `fs.LogfCtx`.
  - Upstream retained all legacy uncontextualized wrappers (`fs.Debugf`, `fs.Errorf`, `fs.Infof`, `fs.Logf`).
  - Custom backends use `fs.Debugf`, `fs.Errorf`, and `fs.Infof`. Because the uncontextualized wrappers remain in `fs/log.go`, no call sites in custom backends are broken.
- **Overview and Registry**:
  - `fs/registry.go` in upstream v1.76.0 introduced `if info.Overview == nil` guarding `overview.GetBackendConfig(...)`.
  - In our merged code, if overview metadata is absent, `Debugf` is called instead of `Errorf`. This prevents spurious error logs while retaining full registration mechanics.

### B. `fs/operations` Package
- **`operations.ReOpen`**:
  - Upstream updated internal logging to `fs.DebugfCtx(h.ctx, ...)`.
  - Custom method `Account(n int) *ReOpen` was re-applied cleanly.
  - Used in `backend/teldrive/upload.go`:
    ```go
    if acc, ok := in.(interface{ Account(int) *operations.ReOpen }); ok {
        acc.Account(int(stored.size))
    }
    ```
    Confirmed compatible.

### C. `lib/pool` Package
- **`pool.RW`**:
  - Upstream enhanced `pool.RW` with safe double-close handling (`rw.closed = true`) and `ErrClosed`.
  - Custom method `Account(n int) *RW` was re-applied cleanly.
  - Used in `backend/teldrive/upload.go`:
    ```go
    if acc, ok := in.(interface{ Account(int) *pool.RW }); ok {
        acc.Account(int(stored.size))
    }
    ```
    Confirmed compatible.

### D. `lib/rest` Package
- **`MultipartUpload`**:
  - Upstream v1.76.0 enhanced `MultipartUpload` by returning a wrapped `*multipartBody` whose `Close()` method aborts the pipe reader and waits for the multipart writer goroutine to terminate.
  - Function signature remained:
    ```go
    MultipartUpload(ctx context.Context, in io.Reader, params url.Values, contentName, fileName string, contentType string) (io.ReadCloser, string, int64, error)
    ```
  - Custom backends calling `MultipartUpload` (e.g. `teldrive`, `terabox`) benefit directly from leak prevention without code changes.

### E. `lib/pacer` Package
- Upstream v1.76.0 made zero changes to `lib/pacer`.
- Custom backends utilizing `pacer.New(...)`, `pacer.SetRetries(...)`, `pacer.Call(...)` have 100% API stability.

### F. `fs/rc/rcserver` Package
- Upstream v1.76.0 added security controls:
  - `maxUnauthenticatedBodySize = 64 << 10`
  - Body rejection before reading payload when routes are unauthenticated or missing.
  - Fixed regexp `^\[(.*?)\](.*)$`.
- No custom backends interact with `rcserver` directly; all RC endpoints in custom backends register via `rc.Add(...)`, which remains fully intact.

---

## 3. Backend Registration Verification

`backend/all/all.go` registers all backends through package-level initialization.
The merged file was inspected to ensure:
```go
import (
	// Active file systems
	_ "github.com/rclone/rclone/backend/alias"
	_ "github.com/rclone/rclone/backend/alist"
	_ "github.com/rclone/rclone/backend/alldebrid"
	_ "github.com/rclone/rclone/backend/archive"
	...
	_ "github.com/rclone/rclone/backend/dosya"
	...
	_ "github.com/rclone/rclone/backend/kdrive"
	...
	_ "github.com/rclone/rclone/backend/swift"
	_ "github.com/rclone/rclone/backend/teldrive"
	_ "github.com/rclone/rclone/backend/terabox"
	_ "github.com/rclone/rclone/backend/ulozto"
	...
)
```
- **Custom Backends Present**:
  - `alist`: Registered via `backend/alist/alist.go:init()` -> `fs.Register(&fs.RegInfo{ Name: "alist", ... })`
  - `alldebrid`: Registered via `backend/alldebrid/alldebrid.go:init()` -> `fs.Register(&fs.RegInfo{ Name: "alldebrid", ... })`
  - `teldrive`: Registered via `backend/teldrive/teldrive.go:init()` -> `fs.Register(&fs.RegInfo{ Name: "teldrive", ... })`
  - `terabox`: Registered via `backend/terabox/terabox.go:init()` -> `fs.Register(&fs.RegInfo{ Name: "terabox", ... })`
- **New Upstream Backends Present**:
  - `dosya`: Registered via `backend/dosya/dosya.go:init()`
  - `kdrive`: Registered via `backend/kdrive/kdrive.go:init()`

---

## 4. Dependencies (`go.mod` / `go.sum`)

- `go.mod` was updated to upstream `v1.76.0` specification.
- Go toolchain directive: `go 1.26.0` (with GitHub Actions runner using Go `1.27.x`).
- godebug directives:
  ```
  godebug (
      multipathtcp=0
      x509negativeserial=1
  )
  ```
- Dependency analysis:
  - Custom backends use standard Go library packages (`context`, `crypto`, `encoding/json`, `fmt`, `io`, `net/http`, `net/url`, `path`, `sync`, `time`) and internal rclone libraries (`fs`, `fs/hash`, `lib/rest`, `lib/pacer`, `lib/pool`).
  - No custom backend introduces third-party module dependencies outside rclone's standard `go.mod`.
  - All upstream dependency updates (e.g. AWS SDK v2, Azure SDK, Google APIs, prometheus, etc.) do not affect custom backends.

---

## 5. Potential Compatibility Risks & Mitigations

1. **Planted Symlink Defenses (`backend/local/local.go`)**:
   - *Risk*: Upstream's new `remove(localPath string)` resolves through `f.osRoot(localPath)`. Could this interfere with `SetHash`?
   - *Analysis*: `SetHash` operates exclusively on in-memory object metadata (`o.hashes` map protected by `o.fs.objectMetaMu`) and does not touch file descriptors or filesystem path resolution. Zero risk of collision.
2. **Go 1.27 Runtime Behavior**:
   - *Risk*: Fork build uses Go 1.27.x runners.
   - *Analysis*: Upstream v1.76.0 explicitly targets Go 1.27 (`build: update to go1.27 and make go1.26 the minimum required version`). The fork CI configuration (`.github/workflows/build.yml`) specifies `go-version: '1.27.x'`, fully matching upstream compiler requirements.
3. **Regex URL Matching in RC**:
   - *Risk*: Previous preliminary commit contained an unescaped curly brace in regex.
   - *Analysis*: Corrected to upstream's canonical `var fsMatch = regexp.MustCompile(`^\[(.*?)\](.*)$`)`.

---

## Conclusion

Static code inspection reveals **zero broken imports, zero API incompatibilities, zero registration failures, and zero compile blockers**. The merged codebase preserves all custom backends and core modifications in full alignment with rclone v1.76.0 standards.
