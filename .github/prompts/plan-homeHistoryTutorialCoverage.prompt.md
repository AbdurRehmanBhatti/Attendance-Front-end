Based on the actual app features, the tutorial should focus on Home first, then optionally History.

Recommended tutorial items to show on first login:

1. Primary action: Clock In / Clock Out button  
   Why: this is the core job-to-be-done.  
   Where: [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L1025)

2. Status card (current state + total time)  
   Why: users need to understand whether they are currently clocked in and what Today/Week totals mean.  
   Where: [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L933)

3. History quick access (top history icon or View Full History button)  
   Why: users often want to verify if their punch was recorded.  
   Where: [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L860) and [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L822)

4. More actions menu (My Account, Change Password, Delete Account, Logout)  
   Why: this menu contains critical account/session actions.  
   Where: [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L865)

5. Pull to refresh hint  
   Why: recovery path for stale state/network glitches.  
   Where: [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L795)

Important conditional tutorial hint:

1. Location requirement guidance before first clock attempt  
   Why: clock actions depend on GPS and permission; this is the biggest failure source.  
   Where: [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L435)

Optional second tutorial (shown when user opens History first time):

1. Filter tabs: Today / Last 7 Days / This Month  
   Where: [lib/screens/history_screen.dart](lib/screens/history_screen.dart#L134)

2. Summary row meaning (Monthly/Weekly/Daily)  
   Where: [lib/screens/history_screen.dart](lib/screens/history_screen.dart#L221)

3. Pull to refresh in history  
   Where: [lib/screens/history_screen.dart](lib/screens/history_screen.dart#L122)

Suggested scope so users do not get overwhelmed:

1. First-login Home tutorial: only 3-4 coach marks (Clock button, Status card, History entry, More menu).  
2. Keep Pull-to-refresh and location as short snackbar or one-time inline hint.  
3. History tutorial should be separate and lazy, only when entering History first time.

If you want, I can now draft exact tooltip text and target order for implementation in your current tutorial flow (including key names and when each should be marked seen).

---

## Exact Tooltip Text and Target Order (Implementation Draft)

### Home Tutorial (first login, primary flow)

Show this flow once, on first successful entry to Home after onboarding.

Trigger condition:
1. `onboarding_seen` is `true`
2. `tutorial_home_v1_seen` is `false`
3. Home widget tree is built (post-frame)

Target order and exact text:

1. Target key: `home_clock_action_key`
   Title: `Clock In Here`
   Body: `Tap this button when you arrive at your workplace to record your attendance.`

2. Target key: `home_status_card_key`
   Title: `Your Live Status`
   Body: `This card shows whether you are clocked in and your Today and Week totals.`

3. Target key: `home_history_entry_key`
   Title: `View Attendance History`
   Body: `Open History to check your records, hours, and recent activity.`

4. Target key: `home_more_menu_key`
   Title: `Account and Settings`
   Body: `Manage your account, change password, request deletion, or log out from here.`

Mark seen timing:
1. On tutorial finish: set `tutorial_home_v1_seen = true`
2. On tutorial skip: set `tutorial_home_v1_seen = true`
3. Optional backward compatibility: also set `tutorial_seen = true`

### History Tutorial (lazy, first History visit)

Show this only when user opens History screen and has not seen this flow.

Trigger condition:
1. `tutorial_history_v1_seen` is `false`
2. History widget tree is built (post-frame)

Target order and exact text:

1. Target key: `history_filters_key`
   Title: `Switch Time Range`
   Body: `Use these tabs to view Today, Last 7 Days, or This Month.`

2. Target key: `history_summary_card_key`
   Title: `Hours Summary`
   Body: `This section shows your monthly, weekly, and daily totals.`

3. Target key: `history_list_key`
   Title: `Refresh Anytime`
   Body: `Pull down to refresh if new attendance entries are not visible yet.`

Mark seen timing:
1. On tutorial finish: set `tutorial_history_v1_seen = true`
2. On tutorial skip: set `tutorial_history_v1_seen = true`

### Location Guidance (contextual hint, not full coach-mark flow)

Show only when location fails for the first time.

Trigger condition:
1. `location_failure_hint_v1_seen` is `false`
2. A location failure dialog/snackbar is about to be shown

Text:
1. Title: `Location Needed`
2. Body: `Clock actions require GPS and location permission. Enable location services and retry.`

Mark seen timing:
1. After first display (or after user closes the dialog): set `location_failure_hint_v1_seen = true`

### Recommended SharedPreferences keys

1. `onboarding_seen`
2. `tutorial_seen` (legacy compatibility)
3. `tutorial_home_v1_seen`
4. `tutorial_history_v1_seen`
5. `location_failure_hint_v1_seen`

### GlobalKey names to add

1. `home_clock_action_key`
2. `home_status_card_key`
3. `home_history_entry_key`
4. `home_more_menu_key`
5. `history_filters_key`
6. `history_summary_card_key`
7. `history_list_key`
