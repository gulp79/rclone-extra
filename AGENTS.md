# rclone-extra Merge Agents

## Mission

Maintain rclone-extra as a long-term fork of upstream rclone.

The repository contains custom backends and core modifications that must survive every upstream update.

The primary goal is preserving custom functionality while adopting upstream improvements.

Read `.custom-merge-manifest.yml` before any analysis.

All components declared there are merge-protected.

---

# Agent: Upstream Analyst

Responsibilities:

- Analyze upstream releases.

- Review changelogs.

- Review commits.

- Detect API changes.

- Detect interface changes.

- Detect package moves.

- Detect renamed functions.

- Detect renamed structs.

- Detect breaking changes.

Deliverables:

- UPSTREAM_ANALYSIS.md

- BREAKING_CHANGES.md

---

# Agent: Custom Code Auditor

Responsibilities:

Review all fork-specific modifications.

Protected files:

- .github/workflows/build.yml

- backend/local/local.go

- backend/all/all.go

- fs/override.go

- fs/types.go

- fs/operations/reopen.go

- fs/rc/rcserver/rcserver.go

- lib/pool/reader_writer.go

Protected directories:

- backend/teldrive/**

- backend/alist/**

- backend/alldebrid/**

- backend/terabox/**

Tasks:

- Understand purpose of modification.

- Categorize modification type.

- Detect upstream dependencies.

- Detect future maintenance risks.

- Detect compatibility issues.

Deliverables:

- CUSTOM_CHANGES_AUDIT.md

---

# Agent: Backend Compatibility Specialist

Responsibilities:

Ensure all custom backends remain compatible.

Protected backends:

- teldrive

- alist

- alldebrid

- terabox

Tasks:

- validate imports

- validate interfaces

- validate backend registration

- validate fs integration

- validate options structures

- validate command registration

Deliverables:

- BACKEND_COMPATIBILITY_REPORT.md

---

# Agent: Core Merge Engineer

Responsibilities:

Perform logical merge between upstream and custom modifications.

Rules:

- Start from upstream implementation.

- Reapply custom functionality.

- Adapt code to upstream APIs.

- Preserve behavior whenever possible.

Never:

- remove protected functionality

- delete custom backends

- overwrite protected files blindly

Deliverables:

- MERGE_REPORT.md

---

# Agent: Compatibility Validator

Responsibilities:

Inspect merged code for compatibility risks.

Verify:

- imports

- interfaces

- registrations

- fs integration

- rc integration

- workflow consistency

Analyze:

- API incompatibilities

- probable compile issues

- probable runtime issues

Do not:

- run builds

- run tests

- execute CI

Deliverables:

- COMPATIBILITY_REPORT.md

---

# Agent: Conflict Resolver

Responsibilities:

Review every merge conflict.

For each conflict identify:

- upstream intent

- custom intent

- final merged approach

Deliverables:

- CONFLICT_REPORT.md

---

# Agent: Workflow Guardian

Responsibilities:

Protect custom CI/CD configuration.

Protected file:

- .github/workflows/build.yml

Rules:

- Never overwrite automatically.

- Review upstream workflow changes.

- Recommend manual improvements.

- Preserve existing custom workflow behavior.

Deliverables:

- WORKFLOW_REVIEW.md

---

# Agent: Release Reviewer

Responsibilities:

Perform final review.

Checklist:

- custom backends preserved

- protected files preserved

- backend registrations verified

- workflow preserved

- upstream improvements integrated

- risks documented

Deliverables:

- FINAL_REVIEW.md

---

# Global Rules

Always read:

.custom-merge-manifest.yml

before starting.

Protected components must never be overwritten automatically.

When upstream and custom code differ:

1. Understand upstream purpose.

2. Understand custom purpose.

3. Build a compatible solution.

4. Preserve custom functionality.

Prefer adaptation over deletion.

Never perform blind overwrite.

Document all assumptions.

Document all compromises.

Document all unresolved risks.
