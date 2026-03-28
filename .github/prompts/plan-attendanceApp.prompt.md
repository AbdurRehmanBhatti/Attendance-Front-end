## Plan: JWT Auth + Attendance Guardrails + Home Status

Implement end-to-end authentication and attendance safety by using ASP.NET Core Identity for user management and credential validation, issuing JWT bearer tokens for API access, and enforcing strict server-side attendance rules. Then update Flutter to use token-based sessions and improved Home status metrics. This addresses multi-user scaling, prevents invalid clock actions, and improves operational clarity for users.

**Steps**
1. Phase 1 - Backend auth foundation: adopt ASP.NET Core Identity (UserManager/SignInManager), configure Identity user schema with email + hashed password, seed/migrate Identity tables, and create login endpoint returning JWT. This blocks all downstream authorization work.
2. Phase 2 - Backend authorization pipeline (depends on 1): enable JWT auth middleware and protect attendance endpoints so user identity comes from token claims, not request body trust.
3. Phase 3 - Backend attendance invariants (depends on 2): enforce business rules server-side:
1. Reject clock-in when active session exists.
2. Reject clock-out when no active session exists.
3. Guarantee only one active session per user.
4. Phase 4 - Backend response contract hardening (parallel with 3 after 2): normalize error payloads so Flutter can reliably surface duplicate clock-in and missing-active-session messages.
5. Phase 5 - Flutter API migration (depends on 2 and 4): update login to email + password, store token/session, send Authorization bearer header on attendance calls, handle 401 deterministically.
6. Phase 6 - Flutter session lifecycle (depends on 5): persist auth session on device, restore session at startup, and add logout flow to clear state.
7. Phase 7 - Home UI/UX updates (depends on 5): keep/show clocked-in status with since time, ensure button behavior reflects state, and show total today working hours across all today sessions including active elapsed time.
8. Phase 8 - End-to-end verification (depends on 1-7): validate backend rules and frontend UX with negative scenarios and timeout/offline handling.

**Relevant files**
- [lib/services/api_service.dart](lib/services/api_service.dart) - auth contract migration, bearer header injection, centralized API error handling.
- [lib/screens/login_screen.dart](lib/screens/login_screen.dart) - email-based login input and token-aware login flow.
- [lib/screens/home_screen.dart](lib/screens/home_screen.dart) - status text, button state mapping, total today hours aggregation.
- [lib/models/user.dart](lib/models/user.dart) - align model with authenticated user payload.
- [lib/models/attendance.dart](lib/models/attendance.dart) - confirm active-session duration behavior for totals.
- [lib/main.dart](lib/main.dart) - startup route based on persisted auth state.
- [lib/config/api_config.dart](lib/config/api_config.dart) - auth-related API settings if needed.
- Backend repo (separate from this workspace): ASP.NET Core Identity setup, auth controller/service, Identity migrations, JWT setup, attendance rule enforcement.

**Verification**
1. Backend tests: auth success/failure, unauthorized attendance access, duplicate clock-in rejection, clock-out without active session rejection.
2. Backend manual checks: valid login returns JWT; missing/invalid token returns unauthorized; business-rule violations return clear 400 responses.
3. Flutter checks: login persists across restart, Home status shows clocked-in since time, button behavior follows state, today total hours match summed records plus active elapsed duration.
4. Resilience checks: expired token path, timeout/offline user messaging, and safe recovery flow.

**Decisions**
- Included: backend + frontend scope, email/password login via ASP.NET Core Identity, JWT required, strict attendance invariants.
- Included: total today hours on Home including active session.
- Excluded for now: signup/forgot-password, RBAC, geofencing policy, analytics dashboards.

If you approve this plan, I can hand off for implementation exactly in this sequence.
