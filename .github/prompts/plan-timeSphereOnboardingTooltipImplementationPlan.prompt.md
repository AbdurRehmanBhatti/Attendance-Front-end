## Plan: Time Sphere onboarding and coach mark rollout

This plan is ready for implementation handoff and has been saved to session memory at /memories/session/plan.md.  
Approach: add required packages/assets first, then build onboarding UI, gate startup in main, and finally add first-time coach mark behavior on the home clock button with safe async handling.

**Steps**
1. Phase 1, dependency and asset wiring  
2. Update [pubspec.yaml](../../pubspec.yaml) with introduction_screen and tutorial_coach_mark, keeping shared_preferences declared once and aligned to your requested version policy.
3. Extend Flutter assets in [pubspec.yaml](../../pubspec.yaml) to include assets/images/ along with existing assets/lottie/.
4. Add placeholder images in assets/images/ named onboarding_1.png, onboarding_2.png, onboarding_3.png.  
5. Run flutter pub get and resolve dependency constraints before code integration.  
6. Phase 2, onboarding screen  
7. Create a new onboarding screen under lib/screens using IntroductionScreen with exactly 3 pages and your provided text content.  
8. Use Image.asset for onboarding_1.png, onboarding_2.png, onboarding_3.png.  
9. Implement completeOnboarding flow with try/catch, write onboarding_seen = true, mounted check after await, then replacement navigation to login.  
10. Configure controls so Skip appears on non-final pages, Get Started on final page, both calling the same completion method.  
11. Phase 3, startup gate  
12. In [lib/main.dart](../../lib/main.dart), add onboarding_seen check into existing startup initialization flow before deciding what startup screen to render.
13. Preserve existing loading behavior (plain progress indicator) while preferences/session state loads.  
14. Keep preference reads in try/catch and define fallback behavior explicitly.  
15. Ensure post-onboarding navigation uses replacement semantics only.  
16. Phase 4, coach mark on clock-in  
17. In [lib/screens/home_screen.dart](../../lib/screens/home_screen.dart), add a GlobalKey target for the visible clock-in control and attach it to the rendered button wrapper.
18. Add showClockInTutorial using TutorialCoachMark with top-aligned content, required title/body, and shadow color black87.  
19. Trigger tutorial in initState via addPostFrameCallback, then read tutorial_seen in try/catch and only show when false.  
20. Persist tutorial_seen = true on both finish and skip callbacks using try/catch.  
21. Phase 5, consistency hardening  
22. Centralize string keys onboarding_seen and tutorial_seen in one place to avoid drift.  
23. Follow existing mounted-after-await and route replacement patterns throughout.

**Relevant files**
1. [pubspec.yaml](../../pubspec.yaml) for dependencies and assets declaration
2. [lib/main.dart](../../lib/main.dart) for startup gating and loading flow
3. [lib/screens/home_screen.dart](../../lib/screens/home_screen.dart) for GlobalKey target and coach mark trigger
4. [lib/services/auth_session_storage.dart](../../lib/services/auth_session_storage.dart) as reference for existing SharedPreferences conventions
5. New onboarding screen file under lib/screens (to be created during implementation)

**Verification**
1. Run flutter pub get successfully.  
2. Fresh install launch shows onboarding before normal auth/home path.  
3. Skip on page 1 or 2 marks onboarding_seen and replacement-navigates to login.  
4. Relaunch does not show onboarding again.  
5. First post-login home render shows coach mark anchored to clock-in button.  
6. Finish and skip both persist tutorial_seen.  
7. Subsequent app opens/home entries do not show coach mark again.  
8. Run flutter analyze and perform manual startup/home smoke checks.

**Decisions captured**
1. Key names remain exactly onboarding_seen and tutorial_seen.  
2. Tutorial is treated as first-login experience by showing on first eligible home render only.  
3. Scope includes onboarding, startup gate, tutorial coach mark, and placeholders; excludes final illustration redesign and analytics.

If you want, I can refine this one step further into an execution checklist grouped by commit boundaries (for example: dependency commit, onboarding commit, startup gate commit, coach mark commit).
