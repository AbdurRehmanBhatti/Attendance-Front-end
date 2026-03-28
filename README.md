# Attendance Front-end (Mobile)

Employee-focused Flutter app for attendance clock-in/clock-out and history.

## Multi-Company Mobile Phases

### Phase 1 (Completed)
- Mobile auth/session now stores and restores `companyId` and `roles` from backend login response.
- App enforces employee-only access for mobile usage.
- Admin accounts are blocked with a clear message to use the admin web console.

### Phase 2 (Completed)
- API base URL is now environment-configurable via `--dart-define`.
- Default is `http://localhost:5054` when no override is provided.

## Run With API URL

Use `--dart-define` to target the backend environment you want.

Example:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5054
```

LAN example:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.100.46:5054
```

## Notes

- Login endpoint: `/api/auth/login`
- Employee app remains employee-focused by design; admins should use the separate `attendance-admin-web` project.

## Maintenance

- Backend change playbook for mobile: [MOBILE_BACKEND_SYNC_GUIDE.md](MOBILE_BACKEND_SYNC_GUIDE.md)
