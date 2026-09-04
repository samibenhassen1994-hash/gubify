# Community Ask Answers and EXP Foundation Design

## Scope

Add flat Answers to Community Asks, one immutable Best Answer, and per-Community XP foundations. No levels, leaderboard, notifications, nested replies, reactions, editing, or manual deletion.

## Data model

Answers live at `communities/{communityId}/asks/{askId}/answers/{answerId}` with `answerId`, `authorId`, `authorDisplayName`, `text`, and `createdAt`.

An Ask is either `active` or `resolved`. Resolution adds `bestAnswerId`, `bestAnswerAuthorId`, `resolvedAt`, and `xpAwarded: true`. The Ask itself is the single-award event.

Community membership fields remain optional and default to zero. A reward writes `xp`, `bestAnswerCount`, `lastRewardAskId`, and `lastRewardRole`. Roles are `bestAnswer` and `askAuthor`.

## Atomic resolution

The Ask author runs one Firestore transaction that reads the active Ask, selected Answer, winner membership, and asker membership. It rejects self-selection and removed winners. It atomically resolves the Ask, awards the winner 20 XP plus one Best Answer, and awards the asker 2 XP.

Rules validate the same transition with `get()` and `getAfter()`, exact numeric deltas, immutable Best Answer, and the technical membership reward reference. Resolution without both membership writes, arbitrary XP, duplicate rewards, or later Best Answer changes is denied.

## UI

Ask Details becomes a flat forum thread: Ask card, answer count, pinned Best Answer when resolved, chronological remaining answers, and a compact composer only while active. Only the Ask author sees `Select best`, only on another user's Answer.

## Removed-member behavior

An Answer remains visible as a historical snapshot. If its author is no longer a current member, it cannot be selected as Best Answer because the transaction cannot securely award a missing membership. No membership is recreated.

## Cleanup and cost

The existing Community deletion flow deletes every Answer subcollection before deleting Ask documents. The Answers stream exists only while Ask Details is mounted. No fanout, global collection, or composite index is introduced.
