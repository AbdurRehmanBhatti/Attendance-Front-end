# Mobile UAT Checklist (Multi-Company + Roles)

## Authentication

1. Employee login with valid credentials succeeds.
2. Employee login with invalid password shows backend error message.
3. Admin login is blocked in mobile app with guidance to use admin web.
4. Session is persisted across app restart for employee users.
5. Corrupted session storage is cleared automatically and user is sent to login.

## Authorization and Session Safety

1. When backend returns `401`, app clears in-memory and persisted session.
2. After `401`, user is redirected to login and cannot navigate back to protected screens.
3. Employee user can access home and history screens after restore.

## Tenant Visibility

1. Home header shows the authenticated employee company ID.
2. Attendance/history responses are only from employee company scope.
3. No API path in mobile app points to `/api/admin/*`.

## Connectivity / Environment

1. App runs correctly with `--dart-define=API_BASE_URL=http://localhost:5054`.
2. App runs correctly with LAN backend URL via `--dart-define`.
3. Login, clock in, clock out, summary, and history all call expected backend base URL.

## Attendance Workflow

1. Clock in starts an active session.
2. Clock out closes active session and updates totals.
3. Open session elapsed time updates in UI.
4. Today and history views display UTC-backed data localized in UI.
