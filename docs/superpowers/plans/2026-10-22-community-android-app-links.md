# Community Android App Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open canonical public Community links in the Android app while preserving Private Gub invite links and providing a Google Play fallback from the website.

**Architecture:** A typed parser and one lifecycle coordinator handle both `/join/{code}` and `/community/{slug}`. Community links wait for the authenticated navigation shell, resolve a single `communityPublic/{slug}` projection, and push the existing public-details screen; the website explicitly launches the equivalent Android intent and publishes the Play signing association.

**Tech Stack:** Flutter/Dart, `app_links`, Firebase Firestore, Android manifest App Links, Next/React/TypeScript, Node test runner.

**Spec:** `docs/superpowers/specs/2026-10-22-community-android-app-links-design.md`

## Global Constraints

- Preserve `/join/{code}` behavior exactly.
- Accept only canonical HTTPS links on `gubify.com` and strict canonical slugs.
- Preserve pending destinations through sign-in, email verification, and profile completion.
- Do not join a Community or create a join request from the link handler.
- Do not change Firestore Rules, Community permissions, moderation, or membership behavior.
- Use Android package `com.gubify.app` and Play fallback `https://play.google.com/store/apps/details?id=com.gubify.app`.
- Publish the exact Play App Signing SHA-256 from the spec in `assetlinks.json`.
- No iOS integration, merge, deployment, or Android release.
- Use explicit `git add <paths>`; never `git add .`.

## Review Focus

- An initial link arriving before authentication must open only after the shell is ready.
- Repeated delivery of the same Community link must not stack routes.
- A different link arriving during an in-flight route must remain pending rather than disappear.
- Malformed or mismatched `communityPublic` data must never route to another Community.
- Android fallback must occur only after an explicit CTA click and must not redirect desktop page loads.

---

### Task 1: Typed App Link Parsing

**Files:**
- Create: `lib/core/app_links/gubify_app_link.dart`
- Create: `lib/core/app_links/gubify_app_link_parser.dart`
- Test: `test/core/app_links/gubify_app_link_parser_test.dart`
- Preserve: `lib/core/invites/invite_link_parser.dart`

**Interfaces:**
- Produces: `sealed class GubifyAppLink`, `PrivateGubInviteLink`, `CommunityAppLink`, and `GubifyAppLinkParser.parse(Uri)`.
- Consumes: `InviteLinkParser.parse(Uri)` for existing invite semantics.

- [ ] Write parser tests for valid visible/canonical invite codes and valid canonical Community slugs.
- [ ] Write parser tests rejecting HTTP, wrong/lookalike host, port, user-info, uppercase/malformed/encoded slugs, empty or extra segments; prove query and fragment do not affect valid links.
- [ ] Run `flutter test --no-pub test/core/app_links/gubify_app_link_parser_test.dart -r expanded` and observe RED because the typed parser does not exist.
- [ ] Implement the minimal typed destination and parser while delegating invite validation to `InviteLinkParser`.
- [ ] Re-run the focused parser test and existing `test/core/invites/invite_link_parser_test.dart`; expect GREEN.

### Task 2: Lifecycle Coordinator and Pending Authentication Destination

**Files:**
- Create: `lib/core/app_links/gubify_app_link_coordinator.dart`
- Modify: `lib/main.dart`
- Test: `test/core/app_links/gubify_app_link_coordinator_test.dart`
- Test: `test/core/invites/invite_link_coordinator_test.dart`
- Remove after migration: `lib/core/invites/invite_link_coordinator.dart`

**Interfaces:**
- Consumes: `GubifyAppLinkParser.parse(Uri)`.
- Produces: `GubifyAppLinkCoordinator(source, openInvite, openCommunity)`, `start()`, `markNavigationReady()`, and `dispose()`.

- [ ] Write coordinator tests for an initial/cold link before readiness, foreground delivery after readiness, delayed readiness representing login/email/profile completion, duplicate suppression, a distinct queued link, errors, idempotent start, and disposal.
- [ ] Run the new test and observe RED because the generic coordinator is missing.
- [ ] Implement one `AppLinks.uriLinkStream` subscription, one pending typed destination, in-flight deduplication, and sequential draining.
- [ ] Update `main.dart` to use the generic coordinator and retain `_openJoin` unchanged.
- [ ] Re-run new and existing coordinator/parser tests; expect GREEN and unchanged invite behavior.

### Task 3: Community Projection Resolution and Navigation

**Files:**
- Modify: `lib/modules/community/repositories/community_repository.dart`
- Modify: `lib/modules/community/services/community_service.dart`
- Modify: `lib/main.dart`
- Create: `test/modules/community/community_app_link_resolution_test.dart`
- Modify: `test/core/app_links/gubify_app_link_coordinator_test.dart`

**Interfaces:**
- Produces: `CommunityRepository.resolvePublicCommunityIdBySlug(String slug)` and `CommunityService.resolvePublicCommunityIdBySlug(String slug)` returning `Future<String?>`.
- Consumes: `CommunityPublicDetailsScreen(communityId: ...)` through the root navigator.

- [ ] Write repository tests for valid projection, missing projection, empty ID, and a projection whose stored slug differs from the requested document.
- [ ] Write a navigation seam/widget test proving a resolved ID builds `CommunityPublicDetailsScreen` and unavailable resolution reports a safe message without pushing.
- [ ] Run the focused tests and observe RED because resolution/navigation is absent.
- [ ] Implement the single-document lookup and strict projection validation.
- [ ] Add `_openCommunitySlug` in `main.dart`, resolve after navigation readiness, and push the existing public-details screen through the existing root navigator/chat-overlay boundary.
- [ ] Re-run focused tests plus existing Community public-details tests for member/open/approval/restriction/unavailable states; expect GREEN.

### Task 4: Android App Links Manifest

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `test/core/app_links/android_app_links_manifest_test.dart`

**Interfaces:**
- Produces: verified Android routing for only `/join/` and `/community/` on `https://gubify.com`.

- [ ] Write a manifest test asserting package/activity configuration, `autoVerify`, HTTPS host, both exact path prefixes, and `flutter_deeplinking_enabled=false`.
- [ ] Run the test and observe RED because `/community/` is absent.
- [ ] Add the minimal Community intent-filter entry without changing the existing invite entry.
- [ ] Re-run the manifest test and process Android debug resources; expect GREEN.

### Task 5: Website Canonical Link, Android Intent, and CTA

**Files (website worktree):**
- Modify: `lib/gubify-app-links.ts`
- Modify: `app/community/[slug]/community-cta.tsx`
- Modify: `tests/community-page.test.mjs`
- Create: `tests/gubify-app-links.test.mjs`

**Interfaces:**
- Produces: canonical URL builder and Android Community intent builder using package `com.gubify.app` and the Play fallback.
- Consumes: validated server-provided Community slug.

- [ ] Write pure tests for canonical HTTPS URL, slug encoding/validation, Android package, HTTPS intent route, and encoded Play fallback.
- [ ] Update rendered-page/CTA tests to require an enabled CTA, explicit-click-only behavior, Android launch, and no automatic redirect or iOS integration.
- [ ] Run focused website tests and observe RED because constants/builders are empty.
- [ ] Implement pure builders and update the CTA so only an explicit Android click launches the intent; desktop/non-Android remains on the SEO page.
- [ ] Re-run focused website tests; expect GREEN with existing metadata and Community rendering intact.

### Task 6: Digital Asset Links Artifact

**Files (website worktree):**
- Create: `public/.well-known/assetlinks.json`
- Create: `tests/assetlinks.test.mjs`
- Modify if needed: `package.json`

**Interfaces:**
- Produces: static association for `com.gubify.app` and the exact Google Play App Signing fingerprint in the spec.

- [ ] Write a test that reads the artifact and asserts valid JSON, exact relation, package, one exact fingerprint, and no secrets.
- [ ] Add a build/render check proving `/.well-known/assetlinks.json` is copied/served as a static artifact without a redirect.
- [ ] Run the tests and observe RED because the artifact is absent.
- [ ] Add the minimal static JSON file.
- [ ] Re-run the focused tests and production website build; expect GREEN.

### Task 7: Cross-Repository Regression Verification

**Files:**
- No production edits unless a failing test demonstrates an in-scope defect.

**Interfaces:**
- Consumes all prior tasks and produces verified branch heads.

- [ ] In the app worktree run all focused App Link, invite, Community public-details, startup/auth-navigation, and Android manifest tests.
- [ ] Run `flutter test` and require exit code 0.
- [ ] Run `flutter analyze` and report any baseline warnings separately from introduced errors.
- [ ] Run `git diff --check` and verify `firestore.rules` is byte-for-byte unchanged from `origin/master`.
- [ ] In the website worktree run focused Community/App Links/assetlinks tests, the full relevant test command, lint, and production build.
- [ ] Run website `git diff --check`; scan both diffs for credentials, signing files, unrelated changes, and automatic page redirects.

### Task 8: Commit, Push, and Publication Handoff

**Files:**
- App and website changes enumerated by the prior tasks.

**Interfaces:**
- Produces two pushed feature branches ready for review; no merge or deployment.

- [ ] Commit app code/tests/config with explicit paths after verification.
- [ ] Commit website code/tests/static artifact with explicit paths after verification.
- [ ] Push `feature/community-app-links` normally in each repository without force.
- [ ] Confirm both working trees are clean and report exact commit SHAs.
- [ ] Document manual publication order: merge website/app, deploy website, verify public assetlinks HTTP 200/no redirect/JSON content type, build/upload Android release, verify domain association, test installed and not-installed devices.
