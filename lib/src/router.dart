import 'package:flutter/material.dart';

import 'route.dart';

/// 未匹配到路由时使用的构建器（旧版路由表风格）。
typedef HlUnknownRouteBuilder = Widget Function(RouteSettings settings);

/// 未匹配到路由时使用的构建器（声明式风格）。
typedef HlUnknownRoutePageBuilder = Widget Function(HlRouteContext context);

/// Navigator 1.0 的声明式路由解析器。
///
/// 兼容旧版 [routes] 路由表；新项目可通过 [routeDefinitions] 使用路径参数、
/// 查询参数、嵌套路由、守卫和自定义 [Route]。
class HlRouter {
  /// 创建路由解析器。
  ///
  /// [routes] 与 [routeDefinitions] 至少提供其一，否则抛出 [ArgumentError]；
  /// 两者同时提供时，[routes] 的条目会被合并进 [routeDefinitions] 并置前。
  ///
  /// - [routes]: 旧版字符串路由表，键为路径、值为页面构建器，保留以兼容
  ///   现有项目。
  /// - [routeDefinitions]: 声明式路由定义列表；子路由会被自动扁平化并拼接
  ///   父级路径。
  /// - [unknownRoute]: 未匹配到路由时的构建器（旧版风格），接收
  ///   [RouteSettings]。
  /// - [unknownRouteBuilder]: 未匹配到路由时的构建器（声明式风格），接收
  ///   [HlRouteContext]；优先级高于 [unknownRoute]。
  /// - [guards]: 全局守卫列表，所有路由进入前都会依次执行。
  /// - [defaultTransition]: 路由未指定过渡时的默认过渡效果，默认跟随平台
  ///   默认过渡。
  /// - [transitionDuration]: 默认的进入过渡时长，默认 300ms。
  /// - [reverseTransitionDuration]: 默认的退出过渡时长，默认 300ms。
  /// - [routeFactory]: 全局自定义 [Route] 工厂；路由未单独指定时生效。
  HlRouter({
    Map<String, HlRouteBuilder>? routes,
    Iterable<HlRoute> routeDefinitions = const <HlRoute>[],
    this.unknownRoute,
    this.unknownRouteBuilder,
    this.guards = const <HlRouteGuard>[],
    this.defaultTransition = HlTransition.platform,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration = const Duration(milliseconds: 300),
    this.routeFactory,
  }) : routes = Map.unmodifiable(routes ?? const <String, HlRouteBuilder>{}),
       routeDefinitions = List.unmodifiable(<HlRoute>[
         ...(routes ?? const <String, HlRouteBuilder>{}).entries.map(
           (entry) => HlRoute(
             path: entry.key,
             builder: (context) => entry.value(context.arguments),
           ),
         ),
         ..._flatten(routeDefinitions),
       ]) {
    if (this.routes.isEmpty && this.routeDefinitions.isEmpty) {
      throw ArgumentError('Provide routes or routeDefinitions.');
    }
  }

  /// 旧版字符串路由表，保留以兼容现有项目。
  final Map<String, HlRouteBuilder> routes;

  /// 扁平化后的声明式路由定义。
  final List<HlRoute> routeDefinitions;

  /// 未匹配到路由时的构建器（旧版风格）。
  final HlUnknownRouteBuilder? unknownRoute;

  /// 未匹配到路由时的构建器（声明式风格），优先级高于 [unknownRoute]。
  final HlUnknownRoutePageBuilder? unknownRouteBuilder;

  /// 全局守卫列表。
  final List<HlRouteGuard> guards;

  /// 默认过渡效果。
  final HlTransition defaultTransition;

  /// 默认的进入过渡时长。
  final Duration transitionDuration;

  /// 默认的退出过渡时长。
  final Duration reverseTransitionDuration;

  /// 全局自定义 [Route] 工厂。
  final HlRouteFactory? routeFactory;

  /// 根据 [RouteSettings] 生成对应的 [Route]。
  ///
  /// 内部会执行路由匹配、守卫校验与重定向处理（最多 16 次重定向），
  /// 未匹配到任何路由时退回未匹配页。
  ///
  /// - [settings]: 路由设置，[RouteSettings.name] 为导航的 location，
  ///   [RouteSettings.arguments] 为原始参数（可为 [HlRouteArguments] 或
  ///   任意业务对象）。
  Route<dynamic> generateRoute(RouteSettings settings) {
    return _generateRoute(settings, redirectDepth: 0);
  }

  /// 生成路由的内部实现，支持递归处理守卫重定向。
  ///
  /// - [settings]: 路由设置，包含 location 与参数。
  /// - [redirectDepth]: 当前重定向深度，超过 16 层时抛出 [StateError]
  ///   防止死循环。
  Route<dynamic> _generateRoute(
    RouteSettings settings, {
    required int redirectDepth,
  }) {
    if (redirectDepth > 16) {
      throw StateError('Too many route redirects for "${settings.name}".');
    }
    final config = _routeArguments(settings.arguments);
    final location = settings.name ?? '/';
    final match = _findMatch(location);
    if (match == null) return _buildUnknownRoute(settings, config, location);

    final context = HlRouteContext(
      settings: settings,
      location: location,
      arguments: config.data,
      transition: config.transition,
      pathParameters: Map.unmodifiable(match.pathParameters),
      queryParameters: Map.unmodifiable(match.queryParameters),
      queryParametersAll: Map.unmodifiable(match.queryParametersAll),
      route: match.route,
    );
    for (final guard in <HlRouteGuard>[...guards, ...match.route.guards]) {
      final result = guard(context);
      if (result is HlRouteGuardRedirect) {
        return _generateRoute(
          RouteSettings(
            name: result.location,
            arguments: HlRouteArguments(
              data:
                  result.arguments ??
                  (result.preserveArguments ? config.data : null),
              transition: result.transition ?? config.transition,
            ),
          ),
          redirectDepth: redirectDepth + 1,
        );
      }
    }
    final page = match.route.builder(context);
    final routeFactory = match.route.routeFactory ?? this.routeFactory;
    if (routeFactory != null) return routeFactory(context, page);
    return _buildRoute(context, page);
  }

  /// 构建未匹配到任何路由时的兜底页面。
  ///
  /// - [settings]: 原始路由设置，用于兜底页展示路由名称。
  /// - [config]: 解析后的导航参数（业务参数 + 过渡配置）。
  /// - [location]: 当前导航的 location 字符串。
  Route<dynamic> _buildUnknownRoute(
    RouteSettings settings,
    HlRouteArguments config,
    String location,
  ) {
    final context = HlRouteContext(
      settings: settings,
      location: location,
      arguments: config.data,
      transition: config.transition,
      pathParameters: const <String, String>{},
      queryParameters: const <String, String>{},
      queryParametersAll: const <String, List<String>>{},
    );
    final page =
        unknownRouteBuilder?.call(context) ??
        unknownRoute?.call(settings) ??
        _UnknownRoutePage(routeName: settings.name);
    return _buildRoute(context, page);
  }

  /// 根据上下文与页面构建最终的 [Route] 实例。
  ///
  /// 无过渡（或未配置任何过渡）时返回 [MaterialPageRoute]；
  /// [HlTransition.none] 返回零时长的 [PageRouteBuilder]；
  /// 其余过渡按方向/缩放/淡入淡出构建 [PageRouteBuilder]。
  ///
  /// - [context]: 已匹配的路由上下文，决定过渡配置与设置。
  /// - [page]: 页面构建器产出的页面。
  Route<dynamic> _buildRoute(HlRouteContext context, Widget page) {
    final route = context.route;
    final transition =
        route?.transition ??
        (context.transition == HlTransition.platform
            ? defaultTransition
            : context.transition);
    if (transition == HlTransition.platform &&
        route?.transitionsBuilder == null) {
      return MaterialPageRoute<dynamic>(
        builder: (_) => page,
        settings: context.settings,
      );
    }
    if (transition == HlTransition.none) {
      return PageRouteBuilder<dynamic>(
        settings: context.settings,
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }
    final duration = route?.transitionDuration ?? transitionDuration;
    final reverseDuration =
        route?.reverseTransitionDuration ?? reverseTransitionDuration;
    return PageRouteBuilder<dynamic>(
      settings: context.settings,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder:
          route?.transitionsBuilder ??
          (_, animation, secondaryAnimation, child) => _transition(
            transition,
            animation,
            child,
            route?.curve ?? Curves.easeOutCubic,
          ),
    );
  }

  /// 根据过渡类型构建对应的过渡动画 Widget。
  ///
  /// - [transition]: 目标过渡效果，`none`/`platform` 不会进入此方法。
  /// - [animation]: 路由进入动画控制器。
  /// - [child]: 被过渡的页面。
  /// - [curve]: 过渡曲线。
  static Widget _transition(
    HlTransition transition,
    Animation<double> animation,
    Widget child,
    Curve curve,
  ) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
    if (transition == HlTransition.zoom) {
      return ScaleTransition(scale: curvedAnimation, child: child);
    }
    if (transition == HlTransition.fade) {
      return FadeTransition(opacity: curvedAnimation, child: child);
    }
    final offset = switch (transition) {
      HlTransition.fromLeft => const Offset(-1, 0),
      HlTransition.fromRight => const Offset(1, 0),
      HlTransition.fromTop => const Offset(0, -1),
      HlTransition.fromBottom => const Offset(0, 1),
      _ => Offset.zero,
    };
    return SlideTransition(
      position: Tween<Offset>(
        begin: offset,
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    );
  }

  /// 在所有扁平化路由定义中查找匹配度最高的路由。
  ///
  /// 静态片段匹配得分高于路径参数；未匹配到任何路由时返回 `null`。
  _RouteMatch? _findMatch(String location) {
    _RouteMatch? bestMatch;
    for (final route in routeDefinitions) {
      final match = _match(route, location);
      if (match != null &&
          (bestMatch == null || match.specificity > bestMatch.specificity)) {
        bestMatch = match;
      }
    }
    return bestMatch;
  }

  /// 尝试用单条路由定义匹配 location，成功时返回匹配结果。
  static _RouteMatch? _match(HlRoute route, String location) {
    final uri = Uri.tryParse(location);
    if (uri == null) return null;
    final pathSegments = uri.pathSegments;
    final patternSegments = _pathSegments(route.path);
    final pathParameters = <String, String>{};
    var specificity = 0;
    var pathIndex = 0;
    for (
      var patternIndex = 0;
      patternIndex < patternSegments.length;
      patternIndex++
    ) {
      final pattern = patternSegments[patternIndex];
      if (pattern.startsWith('*')) {
        final key = pattern.substring(1);
        if (key.isNotEmpty) {
          pathParameters[key] = pathSegments.skip(pathIndex).join('/');
        }
        pathIndex = pathSegments.length;
        break;
      }
      if (pathIndex >= pathSegments.length) return null;
      final current = pathSegments[pathIndex++];
      if (pattern.startsWith(':')) {
        pathParameters[pattern.substring(1)] = current;
        specificity += 1;
      } else if (pattern == current) {
        specificity += 2;
      } else {
        return null;
      }
    }
    if (pathIndex != pathSegments.length) return null;
    return _RouteMatch(
      route,
      pathParameters,
      uri.queryParameters,
      uri.queryParametersAll,
      specificity,
    );
  }

  /// 将原始参数规整为 [HlRouteArguments]。
  ///
  /// 参数已是 [HlRouteArguments] 时原样返回，否则包装为仅含业务数据的实例。
  static HlRouteArguments _routeArguments(Object? arguments) {
    return arguments is HlRouteArguments
        ? arguments
        : HlRouteArguments(data: arguments);
  }

  /// 将嵌套路由定义扁平化为单层列表，同时拼接父级路径。
  static List<HlRoute> _flatten(Iterable<HlRoute> routes, [String? parent]) {
    final flattened = <HlRoute>[];
    for (final route in routes) {
      final path = _joinPath(parent, route.path);
      flattened.add(route.copyWith(path: path, children: const <HlRoute>[]));
      flattened.addAll(_flatten(route.children, path));
    }
    return flattened;
  }

  /// 拼接父级路径与子路由路径，处理首尾斜杠与根路径特例。
  static String _joinPath(String? parent, String path) {
    if (parent == null || parent.isEmpty || parent == '/') {
      return path.startsWith('/') ? path : '/$path';
    }
    if (path == '/') return parent;
    final prefix = parent.endsWith('/')
        ? parent.substring(0, parent.length - 1)
        : parent;
    final suffix = path.startsWith('/') ? path.substring(1) : path;
    return '$prefix/$suffix';
  }

  /// 将路径拆分为不带前导斜杠的段列表，根路径返回空列表。
  static List<String> _pathSegments(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return normalized.isEmpty ? const <String>[] : normalized.split('/');
  }
}

/// 路由匹配的内部结果。
class _RouteMatch {
  /// 创建匹配结果。
  const _RouteMatch(
    this.route,
    this.pathParameters,
    this.queryParameters,
    this.queryParametersAll,
    this.specificity,
  );

  /// 命中的路由定义。
  final HlRoute route;

  /// 路径参数映射。
  final Map<String, String> pathParameters;

  /// 查询参数映射（每键取第一个值）。
  final Map<String, String> queryParameters;

  /// 查询参数映射（每键保留全部值）。
  final Map<String, List<String>> queryParametersAll;

  /// 匹配得分。
  final int specificity;
}

/// 未匹配到任何路由时的兜底页面，仅展示路由名称。
class _UnknownRoutePage extends StatelessWidget {
  /// 创建兜底页面。
  const _UnknownRoutePage({this.routeName});

  /// 未匹配到的路由名称；为 `null` 时展示 `/`。
  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Route not found: ${routeName ?? '/'}')),
    );
  }
}
