# Global Navigation Swipe Back Implementation Plan

**Goal:** Keep My Gubs and Join a Gub inside the global shell and add reliable left-edge progressive back behavior to secondary Community navigation.

**Architecture:** `MainNavigationShell` owns a small Home subsection state while the existing root `IndexedStack` remains unchanged. A reusable `GubifySwipeBack` tracks pointer movement only inside a 24px left-edge strip and delegates either to `Navigator.maybePop` or a supplied progressive/internal callback.

**Tech Stack:** Flutter widgets, Navigator 1.0, widget tests.

**Spec:** Approved design in the current task conversation, including progressive Community Guidelines behavior.

## Global Constraints

- Preserve all existing uncommitted global-navigation work.
- No nested Navigator, routing package, backend, version, merge, push, commit, or deploy changes.
- Root Home, Explore, Notifications, and Profile never expose swipe-back.
- Specific Gub and Community destinations remain pushed full-screen above the shell.
- Existing `PopScope` decisions must remain authoritative.

### Task 1: Reusable edge swipe

**Files:**
- Create: `lib/widgets/gubify_swipe_back.dart`
- Create: `test/widgets/gubify_swipe_back_test.dart`

**Interface:** `GubifySwipeBack({required Widget child, VoidCallback? onBack})`; default action calls `Navigator.maybePop(context)`.

- [ ] Write tests for edge success, off-edge rejection, insufficient distance, vertical rejection, and one callback per gesture.
- [ ] Run focused tests and confirm RED because the widget does not exist.
- [ ] Implement a 24px edge listener, 72px threshold, horizontal dominance, vertical tolerance, and one-shot release action.
- [ ] Run focused tests to GREEN.

### Task 2: Home subsections inside MainNavigationShell

**Files:**
- Modify: `lib/screens/main_navigation_shell.dart`
- Modify: `lib/screens/welcome_screen.dart`
- Modify: `lib/screens/gub/my_gubs_screen.dart`
- Modify: `lib/screens/gub/join_gub_screen.dart`
- Modify: `lib/widgets/gub_page_header.dart`
- Modify: `test/screens/main_navigation_shell_test.dart`
- Add/update focused My Gubs and Join tests as required.

**Interfaces:** optional Welcome callbacks `onOpenMyGubs`/`onOpenJoinGub`; optional screen callbacks `onBack`; Join callback `onJoined(String gubId)`; optional bottom overlay clearance.

- [ ] Write RED tests for navbar retention, internal Back/swipe, post-join state switch, pushed Gub navbar hiding/restoration, and root swipe exclusion.
- [ ] Add shell Home subsection state without changing the four-tab architecture.
- [ ] Keep standalone Navigator fallbacks unchanged.
- [ ] Switch Join to My Gubs before pushing the joined Gub above the existing shell.
- [ ] Run focused tests to GREEN.

### Task 3: Community secondary screens

**Files:**
- Modify actual navigable Community screens under `lib/modules/community/screens/` and `lib/modules/community/admin/`.
- Modify: `lib/modules/profile/screens/user_profile_screen.dart` only for Community profile mode.
- Add: focused Community navigation regression tests.

- [ ] Write RED representative tests for Explore→Community, nested Community routes, and root Explorer exclusion.
- [ ] Wrap Community secondary screens with `GubifySwipeBack` while leaving embedded widgets/dialogs untouched.
- [ ] Enable Explorer swipe only when its existing Back UI is enabled.
- [ ] Run focused Community tests to GREEN.

### Task 4: Progressive Community Guidelines

**Files:**
- Modify: `lib/modules/community/guidelines/community_guidelines_screen.dart`
- Modify: `test/modules/community/community_guidelines_screen_test.dart`

- [ ] Write RED tests proving edge swipe page 3→2 and first page→route pop, while non-edge PageView swipe remains unchanged.
- [ ] Wrap Guidelines with `GubifySwipeBack(onBack: _goBack)` so existing saving and progressive Back rules remain authoritative.
- [ ] Run focused tests to GREEN.

### Task 5: Focused verification checkpoint

- [ ] Run swipe, shell, Welcome/My Gubs/Join, Guidelines, and representative Community navigation tests.
- [ ] Run `flutter analyze`.
- [ ] Run `git diff --check`.
- [ ] Report sensitivity constants, Community inclusion/exclusion audit, exact results, and stop before the full suite.
