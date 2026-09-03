# Community Levels 1–20 and Ask Cooldown Design

## Goal

Derive Community Levels 1–20 from existing membership XP, display the level
without cosmetic Firestore reads, and enforce one new Community Ask creation
per user per Community every eight hours.

## Scope

Included:

- Pure Dart Community level, progress, and recognition calculation.
- A reusable Community avatar level badge.
- Level/progress/recognition in the existing Community user profile.
- Level badge in the existing Community members list, which already receives
  membership documents.
- A transactional, server-time Ask creation cooldown using the existing
  Community membership document.
- Focused Flutter and Firestore Rules coverage.

Excluded:

- Leaderboards, levels above 20, backend jobs, Cloud Functions, Private Gubs,
  Chat/Ask/Answer/card badge reads, new badge collections, milestone rewards,
  and data migration.

## Level Value Object

Create a dependency-free Community leveling value object. It accepts an XP
value, treating missing or negative values as zero, and derives:

- level (1 through 20), capped at 20;
- current and next threshold for levels 1–19;
- XP within the current level;
- XP required for the next level;
- progress in the range 0.0–1.0 and integer percentage 0–100;
- highest recognition title, if unlocked.

Thresholds use `10 * (level - 1) * level`:

| Level | Total XP |
| --- | ---: |
| 1 | 0 |
| 2 | 20 |
| 3 | 60 |
| 4 | 120 |
| 5 | 200 |
| 6 | 300 |
| 7 | 420 |
| 8 | 560 |
| 9 | 720 |
| 10 | 900 |
| 11 | 1100 |
| 12 | 1320 |
| 13 | 1560 |
| 14 | 1820 |
| 15 | 2100 |
| 16 | 2400 |
| 17 | 2720 |
| 18 | 3060 |
| 19 | 3420 |
| 20 | 3800 |

At Level 20, progress is 100%, the next level is absent, and UI uses `Max
level`. Recognitions are local-only: Level 5 `Contributor`, Level 10 `Trusted
Member`, Level 15 `Community Expert`, and Level 20 `Community Legend`.

## Existing Data Flow and UI

`CommunityMemberModel` will expose `xp`, defaulting to zero when absent.
Existing Community member streams already yield the underlying membership
documents, so adding the field does not add a stream, listener, or document
read.

`UserProfileService.loadCommunityProfile` already reads the current member and
target member documents to establish Community access. It will map the target
membership XP into `UserProfileModel`; it will not start another query. The
Community profile header will show a compact level badge and a level card with
the progress bar, percentage, next-level text, and only the highest unlocked
recognition.

The Community members list will wrap its existing avatar in the reusable
badge. The badge receives XP or a derived level; it never accesses Firestore.

The following surfaces intentionally remain unbadged in this phase because
their existing state does not contain membership XP and a read would be purely
cosmetic: Community Chat, Ask cards, Answer cards, Active Ask cards, and
Resolved Ask cards.

## Ask Cooldown Transaction

The authoritative cooldown field is
`communities/{communityId}/members/{uid}.lastAskCreatedAt`.

For both direct Ask creation and conversion from a Chat message, the existing
transaction will:

1. Read the caller's member document and active Ask slot.
2. Treat a missing `lastAskCreatedAt` as no previous cooldown.
3. Return a normal cooldown result if the stored timestamp is less than eight
   hours before the server-authoritative creation time.
4. Otherwise create the Ask, create `activeAskSlots/{uid}`, and update
   `lastAskCreatedAt` with `FieldValue.serverTimestamp()` in the same
   transaction.

The repository result carries the membership timestamp needed for a controlled
service exception. The UI formats its remaining duration as `Xh Ym` or `Xm`.
The client clock is presentation-only and is never used to decide permission;
Firestore Rules compare the stored timestamp to `request.time`.

Resolving or deleting an Ask continues to release an active slot where already
defined, but never clears or changes `lastAskCreatedAt`. Existing Best Answer
rewards (+20 XP / +1 bestAnswerCount) and Ask author reward (+2 XP) remain
unchanged.

## Rules Contract

Ask creation is allowed only when one atomic request creates the Ask and slot
and updates the caller's existing member document with
`lastAskCreatedAt == request.time`.

Rules will require:

- no active Ask slot before the transaction;
- the new slot to refer to the new active Ask and caller;
- `lastAskCreatedAt` to be the only membership field changed by the cooldown
  transaction;
- no prior cooldown timestamp, or `request.time >= priorTimestamp + 8h`;
- the member timestamp to equal `request.time`;
- no standalone, arbitrary, past, deleted, or otherwise manipulated member
  timestamp update.

The existing reward member update remains separately constrained to its XP and
reward-tracking fields. It will not receive general permission to modify the
cooldown field.

## Cost and Compatibility

Levels, progress, recognition, and badges add zero Firestore reads/listeners.
Ask creation adds one explicit member-document transaction read and one member
document update; it does not add a query for prior Asks. No new collection or
index is required. `lastAskCreatedAt` lives in the membership document, so
Community deletion/recovery requires no new cleanup path.

## Verification

Focused tests cover pure thresholds/progress/recognitions, badge/profile UI,
cooldown service outcomes, and Community Ask Rules including reward regression.
Run focused Flutter tests, focused Community Ask Rules tests, targeted analyze,
and `git diff --check`. If Rules change, deployment remains manual:

```powershell
firebase.cmd deploy --only firestore:rules
```

No commit, push, or deploy is part of this work.
