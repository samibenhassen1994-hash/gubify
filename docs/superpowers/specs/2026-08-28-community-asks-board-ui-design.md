# Community Asks Board UI Design

## Scope

Add a compact mutually-exclusive Community/Asks header above Community Chat, a one-shot active count summary, an active Asks board, Dart-side type filters, and a presentational Ask details screen. Preserve Phase 1, Community Chat history, profile Asks, Private Gubs, Rules, and indexes.

## Data flow

`CommunityHomeContent` owns `none/community/asks` panel state. Opening Asks calls `CommunityAskService.getActiveAskCount` once; closing it leaves no subscription. `CommunityAsksScreen` creates one `watchActiveAsks(communityId)` subscription, which Firestore cancels when the screen is disposed. The repository query uses only `status == active`; results are sorted and filtered in Dart.

## UI

The permanent header is a small centered row of two circular controls. Community uses `CommunityImageView`; Asks uses `Icons.view_list_rounded`. Community expands the existing info card. Asks first expands a low summary and its second consecutive tap pushes the board. The board uses ChoiceChips and compact cards; tapping a card pushes a read-only details screen.

## Constraints

No Replies, Best Answer, EXP, Level, leaderboard, search, pagination UI, new packages, Rules changes, index changes, commits, or pushes.
