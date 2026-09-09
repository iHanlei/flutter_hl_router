# hl_router

`hl_router` is a lightweight, declarative routing layer for Flutter Navigator
1.0. It supports nested route declarations, path and query parameters,
synchronous guards, redirects, transitions, custom routes, and navigation
without a widget-level `BuildContext`.

## Setup

```dart
final router = HlRouter(
  routeDefinitions: [
    HlRoute(path: '/', builder: (_) => const HomePage()),
    HlRoute(
      path: '/orders',
      builder: (_) => const OrderListPage(),
      children: [
        HlRoute(
          path: ':id',
          builder: (context) => OrderDetailPage(
            id: context.pathParameters['id']!,
            tab: context.queryParameters['tab'],
          ),
        ),
      ],
    ),
  ],
);

MaterialApp(
  navigatorKey: HlNavigator.key,
  onGenerateRoute: router.generateRoute,
);
```

Navigate with encoded parameters instead of string interpolation:

```dart
HlNavigator.push(
  HlRouteLocation.build(
    '/orders/:id',
    pathParameters: {'id': orderId},
    queryParameters: {'tab': 'payment'},
  ),
);
```

## Guards and custom navigation stacks

Guards are synchronous because Flutter's `onGenerateRoute` is synchronous.
Perform token refreshes or other asynchronous checks before navigation, then
return `HlRouteGuardResult.allow` or redirect to a location.

```dart
HlRoute(
  path: '/profile',
  builder: (_) => const ProfilePage(),
  guards: [
    (_) => isSignedIn
        ? HlRouteGuardResult.allow
        : HlRouteGuardResult.redirect('/sign-in'),
  ],
)
```

Use `HlNavigatorController` with its own `GlobalKey<NavigatorState>` for an
inner `Navigator`, such as a tab or a modal flow. It exposes `push`, `replace`,
`pushAndRemoveUntil`, `popUntil`, `popToRoot`, and `pushRoute`.

## Compatibility

The original route-table API remains supported:

```dart
HlRouter(routes: {'/settings': (_) => const SettingsPage()});
```
