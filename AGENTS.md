# rclone-extra Merge Agents

## Mission

Maintain rclone-extra as a long-term fork of upstream rclone.

The repository contains custom backends and core modifications that must survive every upstream update.

The primary goal is preserving custom functionality while adopting upstream improvements.

Read `.custom-merge-manifest.yml` before any analysis.

All components declared there are merge-protected.

---

# Protected Components

Protected files:
- `.github/workflows/build.yml`
- `backend/local/local.go`
- `backend/all/all.go`
- `fs/override.go`
- `fs/types.go`
- `fs/operations/reopen.go`
- `fs/rc/rcserver/rcserver.go`
- `fs/registry.go`
- `lib/pool/reader_writer.go`

Protected directories:
- `backend/teldrive/**`
- `backend/alist/**`
- `backend/alldebrid/**`
- `backend/terabox/**`

---

# Operational Rules & Optimizations

### 1. Fast-Track Conflict Resolution (Efficiency & Token Optimization)
When performing `git merge <target-tag>`:
- Check if conflicted files are declared in `.custom-merge-manifest.yml` or have custom fork commits (`git diff <base-tag> HEAD -- <file>`).
- For any file NOT in the manifest and NOT modified by the fork (e.g. upstream docs, tests, unchanged backends), **immediately resolve in favor of upstream in batch**:
  ```bash
  git checkout <target-tag> -- <unmodified-file>
  ```
- Do NOT spend tokens or roundtrips performing deep line-by-line analysis on standard upstream files.
- Focus deep 3-way merge strictly on protected components and configuration (`.gitignore`, `VERSION`).

### 2. Line Endings (CRLF vs LF)
- Always ensure Unix line endings (LF) for all Go code and configuration files.
- Prevent Windows CRLF conversions from creating massive spurious git diffs against upstream.

### 3. Reporting Policy
- Detailed analysis, conflict summaries, and compatibility audits are reported **directly in the chat output**.
- Do NOT create redundant markdown files in the repository unless explicitly requested.
- Any generated report files are local development artifacts, ignored via `.gitignore`, and **must never be committed** to the production branch.

---

# Agent Responsibilities

### Upstream Analyst
- Analyze upstream releases, changelogs, commits, and breaking changes / CVEs.

### Custom Code Auditor
- Review all fork-specific modifications declared in `.custom-merge-manifest.yml`.
- Categorize modification types and detect upstream dependencies.

### Backend Compatibility Specialist
- Ensure all 4 custom backends (`teldrive`, `alist`, `alldebrid`, `terabox`) remain fully compatible.
- Validate registrations in `backend/all/all.go`.

### Core Merge Engineer
- Perform logical merge between upstream and custom modifications.
- Start from upstream implementation and re-apply custom functionality on top.
- Retain existing custom behavior wherever possible.

### Compatibility Validator
- Inspect interfaces (`fs.Fs`, `fs.Object`, etc.), registrations, imports, and operations.
- Static code analysis only: **Do NOT run builds, tests, or CI workflows**.

### Workflow Guardian
- Protect custom CI/CD configuration (`.github/workflows/build.yml`).
- Preserve static MinGW CGO WinFsp, Android NDK, and pure-static Linux builds.

---

# Global Merge Rules

Always read `.custom-merge-manifest.yml` before starting.

Protected components must never be overwritten automatically.

When upstream and custom code differ:
1. Understand upstream purpose.
2. Understand custom purpose.
3. Build a compatible solution.
4. Preserve custom functionality.

Prefer adaptation over deletion.
Never perform blind overwrite.
Document all assumptions, compromises, and risks clearly.
