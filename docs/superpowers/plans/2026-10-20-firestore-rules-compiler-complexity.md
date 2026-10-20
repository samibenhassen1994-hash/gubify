# Firestore Rules Compiler Complexity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce Firestore Rules compiler scope complexity without changing any permission decision.

**Architecture:** Keep genuinely shared authentication, path, schema, and authorization helpers at database scope. Move helpers with exactly one direct `allow` call into that call's smallest enclosing `match`, and remove only helpers proven unreachable from every `allow` expression by a static call-graph traversal.

**Tech Stack:** Firebase Security Rules v2, Firebase Emulator Suite, Node test runner, Flutter.

**Spec:** User request in the current Codex thread.

## Global Constraints

- No Firebase deploy, Google Play release, destructive reset, or merge.
- Do not change any helper body, `allow` expression, permission outcome, or application behavior.
- Do not replace valid Firebase primitives such as `get`, `getAfter`, or `exists`.
- Use the full 647-test Rules suite as the permission regression gate.

## Review Focus

- A localized helper must remain visible to its original `allow` and nowhere broader.
- Shared dependencies called by localized helpers must remain at database scope.
- Approval-request behavior must remain covered after removing unreachable legacy helpers.
- Modern and legacy Gub deletion paths must retain identical authorization.
- Platform moderation audit-event and authority-referral writes must remain admin-only.

---

### Task 1: Baseline and compiler reproduction

**Files:**
- Inspect: `firestore.rules`
- Test: `tests/firestore-rules/*.test.mjs`

- [x] Count functions and match blocks.
- [x] Run the full Rules suite and record 647/647.
- [x] Reproduce the remote compiler failure with `firebase deploy --dry-run`.
- [x] Build a call graph and identify direct single-match helpers and unreachable helpers.

### Task 2: Localize collection-specific helpers

**Files:**
- Modify: `firestore.rules`

- [ ] Move the 73 helpers with one direct call into the smallest enclosing `match`.
- [ ] Preserve every helper body and every `allow` expression byte-for-byte apart from relocation.
- [ ] Remove only `eventPath`, `validCommunityApprovalMember`, and `validCommunityApprovalMutation`, which are unreachable from all `allow` expressions.
- [ ] Run the focused structural and affected-domain Rules suites.

### Task 3: Equivalence and final verification

**Files:**
- Test: `tests/firestore-rules/*.test.mjs`
- Test: pertinent Flutter moderation/community tests

- [ ] Compare normalized `allow` expressions and all retained helper bodies against the baseline.
- [ ] Run `firebase deploy --dry-run` and require compilation success.
- [ ] Run all 647 Firestore Rules tests.
- [ ] Run pertinent Flutter tests, full `flutter test`, and `flutter analyze`.
- [ ] Run `git diff --check`, inspect the final diff, and prepare the branch for review.
