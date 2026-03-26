# Attendance App — Project Documentation

> **Last updated:** March 26, 2026 — All phases complete (Backend Phases 1–7, Flutter Phases 1–7).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Tech Stack](#3-tech-stack)
4. [Backend — ASP.NET Core Web API](#4-backend--aspnet-core-web-api)
   - 4.1 [Project Structure](#41-project-structure)
   - 4.2 [Database Schema](#42-database-schema)
   - 4.3 [API Endpoints](#43-api-endpoints)
   - 4.4 [Error Handling](#44-error-handling)
   - 4.5 [Configuration](#45-configuration)
5. [Frontend — Flutter App](#5-frontend--flutter-app)
   - 5.1 [Project Structure](#51-project-structure)
   - 5.2 [Design System](#52-design-system)
   - 5.3 [Screens](#53-screens)
   - 5.4 [Reusable Widgets](#54-reusable-widgets)
   - 5.5 [API Service Layer](#55-api-service-layer)
   - 5.6 [Navigation & Routing](#56-navigation--routing)
   - 5.7 [Animations & Micro-interactions](#57-animations--micro-interactions)
   - 5.8 [Error Handling](#58-error-handling)
6. [Data Flow](#6-data-flow)
7. [Design Decisions & Why](#7-design-decisions--why)
8. [What's Excluded (Deferred)](#8-whats-excluded-deferred)
9. [How to Run](#9-how-to-run)
10. [Changelog](#10-changelog)

---

## 1. Overview

### What

A full-stack **employee attendance tracking system** consisting of:

- **Backend**: ASP.NET Core Web API serving REST endpoints for clock-in, clock-out, and attendance retrieval.
- **Frontend**: Cross-platform Flutter mobile app with a polished Material 3 UI for employees to log their attendance.

### Why

The app replaces manual attendance registers / spreadsheets with a digital solution that:

- Records exact clock-in and clock-out timestamps with server-side `DateTime.UtcNow` (no client-side clock manipulation).
- Gives employees real-time visibility into their current status ("Clocked In since 08:30 AM").
- Provides a daily attendance history view for self-service.
- Prepares for GPS-based location capture in a future iteration (nullable lat/long columns already exist in the schema).

### How (High Level)

1. Employee opens the Flutter app → **Login Screen** authenticates against the backend.
2. After login → **Home Screen** fetches today's attendance and shows the current status.
3. Employee taps **Clock In** → `POST /api/attendance/in` creates a record with `ClockInTime = UtcNow`.
4. Employee taps **Clock Out** → `POST /api/attendance/out` finds the open record and sets `ClockOutTime = UtcNow`.
5. Employee can view **History Screen** → `GET /api/attendance/today/{userId}` returns all records for today.

---

## 2. Architecture

```
┌────────────────────┐         HTTP/JSON         ┌─────────────────────────┐
│                    │  ◄──────────────────────►  │                         │
│   Flutter App      │    POST /api/attendance/in │  ASP.NET Core Web API   │
│   (Android / iOS)  │    POST /api/attendance/out│  (.NET 10)              │
│                    │    GET  /api/attendance/    │                         │
│   Material 3 UI    │          today/{userId}    │  EF Core 10 + MSSQL     │
│   setState()       │                            │  Swagger UI             │
│                    │                            │                         │
└────────────────────┘                            └────────┬────────────────┘
                                                           │
                                                           │ EF Core
                                                           ▼
                                                  ┌─────────────────┐
                                                  │   SQL Server    │
                                                  │  AttendanceDb   │
                                                  │                 │
                                                  │  Tables:        │
                                                  │   • Users       │
                                                  │   • Attendance  │
                                                  └─────────────────┘
```

- **Communication**: JSON over HTTP. The Flutter app calls the API via the `http` package with a 15-second timeout.
- **State management**: `setState()` — chosen for simplicity since the app has only 3 screens and no cross-widget shared state.
- **Auth**: Simplified userId-in-body approach. The login endpoint is a placeholder (`/api/auth/login`) — no JWT or session tokens yet.

---

## 3. Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Backend runtime** | .NET | 10.0 |
| **Backend framework** | ASP.NET Core Web API | 10.0 |
| **ORM** | Entity Framework Core | 10.0.5 |
| **Database** | Microsoft SQL Server | Local (`Server=.`) |
| **API docs** | Swashbuckle (Swagger) | 10.1.7 |
| **Frontend framework** | Flutter | SDK ^3.9.0 |
| **Language** | Dart | (bundled with Flutter) |
| **HTTP client** | `http` package | ^1.1.0 |
| **Date formatting** | `intl` | ^0.18.0 |
| **Typography** | `google_fonts` (Poppins) | ^6.1.0 |
| **Declarative animations** | `flutter_animate` | ^4.3.0 |
| **Skeleton loading** | `shimmer` | ^3.0.0 |
| **Rich animations** | `lottie` | ^3.1.0 (available, not yet used) |

---

## 4. Backend — ASP.NET Core Web API

### 4.1 Project Structure

```
AttendanceApi/
├── Constants/
│   └── ApiRoutes.cs            # Route string constants
├── Controllers/
│   └── AttendanceController.cs # 3 REST endpoints
├── Data/
│   └── AppDbContext.cs         # EF Core DbContext, Fluent API
├── DTOs/
│   ├── ClockInRequest.cs       # Request body for clock-in
│   └── ClockOutRequest.cs      # Request body for clock-out
├── Migrations/
│   └── ...InitialCreate.cs     # Users + Attendance tables
├── Models/
│   ├── User.cs                 # User entity
│   └── Attendance.cs           # Attendance entity
├── Program.cs                  # App pipeline: DI, CORS, Swagger, error handler
├── appsettings.json            # Connection string
├── nuget.config                # NuGet source (nuget.org only)
└── DOCUMENTATION.md            # Backend-specific docs
```

### 4.2 Database Schema

**Users Table**

| Column | Type | Constraints |
|--------|------|------------|
| `UserId` | `int` | PK, identity |
| `Name` | `nvarchar(100)` | Required |
| `Email` | `nvarchar(100)` | Required |

**Attendance Table**

| Column | Type | Constraints |
|--------|------|------------|
| `AttendanceId` | `int` | PK, identity |
| `UserId` | `int` | FK → Users, cascade delete, indexed |
| `ClockInTime` | `datetime2` | Nullable |
| `ClockOutTime` | `datetime2` | Nullable |
| `Latitude` | `float` | Nullable (reserved for GPS) |
| `Longitude` | `float` | Nullable (reserved for GPS) |

**Why nullable GPS columns?** They're scaffolded now so that when GPS capture is added later, no database migration is needed — just populate the values.

### 4.3 API Endpoints

All endpoints are under the base route `api/attendance` (defined in `ApiRoutes.cs`).

| Method | Route | Purpose | Request Body | Response |
|--------|-------|---------|-------------|----------|
| `POST` | `/api/attendance/in` | Clock in | `{ "userId": int, "latitude"?: double, "longitude"?: double }` | `200 OK` → Attendance JSON |
| `POST` | `/api/attendance/out` | Clock out | `{ "userId": int }` | `200 OK` → Attendance JSON |
| `GET` | `/api/attendance/today/{userId}` | Get today's records | — | `200 OK` → `Attendance[]` JSON |

**How clock-out works:** The controller queries for the most recent attendance record for that user where `ClockOutTime == null` (i.e., still open). If none exists, it returns a `400 Bad Request` with a ProblemDetails body.

**How "today" is determined:** `DateTime.UtcNow.Date` — all records where `ClockInTime >= today (UTC midnight)` are returned, ordered by most recent first.

### 4.4 Error Handling

- **Validation errors** (missing `[Required]` fields): ASP.NET returns `400` with `ValidationProblemDetails` automatically.
- **Business logic errors** (e.g., no active clock-in): Controller returns `Problem()` with a descriptive `detail` message (RFC 7807 ProblemDetails format).
- **Unhandled exceptions**: Global `UseExceptionHandler` catches everything and returns `500` with `{ "error": "An unexpected error occurred." }`.
- **All responses**: Controller is decorated with `[Produces("application/json")]` and `[ProducesResponseType]` for Swagger documentation.

### 4.5 Configuration

**Connection String** (`appsettings.json`):
```json
"ConnectionStrings": {
  "DefaultConnection": "Server=.;Database=AttendanceDb;Trusted_Connection=true;TrustServerCertificate=true"
}
```

**CORS**: `AllowAll` policy — any origin, any header, any method. Suitable for development; should be tightened for production.

**Swagger**: Available at `/swagger` in development mode.

---

## 5. Frontend — Flutter App

### 5.1 Project Structure

```
attendance_app/
├── assets/
│   └── lottie/                     # Reserved for Lottie JSON animations
├── lib/
│   ├── config/
│   │   ├── api_config.dart         # Base URL constant
│   │   ├── app_theme.dart          # Material 3 theme, design tokens
│   │   └── page_transitions.dart   # SlideFadeRoute, SlideDirection enum
│   ├── models/
│   │   ├── attendance.dart         # Attendance model + fromJson
│   │   └── user.dart               # User model + fromJson
│   ├── services/
│   │   └── api_service.dart        # HTTP wrapper, ApiException class
│   ├── screens/
│   │   ├── login_screen.dart       # Animated login form
│   │   ├── home_screen.dart        # Dashboard: status, clock buttons, last attendance
│   │   └── history_screen.dart     # Attendance list with shimmer loading
│   ├── widgets/
│   │   ├── animated_clock_button.dart  # Gradient pill button with success/error states
│   │   ├── attendance_card.dart        # Expandable attendance entry card
│   │   ├── shimmer_list.dart           # Skeleton loading placeholder
│   │   └── status_indicator.dart       # Pulsing active/inactive dot
│   └── main.dart                   # App entry, theme wiring, route generation
├── pubspec.yaml                    # Dependencies
└── test/
    └── widget_test.dart
```

### 5.2 Design System

**Why a design system?** Consistency across all screens — every spacing value, border radius, animation duration, and color is defined once and reused everywhere.

**File: `config/app_theme.dart`**

| Token Class | Values | Purpose |
|-------------|--------|---------|
| `AppSpacing` | `xs=4, sm=8, md=16, lg=24, xl=32, xxl=48` | Consistent padding & margins |
| `AppRadius` | `sm=8, md=12, lg=16, xl=24, full=100` | Rounded corners |
| `AppDurations` | `fast=200ms, standard=300ms, emphasis=500ms, slow=800ms` | Animation timing |

**Brand Color:** `#006D5B` (deep teal) → fed into `ColorScheme.fromSeed()` which generates the full Material 3 palette (primary, secondary, tertiary, error, surface, etc.) for both light and dark themes.

**Typography:** Poppins via `google_fonts` — applied as the default text theme across the entire app.

**Themed Components:**
- **Cards**: Rounded (radius 16), elevation 2, subtle shadow at 15% opacity
- **Buttons**: Elevated and Filled variants with rounded corners (radius 12), generous padding
- **Input fields**: Filled with `surfaceContainerLow`, rounded borders, animated focus states
- **SnackBars**: Floating behavior, rounded (radius 12)
- **AppBar**: Centered title, zero elevation until scrolled (then elevation 2)

**Dark Mode:** Full support. `ThemeMode.system` detects OS preference. Both light and dark themes are generated from the same seed color, ensuring consistent branding.

### 5.3 Screens

#### Login Screen (`screens/login_screen.dart`)

**What it does:** Authenticates the user and navigates to the Home Screen.

**How:**
- Full-screen gradient background (primary → primaryContainer, top to bottom).
- Centered card with username and password fields, form validation.
- Posts to `POST /api/auth/login` and expects `{ "userId": int }` back.
- On success: pushes `HomeScreen` with a slide-up + fade transition via `SlideFadeRoute`.
- On failure: the form card shakes (TweenSequence horizontal offset animation), and a themed error SnackBar appears.

**Why designed this way:**
- The gradient + card layout creates visual hierarchy and feels more premium than a flat form.
- The shake animation provides instant tactile feedback on errors without needing to parse an error message.
- `Hero` tag on the clock icon connects login → home with a smooth hero animation.

#### Home Screen (`screens/home_screen.dart`)

**What it does:** The main dashboard showing current attendance status with clock-in/out actions.

**How:**
- On init, fetches today's attendance via `GET /api/attendance/today/{userId}`.
- **Greeting header**: Time-based greeting ("Good morning/afternoon/evening, {name}") + today's date.
- **Status card**: Glassmorphism card (BackdropFilter blur + semi-transparent gradient) showing:
  - `StatusIndicator` widget — pulsing green dot when clocked in, static gray when not.
  - Text: "Clocked In — Since 8:30 AM" or "Not Clocked In — Tap the button below".
  - Duration chip showing elapsed time when clocked in.
- **Clock buttons**: `AnimatedClockButton` wrapped in `AnimatedSwitcher` — crossfades between Clock In (green→teal gradient) and Clock Out (red→orange gradient) based on state.
- **Last Attendance card**: Shows the most recent clock-in/out times with time chips and a duration badge.
- **Pull-to-refresh**: `RefreshIndicator` wraps the entire ListView to re-fetch data.
- Haptic feedback (`HapticFeedback.mediumImpact()`) triggers on every clock tap.

**Why:**
- Glassmorphism status card differentiates the most important information visually.
- `AnimatedSwitcher` prevents confusion — only the relevant action button is shown.
- Haptic feedback confirms the tap physically, important for an action that records work time.

#### History Screen (`screens/history_screen.dart`)

**What it does:** Shows a list of today's attendance records.

**How:**
- Fetches via `GET /api/attendance/today/{userId}`.
- **Loading state**: `ShimmerList` shows 5 animated skeleton cards matching the exact layout of real cards.
- **Data state**: `ListView.builder` with staggered animations — each `AttendanceCard` fades in and slides from the right with a 100ms delay per card.
- **Empty state**: Large icon + "No attendance records today" + "Pull down to refresh".
- **Error state**: Cloud-off icon + error message + "Retry" button.
- **Pull-to-refresh**: Available in all states (loading, empty, error, data).

**Why:**
- Shimmer loading is less jarring than a centered spinner — it hints at the shape of the content about to appear.
- Staggered animations create a feeling of content "flowing" in rather than popping.
- The error state with a retry button is more discoverable than pull-to-refresh alone.

### 5.4 Reusable Widgets

#### `AnimatedClockButton` (`widgets/animated_clock_button.dart`)

**What:** Full-width gradient pill button (64px height) used for Clock In / Clock Out.

**How:**
- **4-state lifecycle**: `idle → loading → success/error → idle` (auto-resets after 1.5s).
- **Press animation**: `AnimationController` scales the button to 95% on tap.
- **Loading**: White `CircularProgressIndicator` replaces the label.
- **Success overlay**: Elastic scale-up checkmark icon in a frosted circle badge.
- **Error overlay**: Scale-up X icon with a horizontal sin-wave shake.
- Callback is `Future<void> Function()` — the button **awaits** the result to determine success or failure.

**Why `Future<void> Function()` instead of `VoidCallback`?**
The button needs to know the outcome of the async API call so it can show the correct overlay (checkmark vs X). The home screen's handlers rethrow exceptions after showing a SnackBar, letting the button catch them.

#### `AttendanceCard` (`widgets/attendance_card.dart`)

**What:** Expandable card showing a single attendance record.

**How:**
- Leading icon (green `timer` if active, primary `timer_off` if completed).
- Formatted times: "8:30 AM → 5:15 PM".
- Status label + duration chip.
- Tap to expand/collapse: `AnimatedRotation` on the arrow icon, `AnimatedCrossFade` on the detail section.
- Expanded section shows: Clock In time, Clock Out time, Duration — each as a row with icon.

#### `StatusIndicator` (`widgets/status_indicator.dart`)

**What:** Small colored dot (default 14px) that pulses when active.

**How:**
- `AnimationController` drives an opacity tween (1.0 → 0.4, reverse repeat over 1200ms).
- Green glow `BoxShadow` when active; static gray with no shadow when inactive.
- Responds to `didUpdateWidget` — starts/stops the animation when `isActive` changes.

#### `ShimmerList` (`widgets/shimmer_list.dart`)

**What:** Skeleton loading placeholder that matches `AttendanceCard` layout.

**How:**
- 5 cards (configurable via `itemCount`) using `Shimmer.fromColors`.
- Each card has placeholders matching the icon box, text lines, and duration chip of a real card.
- Dark-mode aware: uses `surfaceContainerHigh` / `surfaceContainerHighest` in dark theme, `grey.shade300` / `grey.shade100` in light.

### 5.5 API Service Layer

**File:** `services/api_service.dart`

| Method | Endpoint | Returns |
|--------|----------|---------|
| `login(username, password)` | `POST /api/auth/login` | `int` (userId) |
| `clockIn(userId)` | `POST /api/attendance/in` | `Attendance` |
| `clockOut(userId)` | `POST /api/attendance/out` | `Attendance` |
| `getTodayAttendance(userId)` | `GET /api/attendance/today/{userId}` | `List<Attendance>` |

**How it works:**
1. All requests use `Content-Type: application/json` header.
2. All requests have a **15-second timeout** — throws `TimeoutException` on expiry.
3. Non-200 responses throw `ApiException(statusCode, message)`.
4. Error messages are parsed from the RFC 7807 ProblemDetails body — checks `detail`, `error`, `title` fields in order.

**`ApiException` class:** Implements `Exception`, carries `statusCode` and `message`. Every screen catches this specifically to show user-friendly error messages.

**Base URL (`config/api_config.dart`):** `http://192.168.32.1:5054` — the development machine's LAN IP on port **5054** (matching `launchSettings.json`). This allows a physical device on the same Wi-Fi network to reach the backend directly.

> **Emulator vs Physical Device:**
> - **Android emulator**: Use `http://10.0.2.2:5054` (the emulator alias for the host's localhost).
> - **Physical device**: Use the PC's LAN IP (e.g., `http://192.168.32.1:5054`). Ensure both devices are on the same Wi-Fi and the PC firewall allows inbound on port 5054.
> - Update the `baseUrl` constant in `api_config.dart` when switching between emulator and physical device.

### 5.6 Navigation & Routing

**Named Routes (defined in `main.dart`):**

| Route | Screen | Arguments |
|-------|--------|-----------|
| `/login` | `LoginScreen` | None |
| `/home` | `HomeScreen` | `{ 'userId': int, 'userName': String }` |
| `/history` | `HistoryScreen` | `{ 'userId': int }` |

**How:** `onGenerateRoute` in `MaterialApp` maps route names to `SlideFadeRoute` instances with appropriate slide directions.

**`SlideFadeRoute` (`config/page_transitions.dart`):** A custom `PageRouteBuilder` that combines:
- `SlideTransition` (from configurable direction: right, left, up, down).
- `FadeTransition` (opacity 0→1 over the first 60% of the animation).
- Duration: 300ms both enter and exit.
- Curve: `Curves.easeOutCubic` for the slide.

**Current navigation flow:**
1. Login → Home: `pushReplacement` with `SlideFadeRoute(direction: up)` — the login screen is removed from the stack.
2. Home → History: `push` with `SlideFadeRoute(direction: right)` — the home screen stays in the stack for back navigation.

**Why `onGenerateRoute` instead of simple `routes` map?** `HomeScreen` and `HistoryScreen` require constructor arguments (`userId`, `userName`). The `routes` property only supports no-argument constructors, so `onGenerateRoute` is used to extract `settings.arguments` and pass them.

### 5.7 Animations & Micro-interactions

| Animation | Where | How | Why |
|-----------|-------|-----|-----|
| Fade-in + slide-up | Login card on load | `flutter_animate`: `.fadeIn().slideY(begin: 0.3)` | Draws attention to the form |
| Shake on error | Login card | `TweenSequence` horizontal offset (±12px) | Immediate error feedback |
| Hero transition | Clock icon, login → home | Flutter `Hero` widget with tag `app-logo` | Visual continuity between screens |
| Greeting slide-in | Home header | `.fadeIn().slideY(begin: -0.1)` | Content "arrives" naturally |
| Status card slide-in | Home status card | `.fadeIn().slideY(begin: 0.15)` with 100ms delay | Staggered entrance |
| Last attendance slide-in | Home last card | `.fadeIn().slideY(begin: 0.2)` with 200ms delay | Cascading reveal |
| Button scale on press | Clock buttons | `AnimationController` → `Transform.scale(0.95)` | Tactile press feedback |
| Button success overlay | Clock buttons | Elastic scale-up checkmark badge | Confirm action succeeded |
| Button error overlay | Clock buttons | Scale-up X + sin-wave shake | Confirm action failed |
| Clock button crossfade | Home screen | `AnimatedSwitcher` with fade + scale | Smooth state transition |
| Pulsing status dot | Home status card | Opacity 1.0→0.4 loop (1200ms) | "Alive" indicator |
| Staggered card fade-in | History list | Each card delays 100ms after previous | Content flows in |
| Expand/collapse arrow | Attendance card | `AnimatedRotation(turns: 0.5)` | Shows expand state |
| Expand/collapse detail | Attendance card | `AnimatedCrossFade` | Smooth reveal |
| Page transitions | All navigation | `SlideFadeRoute` (slide + fade) | Polish between screens |
| Haptic feedback | Clock in/out taps | `HapticFeedback.mediumImpact()` | Physical confirmation |

### 5.8 Error Handling

**Strategy:** Every API call is wrapped in `try/catch` with three levels:

1. `on ApiException catch (e)` → Shows `e.message` (the server's error detail).
2. `on TimeoutException` → Shows "Connection timed out" message.
3. `catch (_)` → Shows generic "Network error. Check your connection."

**Error display:**
- **SnackBars** with error icon: Used on Login Screen and Home Screen for transient errors.
- **Full-screen error state**: Used on History Screen with a Retry button for persistent errors.
- **Themed styling**: SnackBar background = `colorScheme.errorContainer`, text = `colorScheme.onErrorContainer`.

**No crashes on network failure:** All screens handle offline gracefully — no unhandled exceptions can reach the framework.

---

## 6. Data Flow

### Clock-In Flow

```
User taps "Clock In"
    │
    ▼
AnimatedClockButton._handleTap()
    │  state → loading (spinner shown)
    │  scale animation plays
    ▼
HomeScreen._handleClockIn()
    │  HapticFeedback.mediumImpact()
    ▼
ApiService.clockIn(userId)
    │  POST /api/attendance/in  { "userId": 1 }
    ▼
AttendanceController.ClockIn()
    │  Creates Attendance { UserId, ClockInTime = UtcNow }
    │  Saves to database
    │  Returns 200 OK → Attendance JSON
    ▼
ApiService returns Attendance object
    ▼
HomeScreen.setState()
    │  _lastAttendance = record
    │  _isClockedIn = true
    ▼
AnimatedClockButton
    │  state → success (checkmark overlay, 1.5s)
    │  state → idle
    ▼
AnimatedSwitcher crossfades to "Clock Out" button
    StatusIndicator starts pulsing green
    Status card updates text to "Clocked In — Since {time}"
```

### Clock-Out Flow

Same pattern, but:
- Controller finds the open record (`ClockOutTime == null`), sets `ClockOutTime = UtcNow`.
- If no open record → 400 with "No active clock-in found" → button shows error overlay.
- After success, `AnimatedSwitcher` crossfades back to "Clock In" button.

---

## 7. Design Decisions & Why

| Decision | Choice | Why |
|----------|--------|-----|
| **State management** | `setState()` | Only 3 screens, no cross-widget shared state. Adding Provider/Riverpod would be over-engineering for this scope. |
| **Auth approach** | userId in body, no JWT | Simplicity for MVP. The login endpoint is a placeholder. JWT can be added later without changing the UI. |
| **GPS** | Nullable columns, no capture | Schema is ready for GPS. Adding `geolocator` involves permissions, platform config, and edge cases (denied, unavailable) — deferred to avoid scope creep. |
| **Material 3** | `ColorScheme.fromSeed` | One seed color generates a complete, accessible color palette with proper contrast ratios. No manual color picking needed. |
| **Poppins font** | `google_fonts` | Modern, clean, geometric — reads well on mobile at all sizes. Loaded via package to avoid bundling font files. |
| **Shimmer loading** | `shimmer` package | Skeleton cards that match content layout are less jarring than a centered spinner and set expectations for page structure. |
| **flutter_animate** | Declarative animation chains | Writing `.fadeIn().slideY()` is far less code than manual `AnimationController` + `Tween` setup for one-shot entrance animations. |
| **AnimationController** | Status indicator pulse | Looping animations need explicit controller — `flutter_animate` is designed for one-shot chains. |
| **15s timeout** | `http` `.timeout()` | Balances responsiveness (user won't wait forever) with tolerance for slow connections. |
| **RFC 7807 ProblemDetails** | Backend error format | Industry standard for REST API errors. The Flutter `_parseError` reads `detail` → `error` → `title` → raw body as fallback. |
| **`SlideFadeRoute`** | Custom page transition | Combines slide + fade for a polished feel. Reusable across all navigations with configurable direction. |
| **LAN base URL** | `192.168.32.1:5054` | PC's LAN IP on port 5054 for physical device testing. Use `10.0.2.2:5054` for emulator instead. |

---

## 8. What's Excluded (Deferred)

| Feature | Why Deferred |
|---------|-------------|
| GPS location capture | Requires platform permissions, `geolocator` config, edge case handling. Schema is ready. |
| Provider / Riverpod | Not needed with only 3 screens and no shared state. |
| Unit / widget tests | Excluded from initial build scope. |
| Push notifications | Requires FCM setup, backend push service, device token management. |
| Offline caching | Would need local DB (e.g., `sqflite` or `drift`), sync conflict resolution. |
| JWT / token auth | Login is placeholder. Adding JWT changes the API service (token storage, refresh, interceptors). |
| Biometric auth | Depends on `local_auth`, platform permission handling. |
| Slide-to-clock gesture | Potential enhancement — a slider widget for clock-in/out instead of a button. |

---

## 9. How to Run

### Backend

```bash
cd "Attendance App/AttendanceApi"

# Restore packages
dotnet restore

# Apply migrations (creates AttendanceDb if it doesn't exist)
dotnet ef database update

# Run the API (http profile binds to http://192.168.32.1:5054)
dotnet run
```

**Prerequisites:** .NET 10 SDK, SQL Server (local instance), `dotnet-ef` tool.

**Swagger UI:** Navigate to `http://192.168.32.1:5054/swagger` in the browser (or `http://localhost:5054/swagger` if using the https profile).

### Frontend

```bash
cd "Attendance App/attendance_app"

# Get packages
flutter pub get

# Run on connected device or emulator
flutter run
```

**Prerequisites:** Flutter SDK ^3.9.0, Android SDK / Xcode (for iOS).

**API URL:** Currently set to `http://192.168.32.1:5054` (LAN IP for physical device testing). If running on an Android emulator, change `lib/config/api_config.dart` to `http://10.0.2.2:5054`. The backend runs on port **5054** as configured in `launchSettings.json`.

---

## 10. Changelog

| Date | Change | Scope |
|------|--------|-------|
| 2026-03-26 | Initial project setup — Backend Phases 1–7, Flutter Phases 1–7 complete | Full stack |
| 2026-03-26 | Backend: Added `ApiRoutes` constants, `DOCUMENTATION.md` | Backend |
| 2026-03-26 | Flutter: Full implementation of all 3 screens, 4 widgets, design system, page transitions, named routing | Frontend |
| 2026-03-26 | Updated API base URL from `http://10.0.2.2:5000` to `http://192.168.32.1:5054` (LAN IP, correct port) for physical device testing | Frontend config |
| 2026-03-26 | Backend `launchSettings.json` http profile updated to bind to `http://192.168.32.1:5054` for LAN access | Backend config |
