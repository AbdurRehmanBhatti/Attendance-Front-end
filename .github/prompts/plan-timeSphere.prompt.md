## Plan: Offline Face Auth and Attendance Sync

Implement offline-first face enrollment, liveness gating, recognition, and attendance sync by extending current Flutter employee flow and ASP.NET Core APIs while preserving existing check-in route behavior. The approach adds a local sqflite store, singleton inference isolate initialized at app startup, mandatory liveness-before-recognition, and company-scoped embedding sync so recognition works offline.

**Steps**
1. Phase 1: Backend schema and API contract (foundation)
2. Add FaceEmbedding (nullable nvarchar(max)) to the existing User entity (mapped to Users table), configure mapping in DbContext, and create an EF migration plus SQL script for ALTER TABLE Users ADD FaceEmbedding NVARCHAR(MAX) NULL.
3. Add route constants for POST /api/employees/{id}/enroll and GET /api/employees/embeddings.
4. Add a dedicated employees embeddings API surface with company-scoped authorization rules: Employees can enroll themselves only; Admins can enroll employees in their own company; embeddings list returns only employees in caller company. This resolves privacy/scope while satisfying startup sync.
5. Add DTOs for enrollment request and embeddings response and wire service registration in Program.
6. Add backend tests for enroll authorization, company-scope filtering, missing employee handling, and successful enroll/update behavior.
7. Phase 2: Flutter foundation (parallel with Phase 1)
8. Update dependencies/assets in pubspec for camera + ML Kit + TFLite + sqflite and include MobileFaceNet model asset.
9. Add SQLite layer with tables: face_embeddings (employee_id, embedding_base64, updated_at_utc, sync_state) and attendance_outbox (queued clock-in records for offline replay).
10. Add helpers for embedding encoding/decoding (Float32 <-> base64), averaging five embeddings, and cosineSimilarity(a, b).
11. Add singleton face inference isolate service initialized at app startup and kept alive for all embedding requests (per confirmed direction), so model/interpreter are not recreated per screen.
12. Phase 3: API and startup sync integration (depends on 1, parallel with 4)
13. Extend ApiService with enrollFaceEmbedding and getEmployeeEmbeddings methods while keeping clock-in endpoint unchanged at /api/attendance/in.
14. On app startup after session restoration, trigger embeddings sync from backend and upsert into local face_embeddings so offline recognition has latest data.
15. Add retry behavior so failed sync does not block login/home rendering.
16. Phase 4: Self-enrollment flow in Flutter (depends on 2 and 3)
17. Replace original admin-only mobile enrollment assumption with self-enrollment (confirmed): add enrollment entry point in employee app UI and route.
18. Enrollment screen flow: capture 5 face photos, validate face presence per capture, generate 5 embeddings via singleton isolate, average to one 512-d embedding, save locally, then send to backend endpoint; if offline, mark pending sync locally.
19. Add clear UI feedback states for positioning, capture progress (1/5..5/5), processing, success/failure.
20. Phase 5: Liveness + recognition gate before clock-in (depends on 2 and 3)
21. Add liveness screen using google_mlkit_face_detection with random challenges (blink, turn left, turn right), face-presence checks, and pass/fail state machine.
22. Enforce invariant: liveness must pass before recognition and recognition must pass before attendance submission.
23. After liveness pass, capture one frame, compute embedding in isolate, compare against local embeddings using cosine similarity threshold > 0.75.
24. Enforce matched employee ID must equal logged-in user ID before calling clock-in endpoint (confirmed), otherwise block with Face not recognized.
25. Integrate this gate into HomeScreen clock-in action while preserving existing location acquisition and error handling patterns.
26. Phase 6: Offline attendance queue + replay (depends on 3 and 5)
27. On network/timeout during clock-in submission, enqueue attendance intent in attendance_outbox with timestamp and location.
28. Add sync service to replay pending queue on app startup, app resume, and after successful API calls.
29. Add idempotency-safe replay behavior and bounded retry metadata in queue records.
30. Phase 7: Verification and hardening (depends on all prior phases)
31. Add Flutter unit tests for cosine similarity, embedding codec, embedding average, and recognition threshold selection.
32. Add backend unit tests in AttendanceApi.Tests for new employee embeddings endpoints and scope checks.
33. Run static checks and tests, then execute manual scenarios: first-time enrollment, failed liveness, recognized check-in, unrecognized face, offline check-in queue, online replay, startup embedding sync refresh.

**Relevant files**
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/pubspec.yaml — Add ML, camera, sqflite dependencies and model asset entry
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/main.dart — Startup initialization for model isolate + embeddings sync trigger
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/services/api_service.dart — Add embeddings enroll/sync API methods and reuse auth refresh/error handling
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/screens/home_screen.dart — Gate clock-in with liveness + recognition before existing location/API logic
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/screens/login_screen.dart — Keep employee-only login behavior (self-enrollment confirmed)
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/models/user.dart — Reuse role helpers and user identity for self-match enforcement
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/lib/config/prefs_keys.dart — Add optional flags for enrollment/liveness onboarding states
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/android/app/src/main/AndroidManifest.xml — Add CAMERA permission
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/ios/Runner/Info.plist — Add NSCameraUsageDescription
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/test/widget_test.dart — Keep baseline app render test passing after startup init changes
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Front-end/test/delete_account_screen_test.dart — Preserve session-clear behavior patterns after API layer changes
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Backend/Models/User.cs — Add FaceEmbedding property
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Backend/Data/AppDbContext.cs — Configure FaceEmbedding column mapping
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Backend/Constants/ApiRoutes.cs — Add employee embeddings route constants
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Backend/Program.cs — Register embeddings service(s)
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Backend/Migrations/AppDbContextModelSnapshot.cs — Updated by EF migration
- c:/Users/AbdurRehman/source/repos/Attendance App/Attendance-Backend/AttendanceApi.Tests — Add endpoint tests for enroll + embeddings sync
- New files will be added under Front-end lib/services, lib/screens, lib/models, and Backend DTOs/Controllers/Services/Migrations for face feature implementation.

**Verification**
1. Flutter dependency and static checks: flutter pub get, flutter analyze, flutter test.
2. Backend migration and compile: dotnet ef migrations add AddFaceEmbeddingToUsers, dotnet build, dotnet test.
3. Manual mobile flow checks:
4. Enrollment success: capture 5 photos, averaged embedding stored locally and uploaded.
5. Liveness failure path: challenge fail blocks recognition and check-in.
6. Recognition success path: matched self ID allows clock-in.
7. Recognition failure path: shows Face not recognized and does not call check-in.
8. Offline check-in: record queued locally when network unavailable.
9. Queue replay: pending record syncs when network returns.
10. Startup embeddings sync refreshes local cache from backend.

**Decisions**
- Enrollment in this mobile app is self-enrollment (not admin-only mobile enrollment).
- GET /api/employees/embeddings is accessible to Employees and Admins with strict company scoping.
- Check-in route remains unchanged at POST /api/attendance/in.
- Recognized employee ID must equal logged-in user ID before check-in call.
- Inference uses a singleton isolate service initialized at app startup to keep model/interpreter in memory.

**Further Considerations**
1. Enrollment quality guard: require minimum face box size and frontal angle during capture to reduce poor embeddings.
2. Security hardening: add optional embedding version metadata to support future model upgrades without breaking comparisons.
3. Sync resilience: cap queue retry attempts and expose last sync error in diagnostics UI/logs for support.