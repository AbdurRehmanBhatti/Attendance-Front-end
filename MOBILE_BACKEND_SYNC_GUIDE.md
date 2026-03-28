# Mobile Backend Sync Guide

Last updated: March 28, 2026

Purpose
- Keep the Flutter mobile app aligned with backend API and auth changes.
- Provide a standard process so mobile can be updated quickly and safely after backend releases.

Scope
- App: Attendance-Front-end (employee mobile app)
- Backend: Attendance-Backend API

Important Product Rule
- Mobile app is employee-focused.
- Admin accounts should use the separate admin web app.

## Current Backend Contract Used by Mobile

Authentication
- Endpoint: POST /api/auth/login
- Request body:
  - email: string
  - password: string
- Response body fields consumed by mobile:
  - token: string
  - userId: number
  - companyId: number
  - name: string
  - email: string
  - roles: string[]

Attendance
- POST /api/attendance/in
- POST /api/attendance/out
- GET /api/attendance/history?startDateUtc=...&endDateUtc=...
- GET /api/attendance/summary

## Mobile Files That Must Be Reviewed On Backend Changes

API and contracts
- lib/services/api_service.dart
- lib/models/user.dart
- lib/models/attendance.dart
- lib/models/attendance_history.dart
- lib/config/api_config.dart

Session and access behavior
- lib/services/auth_session_storage.dart
- lib/main.dart
- lib/screens/login_screen.dart
- lib/screens/home_screen.dart
- lib/screens/history_screen.dart

## Change Mapping Matrix

1. Backend changes login response fields
- Mobile impact:
  - Update parsing in lib/models/user.dart
  - Update persisted session in lib/services/auth_session_storage.dart
  - Update restore flow in lib/main.dart
  - Update role gate in lib/screens/login_screen.dart

2. Backend changes auth rules, claims, or role names
- Mobile impact:
  - Update employee role checks in lib/models/user.dart and lib/screens/login_screen.dart
  - Update startup restore guard in lib/main.dart

3. Backend changes endpoint paths
- Mobile impact:
  - Update paths in lib/services/api_service.dart

4. Backend changes DTO field names or types
- Mobile impact:
  - Update affected model fromJson and toJson methods
  - Update any UI assumptions in screens/widgets

5. Backend changes date handling or UTC policy
- Mobile impact:
  - Validate query serialization in lib/services/api_service.dart
  - Validate local display conversion in screens and models

6. Backend adds new required request fields
- Mobile impact:
  - Update request builders in lib/services/api_service.dart
  - Update related UI forms and validation

7. Backend changes error response shape
- Mobile impact:
  - Update error parsing in lib/services/api_service.dart
  - Ensure user-facing messages still show correctly

## Mandatory Update Workflow After Any Backend Release

1. Read backend release notes or PR diff.
2. Check affected endpoints and DTOs against this app contract.
3. Update models and api_service first.
4. Update session/role flow if auth payload or roles changed.
5. Run flutter analyze.
6. Run manual smoke test:
  - Employee login success
  - Invalid credentials failure message
  - Admin login blocked in mobile app
  - Clock in and clock out
  - History and summary load
  - 401 flow clears session and redirects to login
7. Update README and this guide if contract changed.

## Build and Environment Rules

API base URL
- Provided through dart define:
  - flutter run --dart-define=API_BASE_URL=http://localhost:5054

Do not hardcode environment-specific URLs in source.

## Versioning and Ownership

When backend introduces a breaking API change
- Create a mobile compatibility task immediately.
- Mark whether change is backward compatible.
- If not backward compatible, ship mobile update before backend rollout to production.

Owners
- Backend owner: updates API contract details.
- Mobile owner: updates Flutter models, services, and UX behavior.

## Quick Compatibility Checklist

- Login response still includes token, userId, companyId, roles.
- Employee role name still matches mobile check logic.
- Attendance endpoints still return expected fields and status codes.
- Error bodies still produce useful messages in app.
- Session restore works after app restart.
