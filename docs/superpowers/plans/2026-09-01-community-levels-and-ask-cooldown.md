# Community Levels and Ask Cooldown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Derive Community levels from membership XP and enforce an eight-hour, server-time Ask creation cooldown.

**Architecture:** A pure Dart level value object maps XP to level/progress/recognition. Existing member data flows carry XP to the Community profile and member-list badge without new reads. Ask creation transactions atomically update an existing member’s `lastAskCreatedAt`; Firestore Rules verify the same atomic shape with `request.time`.

**Tech Stack:** Flutter/Dart, Cloud Firestore transactions and Security Rules, flutter_test, Firebase Rules emulator tests.

**Spec:** `docs/superpowers/specs/2026-09-01-community-levels-and-ask-cooldown-design.md`

## Global Constraints

- Keep levels local-only; never persist a `level` field.
- Cap at Level 20 and use `Max level` with 100% progress.
- Add no cosmetic Firestore reads/listeners for badges or levels.
- Keep Chat, Ask, Answer, Active Ask, and Resolved Ask cards unbadged.
- Cooldown is per user/per Community and expires exactly at `lastAskCreatedAt + 8h`.
- Rules use `request.time`; client time may format a returned remaining duration only.
- Preserve rewards, activeAskSlots, deletion/recovery, and Private Gubs.
- Do not add an index, commit, push, or deploy.

---

### Task 1: Pure Community Level Value Object

**Files:**
- Create: `lib/modules/community/leveling/community_level.dart`
- Create: `test/modules/community/community_level_test.dart`

**Consumes:** integer membership XP.

**Produces:** `CommunityLevel.fromXp(int?)` with `level`, `progress`, `percentage`, `xpWithinCurrentLevel`, `xpNeededForNextLevel`, `nextLevel`, and `recognition`.

- [ ] **Step 1: Write failing pure tests**

```dart
expect(CommunityLevel.fromXp(0).level, 1);
expect(CommunityLevel.fromXp(20).level, 2);
expect(CommunityLevel.fromXp(640).percentage, 50);
expect(CommunityLevel.fromXp(3800).isMaxLevel, isTrue);
expect(CommunityLevel.fromXp(2100).recognition, 'Community Expert');
```

- [ ] **Step 2: Run the focused test**

Run: `flutter test --no-pub test/modules/community/community_level_test.dart`

Expected: compilation failure because `CommunityLevel` does not exist.

- [ ] **Step 3: Implement the value object**

```dart
static int thresholdForLevel(int level) => 10 * (level - 1) * level;

factory CommunityLevel.fromXp(int? value) {
  final xp = (value ?? 0).clamp(0, maxXp);
  // Walk the fixed 1–20 range, then derive progress from adjacent thresholds.
}
```

- [ ] **Step 4: Re-run the pure test**

Run: `flutter test --no-pub test/modules/community/community_level_test.dart`

Expected: PASS.

### Task 2: Membership XP Mapping and Read-Free Badge/Profile UI

**Files:**
- Modify: `lib/modules/community/models/community_model.dart`
- Modify: `lib/modules/community/repositories/community_repository.dart`
- Create: `lib/modules/community/widgets/community_level_avatar.dart`
- Modify: `lib/modules/community/screens/community_members_screen.dart`
- Modify: `lib/modules/profile/models/user_profile_model.dart`
- Modify: `lib/modules/profile/services/user_profile_service.dart`
- Modify: `lib/modules/profile/screens/user_profile_screen.dart`
- Create/modify: focused Community member/profile widget tests.

**Consumes:** `CommunityMemberModel.xp` parsed from existing member documents and `CommunityLevel` from Task 1.

**Produces:** level badge over existing Community profile/member-list avatars, and a Community profile level card.

- [ ] **Step 1: Write failing UI/model tests**

```dart
expect(CommunityMemberModel(..., xp: 900).xp, 900);
expect(find.text('Lv 10'), findsOneWidget);
expect(find.text('Level 20'), findsOneWidget);
expect(find.text('Max level'), findsOneWidget);
expect(find.text('Community Legend'), findsOneWidget);
```

The Community profile test injects the existing `profileFuture`; it does not initialize Firebase or add a stream.

- [ ] **Step 2: Run focused tests**

Run: `flutter test --no-pub test/modules/community/community_level_test.dart test/modules/community/community_members_screen_test.dart test/modules/profile/user_profile_organized_events_test.dart`

Expected: badge/level-card assertions fail before production implementation.

- [ ] **Step 3: Implement only existing-flow mappings and UI**

```dart
final int xp;
// Repository parsing: (data['xp'] as num?)?.toInt() ?? 0
// Profile service: communityXp: target.xp
// Badge: Stack(existingAvatar, Positioned(... Text('Lv ${level.level}')))
```

Keep the profile’s two existing membership reads; use the target member’s XP. Do not add badge code to state that lacks XP.

- [ ] **Step 4: Re-run focused UI tests**

Run: `flutter test --no-pub test/modules/community/community_level_test.dart test/modules/community/community_members_screen_test.dart test/modules/profile/user_profile_organized_events_test.dart`

Expected: PASS, including no recognition below Level 5 and only the highest recognition.

### Task 3: Transactional Eight-Hour Ask Cooldown

**Files:**
- Modify: `lib/modules/community/repositories/community_ask_repository.dart`
- Modify: `lib/modules/community/services/community_ask_service.dart`
- Modify: `lib/modules/community/widgets/community_create_ask_card.dart`
- Modify: `lib/modules/community/widgets/community_chat_view.dart` only if it maps the existing service exception to feedback.
- Modify: focused Ask service/repository/widget tests.

**Consumes:** existing Ask creation transaction, active slot document, and caller member document.

**Produces:** atomic Ask + active slot + targeted member timestamp update, and `CommunityAskCooldownException` with a safely ceiling-rounded message.

- [ ] **Step 1: Write failing service tests**

```dart
await service.createDirectAsk(...); // first result: created
await expectLater(service.createDirectAsk(...), throwsA(isA<CommunityAskCooldownException>()));
expect(exception.message, 'You can create another Ask in 42m.');
```

Include first Ask/missing timestamp, just-before eight hours denied, exactly eight hours allowed, per-Community/per-user isolation, active-slot precedence, and preserved cooldown after resolve/delete.

- [ ] **Step 2: Run focused service test**

Run: `flutter test --no-pub test/modules/community/community_ask_service_test.dart`

Expected: cooldown tests fail because no cooldown result exists.

- [ ] **Step 3: Implement normal transaction results and targeted update**

```dart
final memberSnapshot = await transaction.get(memberReference);
if (lastAskCreatedAt != null && nowBeforeServerTimestamp... ) {
  return CommunityAskCreateAttempt.cooldown(lastAskCreatedAt);
}
transaction.update(memberReference, {
  'lastAskCreatedAt': FieldValue.serverTimestamp(),
});
```

The transaction returns a normal attempt/result; it never throws an expected cooldown exception from the callback. The service converts the result afterward and rounds displayed remaining minutes upward, never emitting `0m` while positive time remains.

- [ ] **Step 4: Map the controlled exception in both existing Ask entry points**

```dart
if (error is CommunityAskCooldownException) {
  message = error.userMessage;
}
```

No timer, listener, query, or client-side permission decision is added.

- [ ] **Step 5: Re-run focused Ask tests**

Run: `flutter test --no-pub test/modules/community/community_ask_service_test.dart test/modules/community/community_create_ask_card_test.dart`

Expected: PASS.

### Task 4: Firestore Rules Cooldown Invariant

**Files:**
- Modify: `firestore.rules`
- Modify: `tests/firestore-rules/community-asks.test.mjs`

**Consumes:** existing Ask/active slot Rules and member reward Rules.

**Produces:** Rules allowing only an atomic cooldown timestamp update and preserving reward updates.

- [ ] **Step 1: Add focused failing Rules tests**

```js
await assertSucceeds(validAskSlotAndMemberTimestampBatch());
await assertFails(askAndSlotWithoutMemberTimestampBatch());
await assertFails(pastTimestampOrUnderEightHoursBatch());
await assertSucceeds(exactlyEightHoursLaterBatch());
await assertSucceeds(existingBestAnswerRewardBatch());
```

- [ ] **Step 2: Run the focused Rules file**

Run: `node_modules\\.bin\\firebase.cmd emulators:exec --only firestore "npm.cmd run test:rules:community-asks"`

Expected: new cooldown expectations fail before Rule implementation.

- [ ] **Step 3: Implement correlated Ask/slot/member Rule helpers**

```rules
request.time >= memberBefore.lastAskCreatedAt + duration.value(8, 'h')
&& memberAfter.lastAskCreatedAt == request.time
&& memberAfter.diff(memberBefore).affectedKeys().hasOnly(['lastAskCreatedAt'])
```

Use `getAfter` to correlate the member update with the caller’s newly created active slot and Ask. Keep the existing reward update helper separate and restricted to XP/reward fields.

- [ ] **Step 4: Re-run focused Rules test**

Run: `node_modules\\.bin\\firebase.cmd emulators:exec --only firestore "npm.cmd run test:rules:community-asks"`

Expected: PASS, including reward regression.

### Task 5: Focused Verification and Scope Review

**Files:** only modified files from Tasks 1–4.

- [ ] **Step 1: Format modified Dart files only**

Run: `dart format <modified Dart files>`

- [ ] **Step 2: Run focused Flutter tests**

Run: `flutter test --no-pub <level, profile, member-list, Ask service and entry-point test files>`

- [ ] **Step 3: Analyze modified Dart files**

Run: `flutter analyze <modified Dart files>`

- [ ] **Step 4: Verify patch whitespace**

Run: `git diff --check`

- [ ] **Step 5: Do not commit**

No git add, commit, push, or deploy. If Rules changed, report only the manual command `firebase.cmd deploy --only firestore:rules`.
