# Initial 100 Communities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Securely support multiple Platform Admin-owned Communities and prepare a documented, idempotent dry-run importer for exactly 100 initial Communities.

**Architecture:** Ordinary users retain the singleton `communityOwnership/{uid}` invariant. Active Platform Admins use the additive `platformAdminCommunityOwnership/{uid}/communities/{communityId}` ledger, with canonical Community documents and projections created atomically. A separate Admin SDK tool validates a researched JSON catalog and defaults to a read-only dry-run.

**Tech Stack:** Flutter/Dart, Cloud Firestore, Firestore Security Rules Emulator, Node.js, Firebase Admin SDK, node:test.

**Spec:** `docs/superpowers/specs/2026-10-21-initial-100-communities-design.md`

## Global Constraints

- Project is exactly `gubify-a3e2c`; verified admin UID is exactly `9dTaHzIR3FcEjK5KDAkCnImYbV93`.
- No production import, Firebase deploy, website/Worker change, merge, or Google Play release.
- Normal users remain limited to one owned Community.
- Revoked Platform Admins cannot create additional Communities.
- Existing Community, membership, XP, public projection, deletion, and Child Safety behavior must remain unchanged.
- Catalog contains exactly 100 English, open, original, non-duplicative records with documented evidence.

## Review Focus

- Admin revocation between client role lookup and atomic create must be denied by Rules.
- Name/slug collision owned by another UID must abort without overwriting data.
- Retry after a partially completed run must skip complete matches and report inconsistent state.
- Platform Admin deletion must remove only the matching ownership record while ordinary deletion remains unchanged.
- One hundred owner memberships must not be misrepresented as artificial users or popularity.

---

### Task 1: Research-backed 100-record catalog and validator

**Files:**
- Create: `tools/data/initial-communities.json`
- Create: `tools/initial-community-catalog.mjs`
- Create: `tests/tools/initial-community-catalog.test.mjs`

**Interfaces:**
- Produces: `loadAndValidateInitialCommunityCatalog(path)` returning 100 normalized records or throwing a precise validation error.

- [ ] Write RED tests for exact count, 20/20/60 grouping, unique canonical names/slugs, allowed types/language/access mode, description length, evidence classification, source URLs, and prohibited official-affiliation wording.
- [ ] Run `node --test tests/tools/initial-community-catalog.test.mjs` and verify the missing validator/catalog failure.
- [ ] Research current global, evergreen, niche, and emerging topics from authoritative sources; write exactly 100 records and implement the validator.
- [ ] Re-run the catalog tests and verify PASS.
- [ ] Commit catalog, validator, tests, and source documentation.

### Task 2: Firestore Rules for additive Platform Admin ownership

**Files:**
- Modify: `firestore.rules`
- Modify: `tests/firestore-rules/community-slugs.test.mjs`
- Modify: `tests/firestore-rules/platform-community-admin.test.mjs`
- Modify: `tests/firestore-rules/community-restrictions.test.mjs`

**Interfaces:**
- Produces: secure create/delete permissions for `platformAdminCommunityOwnership/{uid}/communities/{communityId}`.

- [ ] Add RED emulator tests proving active admins can create a second Community with complete projections, while normal users, anonymous users, missing-profile admins, revoked admins, wrong UIDs, forged roots, incomplete batches, and unrelated deletions fail.
- [ ] Add RED tests proving revocation blocks new creation but the canonical owner can still manage and finalize deletion of existing Communities.
- [ ] Run the focused Rules suites and verify expected failures.
- [ ] Implement minimal Rules helpers and `match` block, extending root create/final-delete invariants without changing normal ownership.
- [ ] Re-run focused Rules suites and verify PASS.
- [ ] Commit Rules and emulator tests.

### Task 3: Flutter repository and service multi-ownership path

**Files:**
- Modify: `lib/modules/community/repositories/community_repository.dart`
- Modify: `lib/modules/community/services/community_service.dart`
- Modify: `lib/modules/community/admin/platform_admin_service.dart`
- Create or modify: `test/modules/community/community_service_test.dart`
- Create: `test/modules/community/platform_admin_multi_ownership_test.dart`

**Interfaces:**
- Produces: admin-aware creation path and ordinary-user singleton path; preserves `currentUserOwnsCommunity()` semantics for UI gating.

- [ ] Add RED tests for normal second-create rejection, active-admin repeated creation, revoked-admin rejection, and atomic administrative ownership writes.
- [ ] Run focused tests and verify expected failures.
- [ ] Add role resolution and repository transaction branching; do not cache admin authority across operations.
- [ ] Update deletion finalization to remove the correct normal/admin ownership record.
- [ ] Re-run focused tests and verify PASS.
- [ ] Commit repository/service behavior and tests.

### Task 4: Multi-owned Community UI compatibility

**Files:**
- Modify only if required: `lib/screens/gub/create_gub_screen.dart`
- Modify only if required: `lib/screens/gub/my_gubs_screen.dart`
- Modify only if required: `lib/modules/profile/screens/personal_profile_screen.dart`
- Modify: corresponding tests under `test/screens/gub/` and `test/modules/profile/`

**Interfaces:**
- Consumes: Task 3 service methods and existing membership streams.
- Produces: all admin-owned Communities remain visible, openable, manageable, and individually deletable.

- [ ] Characterize existing multi-membership rendering and creation gating with tests.
- [ ] Add RED coverage only for proven single-owner assumptions.
- [ ] Make the minimum UI change required; preserve ordinary-user behavior.
- [ ] Run My Gubs, profile, creation, settings, and deletion tests.
- [ ] Commit UI compatibility changes only when necessary.

### Task 5: Idempotent Admin SDK importer

**Files:**
- Create: `tools/import-initial-communities.mjs`
- Create: `tests/tools/import-initial-communities.test.mjs`
- Modify: `package.json`

**Interfaces:**
- Consumes: validated catalog and Application Default Credentials.
- Produces: `runInitialCommunityImport({projectId, adminUid, apply, firestore, auth})` and structured created/skipped/conflict/failed report.

- [ ] Add RED tests with an in-memory Firestore seam for default dry-run, explicit apply guard, admin identity/role validation, complete document plan, collision refusal, idempotent retry, partial-state error, and bounded execution.
- [ ] Run importer tests and verify expected failures.
- [ ] Implement validation, plan generation, one-Community transactions, safe retry classification, and report output.
- [ ] Re-run importer tests and verify PASS.
- [ ] Commit importer, tests, and scripts.

### Task 6: Read-only production dry-run and integration validation

**Files:**
- No production data writes.
- Create: `docs/initial-communities-dry-run-report.md`

**Interfaces:**
- Produces: reviewable dry-run results without creating Communities.

- [ ] Run the importer without `--apply` using local credentials and explicit project `gubify-a3e2c`.
- [ ] Verify the administrator identity again and record candidate/create/skip/conflict/error totals.
- [ ] Confirm no target Community, registry, membership, projection, or ownership document was written.
- [ ] Validate `communityPublic` output shape against Explorer and website/sitemap fields.
- [ ] Commit the sanitized dry-run report.

### Task 7: Full verification and handoff

**Files:**
- Update only verification documentation if required.

- [ ] Run `git diff --check`.
- [ ] Run complete Firestore Rules suite through the emulator.
- [ ] Run all importer/catalog tests.
- [ ] Run `flutter analyze` and complete `flutter test`.
- [ ] Run focused Community creation, membership, profile, deletion, projection, and Platform Admin tests.
- [ ] Confirm no credentials, local key files, temporary output, or unrelated modifications are staged.
- [ ] Commit remaining documentation, push `feature/initial-100-communities`, and stop without import/deploy/merge.
