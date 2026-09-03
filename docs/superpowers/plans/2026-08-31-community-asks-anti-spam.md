# Community Asks Anti-Spam Implementation Plan

> **For agentic workers:** Execute this plan inline, task-by-task, following test-driven development. Do not commit, push, merge, or deploy.

**Goal:** Enforce one active Ask per member per Community and one Answer per member per Ask, then add safe edit/delete controls and reusable profile navigation.

**Architecture:** A deterministic document at `communities/{communityId}/activeAskSlots/{uid}` represents the sole active Ask for that member in that Community. Ask creation claims the slot atomically; resolution and active-Ask deletion release it atomically. Answers use the deterministic document ID `{authorId}`, which makes duplicate Answer creation structurally impossible. Firestore Rules validate all coupled writes with `getAfter()` and preserve the existing reward transaction.

**Tech Stack:** Flutter, Firebase Auth, Cloud Firestore client transactions/batches, Firestore Security Rules, Flutter widget tests, Firestore Emulator Rules tests.

**Spec:** `C:\Users\samib\.codex\attachments\19f2acff-f6fe-4434-8f4c-18f8cc8f578a\pasted-text.txt`

## Global Constraints

- Do not modify Private Gub behavior, reward amounts, account deletion, Rules unrelated to Community Asks, indexes, backend, or deployment.
- Preserve existing Community deletion/resume and Startup recovery; add only cleanup for `activeAskSlots`.
- The canonical Answer path is `answers/{authorId}`. No permanent fallback or dual write for old random development IDs.
- A selected Best Answer in a resolved Ask cannot be deleted individually; deleting the resolved Ask does not reverse rewards.
- Use focused tests first and no commit/push/deploy.

---

### Task 1: Active Ask Slot Contract

**Files:**
- Create: `lib/modules/community/models/community_active_ask_slot.dart`
- Modify: `lib/modules/community/repositories/community_ask_repository.dart`
- Modify: `lib/modules/community/services/community_ask_service.dart`
- Test: `test/modules/community/community_ask_service_test.dart`
- Test: `tests/firestore-rules/community-asks.test.mjs`

**Interfaces:**
- Produces a slot with `askId`, `authorId`, and `createdAt` at `activeAskSlots/{uid}`.
- `createDirectAsk` and `createAskFromMessage` return a controlled `activeAskExists` result when the slot already exists.

- [ ] Write focused failing service/Rules tests: a first active Ask succeeds, a second direct or chat Ask for the same member/Community is rejected, other members/Communities are independent, and concurrent creation cannot yield two Ask documents.
- [ ] Run each new focused test and confirm RED because the repository currently creates the Ask without a slot.
- [ ] Implement the minimal transaction/batch contract: create Ask plus matching slot atomically; preserve deterministic message Ask idempotence.
- [ ] Add Rules for Ask creation and slot writes requiring the matching post-commit Ask/slot state.
- [ ] Rerun focused tests to GREEN.

### Task 2: Deterministic Answer, Edit, and Delete Contract

**Files:**
- Modify: `lib/modules/community/models/community_ask_answer_model.dart`
- Modify: `lib/modules/community/repositories/community_ask_answer_repository.dart`
- Modify: `lib/modules/community/services/community_ask_answer_service.dart`
- Test: `test/modules/community/community_ask_answer_service_test.dart`
- Test: `tests/firestore-rules/community-asks.test.mjs`

**Interfaces:**
- `createAnswer` writes only `answers/{authorId}`.
- `editAnswer` changes only `text` and `updatedAt`.
- `deleteAnswer` returns a controlled result for absent or protected selected Best Answer.

- [ ] Write failing tests for duplicate Answer rejection, own edit, denied foreign edit, self/Ask-author delete, denied normal-member delete, and repost after own delete.
- [ ] Verify RED against the generated Answer ID/no-update/no-self-delete implementation.
- [ ] Implement deterministic document writes and minimal service validation/results.
- [ ] Restrict Rules to the canonical ID, immutable identity/creation fields, `text`/`updatedAt` updates, and permitted deletes while protecting a selected Best Answer.
- [ ] Rerun these focused tests to GREEN.

### Task 3: Resolve and Ask Deletion Integrity

**Files:**
- Modify: `lib/modules/community/repositories/community_ask_answer_repository.dart`
- Modify: `lib/modules/community/repositories/community_ask_repository.dart`
- Modify: `lib/modules/community/services/community_ask_answer_service.dart`
- Modify: `lib/modules/community/services/community_ask_service.dart`
- Modify: `lib/modules/community/repositories/community_repository.dart`
- Test: `test/modules/community/community_ask_answer_service_test.dart`
- Test: `tests/firestore-rules/community-asks.test.mjs`
- Test: `tests/firestore-rules/phase3c.test.mjs`

**Interfaces:**
- Resolving an Ask updates existing reward fields and deletes the matching active slot in one transaction.
- Ask author deletion cleans Answers before Ask; active Ask deletion atomically removes its slot in the final batch.

- [ ] Write failing tests for resolved slot release, deletion of active/resolved Ask, Answer cleanup, no reward rollback, and deletion/recovery cleanup of active slots.
- [ ] Verify RED because resolve currently does not touch a slot and Ask delete is deletion-owner-only.
- [ ] Implement the smallest transaction/batch changes and include `activeAskSlots` in the known Community cleanup subcollections.
- [ ] Add Rules coupling active Ask resolve/delete to matching slot deletion and allowing Ask author delete after Answer cleanup.
- [ ] Rerun focused service and Rules tests to GREEN.

### Task 4: Ask/Answer Actions and Profile Navigation

**Files:**
- Modify: `lib/modules/community/screens/community_ask_details_screen.dart`
- Modify: `lib/modules/community/widgets/community_ask_card.dart`
- Modify: `lib/modules/community/widgets/community_active_asks_section.dart`
- Modify only other Ask author surfaces discovered by audit
- Test: `test/modules/community/community_ask_details_answers_test.dart`
- Test: `test/modules/community/community_asks_board_test.dart`
- Test: `test/modules/community/community_active_asks_section_test.dart`

**Interfaces:**
- Author avatar/name uses the existing `UserProfileScreen.community` navigation pattern.
- Details screen exposes Edit/Delete only to authorized users and shows no second Answer composer once the current user has an Answer.

- [ ] Write failing widget tests for clickable Ask/Answer author identity, edit/delete visibility, Ask-author deletion of another Answer, and composer replacement after the current user answers.
- [ ] Verify RED with the existing static names and always-visible composer.
- [ ] Add minimal callbacks/dependency seams for testability, reuse `ChatUserAvatar` and existing Community profile navigation, and implement dialogs/loading/error feedback.
- [ ] Rerun focused widget tests to GREEN.

### Task 5: Focused Verification

**Files:** all modified files above.

- [ ] Format only modified Dart files.
- [ ] Run focused Community Ask service/widget tests and the focused Emulator Rules script(s).
- [ ] Run `flutter analyze` and `git diff --check`.
- [ ] Do not commit, push, merge, or deploy. If Rules changed, report the required manual deploy command.
