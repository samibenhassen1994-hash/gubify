# Community Ask Answers and EXP Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add immutable Answers, atomic Best Answer selection, and secure per-Community XP rewards.

**Architecture:** UI calls dedicated Answer/Ask services, which call repositories. Firestore transactions and Rules enforce one-time resolution and exact reward deltas using the Ask as the event plus membership reward-reference fields.

**Tech Stack:** Flutter, Dart, Firebase Auth, Cloud Firestore, Firestore Rules emulator, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-30-community-ask-answers-design.md`

## Global Constraints

- Preserve all existing local changes; no commit, push, or deploy.
- Use `active` and `resolved`; no legacy migration.
- XP is per-Community membership: Best Answer +20 XP/+1 count, Ask author +2 XP.
- No levels, leaderboard UI, notifications, replies, reactions, editing, or manual Answer deletion.
- No composite index unless the focused emulator proves it necessary.

### Task 1: Models and service contracts

**Files:** create Answer model/service/repository tests and production files; modify Ask model.

- [ ] Write failing model/service tests for parsing, validation, identity reuse, active-only creation, exact resolution outcomes, and no duplicate reward.
- [ ] Run focused tests and confirm RED.
- [ ] Implement models and service/repository contracts.
- [ ] Run focused tests and confirm GREEN.

### Task 2: Ask Details forum UI

**Files:** modify Ask Details; create Answer card/composer; add focused widget tests.

- [ ] Write failing tests for Ask, composer, count, Select Best visibility, confirmation, pinned Best Answer, resolved state, and retained composer text on error.
- [ ] Run focused tests and confirm RED.
- [ ] Implement minimal responsive forum UI with injected test seams.
- [ ] Run focused tests and confirm GREEN.

### Task 3: Atomic rewards and Rules

**Files:** modify Ask repository/service, `firestore.rules`, and focused Rules tests.

- [ ] Add failing emulator tests for Answer access and exact atomic reward policy.
- [ ] Run focused Rules tests and confirm RED.
- [ ] Implement the transaction and Rules using Ask event plus membership reward references.
- [ ] Run focused Rules tests and confirm GREEN.

### Task 4: Deletion cleanup and regressions

**Files:** modify Community repository and focused cleanup tests.

- [ ] Add failing cleanup test proving Answers are deleted before Asks.
- [ ] Implement nested Answer cleanup in the existing deletion system.
- [ ] Verify active board/profile queries continue to exclude resolved Asks.

### Task 5: Final focused verification

- [ ] Format only touched Dart files.
- [ ] Run focused Flutter tests.
- [ ] Run focused Community Ask Rules tests.
- [ ] Run targeted analyze.
- [ ] Run `git diff --check` and `git status --short`.
