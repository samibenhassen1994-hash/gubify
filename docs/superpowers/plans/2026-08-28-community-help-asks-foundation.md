# Community Help Asks Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add active Community Asks created from an author's own Community Chat message, with profile visibility for all current linked members.

**Architecture:** Store one ask at `communities/{communityId}/asks/{sourceMessageId}` and use dedicated model, repository, and service layers. Active Asks are current collaborative state and deliberately do not use the Chat membership-history boundary; the original Community Chat query and Rules remain unchanged.

**Tech Stack:** Flutter, Dart, Firebase Auth, Cloud Firestore, Firestore Security Rules, Flutter widget/unit tests, Firebase Rules emulator tests.

**Spec:** `C:/Users/samib/.codex/attachments/b5a9ea9d-119f-47a9-86ca-b06684c0d1e8/pasted-text.txt` plus the approved correction in the current task.

## Global Constraints

- Do not modify Private Gub Chat.
- Do not implement EXP, levels, Best Answer, rewards, anti-farming, leaderboard, replies, or message jumping.
- Active Ask cards are not clickable in Phase 1.
- Active Asks are visible to every current linked Community member without a `joinedAt` boundary.
- Anonymous Firebase users cannot read or mutate Asks.
- Use UI → Service → Repository → Firestore and no direct Firestore access from UI.
- Do not add dependencies, commit, push, or merge.

---

### Task 1: Ask domain and atomic creation

**Files:**
- Create: `lib/modules/community/models/community_ask_model.dart`
- Create: `lib/modules/community/repositories/community_ask_repository.dart`
- Create: `lib/modules/community/services/community_ask_service.dart`
- Create: `test/modules/community/community_ask_service_test.dart`

**Interfaces:**
- Produces: `CommunityAskType`, `CommunityAskStatus`, `CommunityAskModel`, `CommunityAskCreateResult`, `CommunityAskRepository.createAsk`, `CommunityAskService.createAsk`, and `CommunityAskService.activeAsksStream`.
- Consumes: Firebase current user, Community membership, source Community message.

- [ ] Write tests for type serialization, input validation, own-message creation results, duplicate results, and active author stream parameters.
- [ ] Run the focused test and confirm it fails because the Ask domain does not exist.
- [ ] Implement the minimum model/repository/service. Use `sourceMessageId` as the Ask document ID and return normal transaction results for expected duplicate/not-owner/missing states.
- [ ] Run the focused test and confirm it passes.

### Task 2: Message actions and Community profile navigation

**Files:**
- Modify: `lib/modules/community/widgets/community_chat_message_bubble.dart`
- Modify: `lib/modules/community/widgets/community_chat_view.dart`
- Modify: `lib/modules/community/widgets/community_home_content.dart`
- Modify: `lib/modules/community/screens/gub_community_home_screen.dart`
- Create: `lib/modules/community/widgets/community_ask_type_sheet.dart`
- Create: `test/modules/community/community_ask_chat_actions_test.dart`

**Interfaces:**
- Consumes: `CommunityAskService.createAsk` and `UserProfileScreen.community`.
- Produces: optional bubble callbacks for profile tap and own-message long press.

- [ ] Write widget tests proving long press on an own message exposes `Create ask`, another user's message does not, each of the three types is passed correctly, and avatar/name opens the existing Community profile.
- [ ] Run the focused test and confirm failures caused by missing callbacks/actions.
- [ ] Implement the bottom-sheet flow, loading protection, controlled duplicate feedback, and existing profile navigation without altering Chat reads or sends.
- [ ] Run the focused test and confirm it passes.

### Task 3: Active Asks section in Community profile

**Files:**
- Create: `lib/modules/community/widgets/community_active_asks_section.dart`
- Modify: `lib/modules/profile/screens/user_profile_screen.dart`
- Create: `test/modules/community/community_active_asks_section_test.dart`

**Interfaces:**
- Consumes: `CommunityAskService.activeAsksStream(communityId, authorId)`.
- Produces: a read-only, non-clickable `Active asks` section scoped to the current Community profile.

- [ ] Write widget tests for active cards, type labels, preview/date/status, author scoping, empty state behavior, and absence of tap behavior.
- [ ] Run the focused test and confirm it fails because the section does not exist.
- [ ] Implement the section and attach it only to `UserProfileScreen.community`.
- [ ] Run the focused test and confirm it passes.

### Task 4: Firestore authorization, indexes, and deletion cleanup

**Files:**
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json`
- Modify: `lib/modules/community/repositories/community_repository.dart`
- Create: `tests/firestore-rules/community-asks.test.mjs`
- Modify: `package.json` only if a focused script is required by the established test convention.

**Interfaces:**
- Consumes: `linkedCommunityAccount`, `isCommunityMember`, `communityActive`, source messages, and existing deletion lifecycle.
- Produces: current-member active Ask reads, own-source atomic creates, and deletion cleanup permission.

- [ ] Write Rules tests for linked current-member active reads, no `joinedAt` boundary, anonymous/outsider/removed denial, own-message creation, other-author denial, deterministic IDs, duplicate denial, malformed fields, no update, and owner deletion cleanup.
- [ ] Run the focused Rules test and confirm it fails because no Ask match exists.
- [ ] Add the narrow Ask Rules and required author/status/createdAt composite index without changing Community Chat or Private Gub Rules.
- [ ] Extend client deletion cleanup to remove Ask documents before final Community deletion.
- [ ] Run focused Rules and deletion tests and confirm they pass.

### Task 5: Focused verification

**Files:** All modified Dart, Rules, index, and focused test files above.

- [ ] Format only modified Dart files.
- [ ] Run focused Community Ask model/service/widget tests.
- [ ] Run the focused Community Asks Rules test.
- [ ] Run focused analyzer on modified Dart files.
- [ ] Run `git diff --check`.
- [ ] Review `git status --short` and confirm no commit, push, or merge occurred.
