# Community Asks Board UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the compact Community/Asks header, active Asks board, Dart filters, and details base.

**Architecture:** Extend the existing Ask service/repository with a one-shot aggregate count and one Community-wide active stream. Keep header state local to `CommunityHomeContent`, and keep board/details presentation in dedicated screens/widgets.

**Tech Stack:** Flutter, Dart, Cloud Firestore.

**Spec:** `docs/superpowers/specs/2026-08-28-community-asks-board-ui-design.md`

## Global Constraints

- Do not modify `firestore.rules` or `firestore.indexes.json`.
- Do not alter Community Chat history or Private Gubs.
- Do not implement Replies, Best Answer, EXP, Level, or leaderboard.
- Do not commit or push.

---

### Task 1: Read APIs

**Files:**
- Modify: `lib/modules/community/repositories/community_ask_repository.dart`
- Modify: `lib/modules/community/services/community_ask_service.dart`
- Test: `test/modules/community/community_ask_service_test.dart`

**Interfaces:**
- Produces: `getActiveAskCount(communityId)` and `watchActiveAsks(communityId)`.
- Consumes: existing linked-account guard and Ask model.

- [ ] Add failing tests proving count/stream delegation and normalization.
- [ ] Run the focused test and observe missing APIs.
- [ ] Implement aggregate count plus one `status == active` stream sorted in Dart.
- [ ] Run the focused test and confirm green.

### Task 2: Compact header state machine

**Files:**
- Modify: `lib/modules/community/widgets/community_home_content.dart`
- Test: `test/modules/community/community_asks_header_test.dart`

**Interfaces:**
- Consumes: one-shot count API and board navigation.
- Produces: mutually exclusive Community and Asks panels.

- [ ] Add failing widget tests for both circles, toggle behavior, exclusivity, second Asks tap, count, and phone layout.
- [ ] Run the focused test and observe missing controls.
- [ ] Implement the local enum state, compact controls, info card, and summary card.
- [ ] Run the focused test and confirm green.

### Task 3: Board and details

**Files:**
- Create: `lib/modules/community/widgets/community_ask_card.dart`
- Create: `lib/modules/community/screens/community_asks_screen.dart`
- Create: `lib/modules/community/screens/community_ask_details_screen.dart`
- Test: `test/modules/community/community_asks_board_test.dart`

**Interfaces:**
- Consumes: one Community-wide active Ask stream.
- Produces: All/Help/Information/Advice filters, cards, empty states, and details navigation.

- [ ] Add failing widget tests for active data, all filters, empty states, card navigation, and details content.
- [ ] Run the focused test and observe missing screens.
- [ ] Implement one StreamBuilder, Dart sorting/filtering, compact cards, and read-only details.
- [ ] Run the focused test and confirm green.

### Task 4: Focused verification

**Files:** All Dart and tests above.

- [ ] Format only modified Dart files.
- [ ] Run Phase 2A focused tests.
- [ ] Run focused analyze.
- [ ] Run `git diff --check` and `git status --short`.
