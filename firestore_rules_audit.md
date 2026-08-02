# Firestore Rules audit — Phase 1

Scope: static inspection of all 159 Dart files under `lib/`. No Firebase
network access was used. This document records the client contract that future
Firestore Rules must permit; it is not a declaration of authorization.

## Shared authorization vocabulary

- **authenticated**: `FirebaseAuth.currentUser` is present.
- **Gub owner/member**: root `gubs/{gubId}.ownerId` / real
  `gubs/{gubId}/members/{uid}` document.
- **active Gub**: root exists and `deletionStatus != deleting`.
- **Community owner/member**: `communities/{id}.ownerId` / real member doc.
- **deletion owner**: root owner and `deletionRequestedBy` (or legacy
  `deletionStartedBy` for Community) equals the authenticated user.

## Path matrix

| Path | Operations / actor / relevant fields | Primary call sites |
|---|---|---|
| `users/{uid}` | get by authenticated clients; self creates profile (`displayName`, `createdAt`, `updatedAt`); other members read display names/photos | `user_service.dart`, `user_repository.dart`, `post_service.dart` |
| `users/{uid}/gubs/{gubId}` | owner creates own copy at Gub creation; joining user creates own copy; self removes stale copy; deletion owner removes all member copies | `gub_service.dart`, `gub_repository.dart`, `gub_access_guard.dart`, `gub_deletion_repository.dart` |
| `users/{uid}/communities/{communityId}` | owner/joiner creates own copy; deletion owner removes captured copies | `community_repository.dart` |
| `gubs/{gubId}` | create owner root; member count update on join/removal; owner starts/checkpoints/deletes deletion. Read owner/member only | `gub_service.dart`, `member_repository.dart`, `gub_deletion_repository.dart`, `gub_repository.dart` |
| `gubs/{id}/members/{uid}` | owner creation/join creates member record; self updates anti-spam acceptance only; owner removes member; deletion cleanup deletes all | `gub_service.dart`, `gub_rules_repository.dart`, `member_repository.dart`, `gub_deletion_repository.dart` |
| `gubs/{id}/messages/{messageId}` | member create message with own sender identity; member read; deletion owner delete | `chat_repository.dart`, `gub_deletion_repository.dart` |
| `gubs/{id}/chatReads/{uid}` | self set `lastReadAt`; members read own/unread query; deletion owner delete | `chat_read_repository.dart`, deletion repository |
| `gubs/{id}/boardReads/{uid}` | self set `lastReadAt`; deletion owner delete | `board_read_repository.dart`, deletion repository |
| `gubs/{id}/posts/{postId}` | member creates post with own `authorId`; members read; deletion owner delete | `post_repository.dart`, `post_service.dart` |
| `gubs/{id}/tasks/{taskId}` | authenticated creator creates/updates/completes; creator or owner deletes; members read; deletion owner delete | `task_repository.dart`, `task_service.dart` |
| `gubs/{id}/events/{eventId}` | creator/owner create, update, delete; members read; deletion owner delete | calendar `event_repository.dart`, `event_service.dart` |
| `gubs/{id}/organizedEvents/{eventId}` | member creates; creator/owner delete; assigned member updates own completion; members read | `gub_event_repository.dart`, `gub_event_service.dart` |
| `gubs/{id}/proposals/{proposalId}` | creator creates; creator/owner soft-delete; transaction updates counters/status; members read | `proposal_repository.dart`, `proposal_service.dart` |
| `gubs/{id}/proposals/{proposalId}/votes/{uid}` | member may set own vote only; members read; deletion owner deletes with parent cleanup | proposal repository, deletion repository |
| `gubs/{id}/goals/{goalId}` | authorized creator/owner creates, updates, soft-deletes; members read; transactions update totals/status | `shared_budget_repository.dart`, services |
| `gubs/{id}/goals/{goalId}/members/{uid}` | creation batch sets member assignments; uid updates own contribution; Gub owner confirms; deletion owner deletes | shared budget repositories/services, deletion repository |
| `gubs/{id}/notifications/{notificationId}` | module services create; members read; target user updates `readBy`; deletion owner delete | notification repository/service, `user_header.dart` |
| `gubs/{id}/creationCooldowns/{creator-module}` | transaction writes deletion cooldown; creator reads; deletion owner deletes | `creation_cooldown_repository.dart`, module repositories |
| `communities/{id}` | authenticated creates root; public list/read; owner starts/retries/deletes deletion; public join transaction increments count | `community_repository.dart`, Community UI/service |
| `communities/{id}/members/{uid}` | create owner/member on create/join; community members read; deletion cleanup deletes | `community_repository.dart` |
| `communities/{id}/messages/{messageId}` | community member creates own sender message; members read; deletion cleanup deletes | `community_chat_repository.dart`, community deletion |
| `communities/{id}/deletionMembers/{uid}` | deletion owner writes and deletes checkpoint markers only | `community_repository.dart` |
| `communityOwnership/{ownerId}` | owner creation marker; deletion owner deletes matching marker; used to enforce owner limit | `community_repository.dart` |
| `_/{id}`, `temp/{id}` | only generated document IDs; no persisted application document writes observed | task/proposal/calendar UI/repositories |

## Transactions and batches

- Gub create/join and member removal use batches spanning root, member and user
  copy documents.
- Gub deletion uses transactions for state/checkpoints and batches for child
  cleanup and cross-user copies.
- Community create/join/deletion finalization use transactions; deletion member
  capture and cleanup use batches.
- Task, Organized Event, Proposal, Shared Budget and contribution flows use
  transactions that read the root Gub for active/deletion state.

## Direct UI Firestore access to account for

- `gub_access_guard.dart`: membership stream, root read, own stale-copy delete.
- `members_screen.dart`: member stream.
- `user_header.dart`: Gub notification stream.
- `create_proposal_screen.dart` and calendar event service: `temp` only for ID
  generation, not a persisted feature collection.

## Dynamic / caution points

- Gub deletion enumerates a fixed list of direct collections plus nested
  `proposals/votes` and `goals/members`; future subcollections require both
  cleanup and Rules updates.
- Community public discovery intentionally reads public root documents; private
  Gubs must not be listable by non-members.
- Existing Community documents may use `deletionStartedBy` while new recovery
  uses `deletionRequestedBy`; Rules must accept legacy recovery safely.
