# Community Direct Asks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add direct Community Ask creation from Community Home while preserving deterministic Chat Asks.

**Architecture:** Extend the existing Ask model with canonical `text` and optional `sourceMessageId`, expose two explicit create APIs through Service and Repository, and add a focused stateful create card to the existing mutually-exclusive Home header. Rules validate shared fields and branch by origin.

**Tech Stack:** Flutter/Dart, Firebase Auth, Cloud Firestore, Firestore Security Rules, Flutter widget tests, Firebase Rules emulator.

**Spec:** `docs/superpowers/specs/2026-08-28-community-direct-asks-design.md`

## Global Constraints

- Ask text limit is exactly `AppLimits.communityMessageMaxLength` (2000).
- No migration or fallback for `sourcePreview`.
- No new Firestore index unless a focused query test proves one is required.
- Do not modify Private Gubs or Community Chat history boundaries.
- Do not commit, push, or deploy.

---

### Task 1: Canonical Ask model and creation APIs

**Files:**
- Modify: `lib/modules/community/models/community_ask_model.dart`
- Modify: `lib/modules/community/repositories/community_ask_repository.dart`
- Modify: `lib/modules/community/services/community_ask_service.dart`
- Modify: `lib/modules/community/services/community_service.dart`
- Test: `test/modules/community/community_ask_model_test.dart`
- Test: `test/modules/community/community_ask_service_test.dart`

**Interfaces:**
- Produces: `createAskFromMessage({communityId, sourceMessageId, type})`
- Produces: `createDirectAsk({communityId, text, type})`
- Produces: `CommunityService.currentDisplayName()`

- [ ] Write failing tests for canonical `text`, nullable/absent `sourceMessageId`, normalized direct text, each type, linked-account guard, and preserved Chat duplicate mapping.
- [ ] Run the two focused test files and confirm failures are caused by missing APIs/model fields.
- [ ] Implement the minimal model, cache-backed identity resolver, Service methods, and Repository methods.
- [ ] Run the two focused test files and confirm they pass.

### Task 2: Direct Create Ask card and Home state

**Files:**
- Create: `lib/modules/community/widgets/community_create_ask_card.dart`
- Modify: `lib/modules/community/widgets/community_home_content.dart`
- Test: `test/modules/community/community_create_ask_card_test.dart`
- Modify: `test/modules/community/community_asks_header_test.dart`

**Interfaces:**
- Consumes: `CommunityAskService.createDirectAsk(...)`
- Produces: third `Create` header action and mutually-exclusive `createAsk` panel.

- [ ] Write failing widget tests for plus visibility, toggle/mutual exclusion, empty/type validation, all three categories, double-tap protection, success close/reset, and error state preservation.
- [ ] Run the two focused widget test files and confirm expected failures.
- [ ] Implement the compact card and Home integration with injected create callback for deterministic tests.
- [ ] Run the focused widget tests and confirm they pass at normal and 320px width.

### Task 3: Consumers use canonical Ask text

**Files:**
- Modify: `lib/modules/community/widgets/community_ask_card.dart`
- Modify: `lib/modules/community/widgets/community_active_asks_section.dart`
- Modify: `lib/modules/community/screens/community_ask_details_screen.dart`
- Modify: `lib/modules/community/widgets/community_chat_view.dart`
- Test: `test/modules/community/community_asks_board_test.dart`
- Test: `test/modules/community/community_active_asks_section_test.dart`
- Test: `test/modules/community/community_ask_chat_actions_test.dart`

**Interfaces:**
- Consumes: `CommunityAskModel.text`
- Preserves: long-press Chat Ask flow through `createAskFromMessage(...)`.

- [ ] Update focused tests to expect canonical `text` for direct and Chat Asks.
- [ ] Run focused tests and confirm failures on old `sourcePreview` usage/API.
- [ ] Update UI consumers and Chat callback with no origin label.
- [ ] Run focused tests and confirm they pass.

### Task 4: Firestore Rules origin branches

**Files:**
- Modify: `firestore.rules`
- Modify: `tests/firestore-rules/community-asks.test.mjs`

**Interfaces:**
- Preserves: safe `get` of absent deterministic Ask.
- Adds: valid Direct Ask write with generated `askId` and absent `sourceMessageId`.

- [ ] Add focused Rules tests for linked member success and anonymous, outsider, removed member, forged author, invalid type/status, blank text failures.
- [ ] Preserve and update Chat Ask ownership, duplicate, and transaction regression tests for canonical `text`.
- [ ] Run `firebase.cmd emulators:exec --only firestore "npm.cmd run test:rules:community-asks"` and confirm RED before Rules changes.
- [ ] Implement the minimal shared/base plus direct/chat branch Rules.
- [ ] Rerun the focused Rules test and confirm zero failures.

### Task 5: Focused verification

**Files:** all Dart and Rules files changed above.

- [ ] Run `dart format` only on modified Dart files.
- [ ] Run focused Dart analyze on modified Dart files and focused tests.
- [ ] Run all focused Flutter Ask/Home tests.
- [ ] Run the focused Community Asks Rules suite.
- [ ] Confirm `firestore.indexes.json` has no Phase 2B change.
- [ ] Run `git diff --check` and `git status --short`.
