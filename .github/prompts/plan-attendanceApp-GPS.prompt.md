## Plan: GPS + Expanded History + Working Hours

Implement GPS capture during clock actions, expand attendance history to Today / Last 7 Days / This Month, and add daily/weekly/monthly total-hours summaries. Recommended approach is backend-first contract updates, then frontend integration, so totals and ranges are consistent and reliable.

**Steps**
1. Phase 1: Backend contract expansion (blocks frontend integration).
2. Add/confirm clock-in and clock-out request models that accept optional latitude/longitude.
3. Add a date-range attendance endpoint for authenticated user data (supports today/week/month windows).
4. Add summary totals in backend response (daily, weekly with Monday start, monthly), or a dedicated summary endpoint.
5. Keep all API timestamps UTC with timezone info in serialization to avoid ambiguity.
6. Standardize validation/error responses for GPS payload and business-rule failures.

7. Phase 2: Frontend data-layer updates (depends on 1).
8. Update API methods for clock-in/out to send GPS when available.
9. Add range-based fetch methods for history tabs.
10. Add summary fetch method (or consume summary embedded in range response).
11. Keep robust parsing of backend validation errors for user-friendly messages.

12. Phase 3: GPS capture flow (depends on 2; permission wiring can start in parallel).
13. Add geolocation dependency and platform permissions.
14. Implement a location service with permission check + one-shot fetch + timeout.
15. Integrate into clock-in/out flow: attempt GPS first, proceed with warning fallback if unavailable/denied.
16. Add UX states: acquiring location, fallback warning, submission success/failure.

17. Phase 4: History UX expansion (depends on 2).
18. Add tabbed history filters: Today, Last 7 Days, This Month.
19. Load data per selected tab with proper loading/error/empty states.
20. Ensure pull-to-refresh reloads the currently selected tab range.

21. Phase 5: Total-hours UX (depends on 2 and 4).
22. Show Daily total and Weekly total on Home.
23. Show Monthly summary in History (or summary card used by tabs).
24. Prefer backend-provided totals; keep client aggregation as fallback only.

25. Phase 6: Verification and hardening (depends on all previous phases).
26. Verify timezone correctness on devices in different timezones.
27. Verify GPS scenarios: granted, denied, denied forever, disabled, timeout.
28. Validate range windows and totals against known fixtures (including cross-midnight and DST edge cases).
29. Confirm unauthorized flows still clear both session memory and persisted auth storage.

**Relevant files**
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/services/api_service.dart - clock payloads, range fetch, summary fetch, error mapping.
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/screens/home_screen.dart - clock handlers with GPS + totals display.
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/screens/history_screen.dart - tabs and range-based loading.
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/models/attendance.dart - timestamp parsing consistency and duration behavior.
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/pubspec.yaml - add geolocation package.
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/android/app/src/main/AndroidManifest.xml - Android location permissions.
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/ios/Runner/Info.plist - iOS location usage strings.
- Backend repo (outside this workspace) - attendance DTOs/controllers/services for GPS + range + summaries.

**Verification**
1. Backend: confirm GPS fields persist when present and attendance still works with null GPS.
2. Backend: confirm Today/Last 7 Days/This Month return correct records for authenticated user.
3. Backend: confirm daily/weekly/monthly totals match fixture expectations (Monday week start).
4. Frontend: run flutter analyze lib and keep clean.
5. Frontend: validate tab switching + pull-to-refresh + empty/error states.
6. Frontend: validate local-time rendering across all attendance views.

**Decisions**
- Scope: frontend + backend.
- GPS policy: optional with warning fallback.
- History UX: tabs for Today / Last 7 Days / This Month.
- Weekly boundary: Monday.
- Totals required: daily + weekly + monthly.

If you approve, this plan is ready for implementation handoff in this exact sequence.
