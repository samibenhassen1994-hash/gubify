# Membership history boundaries

Step 2 prevents a current membership from exposing data created or resolved
before that membership began. The authoritative boundary is, in order,
`membershipStartedAt`, `joinedAt`, then `createdAt` on the membership record.
Missing timestamps fail closed for chronological history.

Chat, Board and Notifications query `createdAt >= membershipBoundary`.
Current-state modules use an explicit current query (for example active Tasks)
and a separately bounded historical query. Resolved Tasks, Proposals and Shared
Budgets use their completion/resolution timestamp; Calendar uses `eventDate`.
The dynamic-bound query form is covered by Firestore Emulator tests.

No fanout, copied history, member scans, or per-member listeners are used.
Each screen resolves its own current membership boundary once before opening its
bounded stream. Rejoining therefore starts a new history window.

Notifications are private-Gub group notifications today. Optional
`data.recipientIds` is filtered by the client, but is not an enforceable
recipient-level Firestore contract for one combined group-wide query. A
recipient-private notification redesign is deliberately deferred to Step 6.
