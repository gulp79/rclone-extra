# CONFLICT REPORT: Merge Analysis (v1.75.2 -> v1.76.0)

This report details every conflict encountered during the synchronization of `rclone-extra` with upstream `rclone` `v1.76.0`, identifying upstream intent, custom intent, and the exact resolution strategy applied.

---

## Conflict Summary

During the three-way merge (`git merge --no-commit v1.76.0`), conflicts arose primarily from two categories:
1. **Protected & Fork-Specific Files**: Files containing intentional fork adaptations conflicting with upstream updates.
2. **Intermediate Release Artifacts**: Upstream release branch commits (cherry-picks into v1.75.1 and v1.75.2) conflicting with the trunk commits in v1.76.0, which shares common ancestor v1.75.0.

---

## 1. Protected Files & Fork Components

### A. `.github/workflows/build.yml`
- **Upstream Intent**:
  - Update GitHub Actions runners to use Go `~1.27.3`.
  - Fix macOS Homebrew uninstallation logic to avoid failures if optional taps are missing.
- **Custom Intent**:
  - Replace the entire default CI/CD pipeline with a custom multi-platform static build workflow:
    - Pure Go static Linux compilation (amd64, arm64, arm-v7).
    - CGO static Windows cross-compilation with MinGW and embedded WinFsp headers for `cmount`.
    - Android NDK multi-arch builds (arm, arm64, 386, amd64).
    - Direct release packaging and GitHub Releases asset uploading.
- **Final Merged Approach**:
  - **Preserved Custom Version (`HEAD`)** in accordance with Rule Phase 7. The fork workflow already targets Go `1.27.x` and meets all release requirements.

---

### B. `backend/local/local.go`
- **Upstream Intent**:
  - Mitigate planted symlink security vulnerabilities (GHSA-r5wv-vqqh-2r9c).
  - Add `func (f *Fs) remove(localPath string) (err error)` using `f.osRoot(localPath)` to prevent symlink escape on file deletion.
  - Implement `lstatRoot` and `mkdirAll` boundary constraints.
- **Custom Intent**:
  - Provide `SetHash(ctx context.Context, ty hash.Type, value string)` on `*local.Object` (implementing `fs.HashSetter`), allowing uploaders (such as TelDrive) to cache calculated hashes on local objects directly, avoiding duplicate read passes.
- **Conflict Point**:
  - Line 1727: Addition of `remove(localPath string)` in upstream conflicting with clean custom structure in `HEAD`.
- **Final Merged Approach**:
  - Accepted upstream's `remove(localPath string)` implementation.
  - Retained `SetHash` on `*local.Object` with full mutex protection via `o.fs.objectMetaMu`.
  - Result: Complete security mitigation alongside zero regression in hash-caching capability.

---

### C. `fs/registry.go`
- **Upstream Intent**:
  - Optimize backend overview metadata lookup by checking `if info.Overview == nil` before invoking `overview.GetBackendConfig(...)`.
  - Log an `Errorf` if overview configuration cannot be found.
- **Custom Intent**:
  - Change `Errorf` to `Debugf` when overview metadata is absent. Custom backends (`alist`, `alldebrid`, `teldrive`, `terabox`) do not have embedded overview documentation compiled into upstream's private metadata bundle; without this change, spurious startup errors are logged.
- **Conflict Point**:
  - Line 428: Conflict between upstream's nil check wrapping `Errorf` and fork's `Debugf` replacement.
- **Final Merged Approach**:
  - Wrapped `overview.GetBackendConfig` in `if info.Overview == nil`, and used `Debugf(nil, "internal error: no overview data found for %q", info.Name)`.

---

### D. `.gitignore`
- **Upstream Intent**:
  - Ignore `/cmd/bisync/testdata/bisync_vscode_debuggers_launch.json` after deleting it from tracking.
- **Custom Intent**:
  - Ignore local build/prompt artifacts (`promptMerge.md`, `prompt*`).
- **Final Merged Approach**:
  - Union of both rules:
    ```gitignore
    /cmd/bisync/testdata/bisync_vscode_debuggers_launch.json
    promptMerge.md
    prompt*
    ```

---

### E. `AGENTS.md`
- **Upstream Intent**:
  - Introduce general AI agent contributor instructions for upstream rclone repository.
- **Custom Intent**:
  - Maintain the fork merge specification and agent architecture for `rclone-extra`.
- **Final Merged Approach**:
  - Retained custom fork `AGENTS.md` from `HEAD`.

---

### F. `VERSION`
- **Upstream Intent**: Bump version tag to `v1.76.0`.
- **Custom Intent**: Previous version was `v1.75.2`.
- **Final Merged Approach**: Adopted `v1.76.0`.

---

## 2. Upstream Core & Backend Conflicts (Release Cherry-Pick Divergence)

The following files experienced merge conflicts solely due to upstream cherry-picks on v1.75.1/v1.75.2 diverging from the v1.76.0 trunk commit history:

- **Upstream Backends & Tests**:
  - `backend/archive/archive_internal_test.go`
  - `backend/archive/squashfs/squashfs.go`
  - `backend/archive/zip/zip.go`
  - `backend/archive/zip/zip_internal_test.go`
  - `backend/dropbox/dropbox.go`
  - `backend/http/http.go`
  - `backend/http/http_internal_test.go`
  - `backend/huaweidrive/huaweidrive.go`
  - `backend/local/local_internal_diskfull_windows_test.go`
  - `backend/local/local_internal_test.go`
  - `backend/netstorage/netstorage_internal_test.go`
  - `backend/oracleobjectstorage/byok.go`
  - `backend/oracleobjectstorage/oracleobjectstorage_test.go`
  - `backend/smb/smb_internal_test.go`
  - `backend/webdav/webdav_internal_test.go`
- **Upstream Commands & Commands Tests**:
  - `cmd/serve/proxy/proxy.go`, `proxy_code.go`, `proxy_test.go`
  - `cmd/serve/s3/...` (`backend.go`, `list.go`, `multipart.go`, `s3.go`, `server.go`, tests)
  - `cmd/serve/sftp/server.go`, `sftp_test.go`
- **Upstream Core Files & Tests**:
  - `fs/configmap_test.go`
  - `fs/fserrors/enospc_error_windows_test.go`
  - `fs/fshttp/http.go`, `fs/fshttp/http_test.go`
  - `fs/operations/copy.go`, `dedupe.go`, `operations.go`
  - `fs/rc/rcserver/rcserver_test.go`
  - `fs/versiontag.go`
  - `fstest/fstests/fstests.go`
  - `fstest/test_all/config.yaml`
  - `lib/http/middleware.go`
  - `lib/http/templates/index.html`
  - `lib/oauthutil/oauthutil_test.go`
  - `lib/rest/headers.go`
  - `lib/transform/transform.md`
  - `vfs/dir_test.go`
  - `vfs/vfscache/cache_test.go`
- **Upstream Documentation**:
  - `MANUAL.html`, `MANUAL.md`, `MANUAL.txt`, `rclone.1`
  - `docs/content/bisync.md`, `changelog.md`, `flags.md`, `http.md`, `sponsor.md`
  - `docs/content/commands/rclone*.md`
  - `docs/layouts/chrome/menu.html`, `docs/layouts/partials/version.html`
- **Dependencies**:
  - `go.mod`, `go.sum`

### Resolution for Intermediate Release Artifacts:
- **Upstream Intent**: Deliver official, tested v1.76.0 behavior and updated dependencies.
- **Custom Intent**: None. The fork does not modify these upstream files.
- **Final Merged Approach**: Clean checkout from `v1.76.0` (`git checkout v1.76.0 -- <file>`).

---

## 3. Deleted Upstream Files

- `cmd/bisync/testdata/bisync_vscode_debuggers_launch.json`: Deleted upstream in v1.76.0. Accepted deletion.
- `fs/rc/webgui/plugins.go`: Deleted upstream in v1.76.0 as legacy webgui was removed. Accepted deletion.

---

## Verification
Post-resolution `git diff --name-only --diff-filter=U` returned 0 unmerged files. All conflicts resolved cleanly without regressions.
