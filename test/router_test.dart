import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hl_router/hl_router.dart';

void main() {
  testWidgets('keeps the legacy route table API', (tester) async {
    final router = HlRouter(
      routes: {'/details': (arguments) => Text('id=$arguments')},
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: router.generateRoute,
        initialRoute: '/details',
      ),
    );

    expect(find.text('id=null'), findsOneWidget);
  });

  testWidgets('matches path and query parameters', (tester) async {
    final router = HlRouter(
      routeDefinitions: [
        HlRoute(
          path: '/orders/:id',
          builder: (context) => Text(
            '${context.pathParameters['id']}: '
            '${context.queryParameters['tab']}: '
            '${context.queryParametersAll['tag']!.join(',')}',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: router.generateRoute,
        initialRoute: '/orders/42?tab=history&tag=one&tag=two',
      ),
    );

    expect(find.text('42: history: one,two'), findsOneWidget);
  });

  testWidgets('flattens nested routes and gives static paths precedence', (
    tester,
  ) async {
    final router = HlRouter(
      routeDefinitions: [
        HlRoute(
          path: '/orders',
          builder: (_) => const SizedBox(),
          children: [
            HlRoute(path: 'new', builder: (_) => const Text('new order')),
            HlRoute(
              path: ':id',
              builder: (context) =>
                  Text('order ${context.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: router.generateRoute,
        initialRoute: '/orders/new',
      ),
    );

    expect(find.text('new order'), findsOneWidget);
  });

  testWidgets('redirects with route guards', (tester) async {
    final router = HlRouter(
      routeDefinitions: [
        HlRoute(
          path: '/private',
          builder: (_) => const Text('private'),
          guards: [
            (_) =>
                HlRouteGuardResult.redirect('/sign-in', arguments: 'expired'),
          ],
        ),
        HlRoute(
          path: '/sign-in',
          builder: (context) => Text('sign in: ${context.arguments}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: router.generateRoute,
        initialRoute: '/private',
      ),
    );

    expect(find.text('sign in: expired'), findsOneWidget);
  });

  test('builds encoded route locations', () {
    expect(
      HlRouteLocation.build(
        '/orders/:id',
        pathParameters: {'id': 'A/B'},
        queryParameters: {'tab': 'payment history', 'empty': null},
      ),
      '/orders/A%2FB?tab=payment+history',
    );
  });
}
