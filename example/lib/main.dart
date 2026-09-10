import 'package:flutter/material.dart';
import 'package:hl_router/hl_router.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hl_router example',
      navigatorKey: HlNavigator.key,
      onGenerateRoute: HlRouter(
        defaultTransition: HlTransition.platform,
        unknownRouteBuilder: (context) => UnknownPage(location: context.location),
        routeDefinitions: [
          HlRoute(
            path: '/',
            builder: (context) => const HomePage(),
          ),
          HlRoute(
            path: '/detail/:id',
            transition: HlTransition.fromRight,
            builder: (context) => DetailPage(
              id: context.pathParameters['id'] ?? '?',
              query: context.queryParameters['q'] ?? '',
            ),
          ),
          HlRoute(
            path: '/fade',
            transition: HlTransition.fade,
            builder: (context) => const TransitionPage(name: 'Fade', color: Colors.purple),
          ),
          HlRoute(
            path: '/zoom',
            transition: HlTransition.zoom,
            builder: (context) => const TransitionPage(name: 'Zoom', color: Colors.teal),
          ),
          HlRoute(
            path: '/bottom',
            transition: HlTransition.fromBottom,
            builder: (context) => const TransitionPage(name: 'From Bottom', color: Colors.orange),
          ),
          HlRoute(
            path: '/none',
            transition: HlTransition.none,
            builder: (context) => const TransitionPage(name: 'No Transition', color: Colors.grey),
          ),
          HlRoute(
            path: '/args',
            builder: (context) => ArgsPage(data: context.requireArguments<String>()),
          ),
          HlRoute(
            path: '/guarded',
            guards: [
              (context) => HlRouteGuardResult.redirect('/login'),
            ],
            builder: (context) => const GuardedPage(),
          ),
          HlRoute(
            path: '/login',
            builder: (context) => const LoginPage(),
          ),
          // 嵌套路由示例：/tabs 和 /tabs/settings
          HlRoute(
            path: '/tabs',
            builder: (context) => const TabsPage(),
            children: [
              HlRoute(
                path: 'settings',
                builder: (context) => const NestedSettingsPage(),
              ),
            ],
          ),
          HlRoute(
            path: '/stack/a',
            builder: (context) => const StackPageA(),
          ),
          HlRoute(
            path: '/stack/b',
            builder: (context) => const StackPageB(),
          ),
          HlRoute(
            path: '/stack/c',
            builder: (context) => const StackPageC(),
          ),
        ],
      ).generateRoute,
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('hl_router')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _group('Basic navigation', [
            _btn('Push /detail/42', () => HlNavigator.push('/detail/42', arguments: 'hello')),
            _btn('Push via HlRouteLocation.build', () => HlNavigator.push(
              HlRouteLocation.build('/detail/:id', pathParameters: {'id': '99'}),
            )),
            _btn('Replace with /fade', () => HlNavigator.replace('/fade')),
            _btn('Push with arguments (String)', () => HlNavigator.push('/args', arguments: 'Hello from args')),
          ]),
          _group('Transitions', [
            _btn('Fade', () => HlNavigator.push('/fade')),
            _btn('Zoom', () => HlNavigator.push('/zoom')),
            _btn('From Bottom', () => HlNavigator.push('/bottom')),
            _btn('None (instant)', () => HlNavigator.push('/none')),
          ]),
          _group('Stack manipulation', [
            _btn('Push A → B → C, then popUntil A', () async {
              await HlNavigator.push('/stack/a');
            }),
            _btn('Reset to / (clear stack)', () => HlNavigator.resetTo('/')),
            _btn('Push unknown route', () => HlNavigator.push('/does/not/exist')),
          ]),
          _group('Guards', [
            _btn('Push /guarded (redirects to /login)', () => HlNavigator.push('/guarded')),
          ]),
          _group('Nested routes', [
            _btn('Push /tabs/settings', () => HlNavigator.push('/tabs/settings')),
          ]),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> buttons) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey)),
        const SizedBox(height: 8),
        ...buttons,
      ],
    ),
  );

  Widget _btn(String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    ),
  );
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.id, required this.query});

  final String id;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detail #$id')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('id: $id', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text('query: "$query"'),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => HlNavigator.back(), child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

class TransitionPage extends StatelessWidget {
  const TransitionPage({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color,
      appBar: AppBar(title: Text(name), backgroundColor: color),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: const TextStyle(fontSize: 24, color: Colors.white)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => HlNavigator.back(), child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

class ArgsPage extends StatelessWidget {
  const ArgsPage({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arguments')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Received arguments:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(data, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => HlNavigator.back(), child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

class GuardedPage extends StatelessWidget {
  const GuardedPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Guarded (should not see this)')));
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Login')),
    body: const Center(child: Text('Redirected here by route guard')),
  );
}

class UnknownPage extends StatelessWidget {
  const UnknownPage({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('404')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Route not found', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(location, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => HlNavigator.back(), child: const Text('Back')),
        ],
      ),
    ),
  );
}

class TabsPage extends StatelessWidget {
  const TabsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tabs (parent)')),
    body: const Center(child: Text('This is the parent /tabs page')),
  );
}

class NestedSettingsPage extends StatelessWidget {
  const NestedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings (nested)')),
    body: const Center(child: Text('Matched /tabs/settings via nested children')),
  );
}

class StackPageA extends StatelessWidget {
  const StackPageA({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stack A')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Page A'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => HlNavigator.push('/stack/b'), child: const Text('Push B')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => HlNavigator.popUntil((r) => r.isFirst), child: const Text('popUntil root')),
        ],
      ),
    ),
  );
}

class StackPageB extends StatelessWidget {
  const StackPageB({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stack B')),
    body: Center(
      child: ElevatedButton(onPressed: () => HlNavigator.push('/stack/c'), child: const Text('Push C')),
    ),
  );
}

class StackPageC extends StatelessWidget {
  const StackPageC({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stack C')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Page C (top of stack)'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => HlNavigator.back(count: 2), child: const Text('Back 2 (to A)')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => HlNavigator.popToRoot(), child: const Text('popToRoot')),
        ],
      ),
    ),
  );
}
