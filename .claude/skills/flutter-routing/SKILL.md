---
name: flutter-routing
description: Use when adding or changing a screen/route, wiring navigation guards (join-approval, room membership), configuring deep links, or debugging a route that opens the wrong screen or loses state on relaunch.
---

# Flutter Routing (go_router)

## Overview

Cantaê has no login/account system (local-first, out of scope per `CLAUDE.md`), so "auth redirects" here mean **session/room-membership guards**: a visitor can't land on the Master Room screen without an approved session, and a deep link to a room code must route through discovery+handshake, not straight into the player.

## Router Shape

- One `GoRouter` instance, created once, injected via Riverpod (`Provider<GoRouter>`), not rebuilt per navigation.
- Routes declared as a flat `routes:` list with nested `ShellRoute`/`StatefulShellRoute` only where bottom-nav/tab state must survive route changes (e.g., Library tabs).
- Named routes (`name:`) always — never navigate by raw path string; typos in path strings are a runtime failure, not a compile error.

```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    redirect: (context, state) => ref.read(sessionGuardProvider).evaluate(state),
    routes: [
      GoRoute(name: 'library', path: '/', builder: (c, s) => const LibraryScreen()),
      GoRoute(
        name: 'room',
        path: '/room/:code',
        builder: (c, s) => RoomScreen(code: s.pathParameters['code']!),
      ),
    ],
  );
});
```

## Redirect / Guard Pattern

Keep guard logic out of the `redirect:` closure itself — delegate to a domain-level predicate so it's testable without `BuildContext`:

```dart
class SessionGuard {
  SessionGuard(this._session);
  final SessionState _session;

  String? evaluate(GoRouterState state) {
    final enteringRoom = state.matchedLocation.startsWith('/room/');
    if (enteringRoom && !_session.isApproved) return '/join/${state.pathParameters['code']}';
    return null; // no redirect
  }
}
```

## Deep Linking (room code via mDNS, not a URL scheme)

Cantaê's "deep link" is a 4-digit visual code entered by the user, not a platform URL scheme — so `go_router`'s path parameters are enough; you do **not** need `app_links`/platform channel URI handling unless a future feature requires opening the app from an external link. Don't add that plumbing speculatively.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Navigating with `context.go('/room/' + code)` | Use `context.goNamed('room', pathParameters: {'code': code})` |
| Guard logic inline in `redirect:` reading providers ad hoc | Extract to a plain class (`SessionGuard`) testable in isolation |
| Rebuilding `GoRouter` on every provider change | Create once; `refreshListenable`/`ref.listen` to trigger re-evaluation instead |
| Using `Navigator.push` for app-level screens alongside `go_router` | Pick one navigator for top-level routes; `Navigator.push` only for in-page dialogs/sheets |

**REQUIRED BACKGROUND:** `flutter-clean-architecture` — guards and redirect predicates belong in `domain/`/`presentation/`, not inline infra calls.
