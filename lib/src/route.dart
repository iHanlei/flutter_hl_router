import 'package:flutter/material.dart';

/// 旧路由表使用的页面构建器。
///
/// 接收导航时传入的 [Object?] 业务参数并返回页面。
/// 新项目建议使用 [HlRoute]，以取得路径参数、查询参数和守卫能力。
typedef HlRouteBuilder = Widget Function(Object? arguments);

/// 声明式路由使用的页面构建器。
///
/// 接收已匹配的 [HlRouteContext] 并返回页面。
typedef HlRoutePageBuilder = Widget Function(HlRouteContext context);

/// 自定义 [Route] 的构建器。
///
/// 接收已匹配的上下文与页面，返回自定义的 [Route] 实例；
/// 可用于接入第三方过渡库或自定义生命周期。
typedef HlRouteFactory =
    Route<dynamic> Function(HlRouteContext context, Widget page);

/// 在进入页面前同步执行的守卫。
///
/// 返回 [HlRouteGuardResult.allow] 放行，返回
/// [HlRouteGuardResult.redirect] 转向其他位置。
typedef HlRouteGuard = HlRouteGuardResult Function(HlRouteContext context);

/// 路由过渡效果。
enum HlTransition {
  /// 跟随 [HlRouter.defaultTransition] 或平台默认过渡。
  platform,

  /// 无过渡，直接切换。
  none,

  /// 新页面从左侧滑入。
  fromLeft,

  /// 新页面从右侧滑入。
  fromRight,

  /// 新页面从顶部滑入。
  fromTop,

  /// 新页面从底部滑入。
  fromBottom,

  /// 淡入淡出。
  fade,

  /// 缩放过渡。
  zoom,
}

/// 导航时附加的业务参数和过渡配置。
///
/// 由 [HlNavigatorController] 与 [HlNavigator] 在导航时自动包装，
/// 页面侧通过 [HlRouteContext.arguments] 解包获取业务参数。
class HlRouteArguments {
  /// 创建导航参数包装。
  ///
  /// - [data]: 传递给目标页面的业务参数，任意类型；为 `null` 表示不传参。
  /// - [transition]: 本次导航使用的过渡效果，默认跟随平台默认过渡。
  const HlRouteArguments({this.data, this.transition = HlTransition.platform});

  /// 业务参数，页面侧通过 [HlRouteContext.arguments] 读取。
  final Object? data;

  /// 本次导航使用的过渡效果。
  final HlTransition transition;
}

/// 已匹配路由的上下文。
///
/// 由 [HlRouter] 在路由匹配成功后构造并传入页面构建器与守卫，
/// 提供 location、参数、路径参数、查询参数及路由定义等信息。
class HlRouteContext {
  /// 创建路由上下文。
  ///
  /// - [settings]: 底层 [RouteSettings]，包含路由名称与原始参数。
  /// - [location]: 当前导航的完整 location 字符串（路径 + 查询串）。
  /// - [arguments]: 解包后的业务参数；无参数时为 `null`。
  /// - [transition]: 本次导航的过渡效果。
  /// - [pathParameters]: 匹配到的路径参数映射，键为 `:name` 中的 `name`。
  /// - [queryParameters]: 匹配到的查询参数映射（每个键取第一个值）。
  /// - [queryParametersAll]: 匹配到的查询参数映射（每个键保留全部值）。
  /// - [route]: 命中的路由定义；未匹配到任何路由时为 `null`。
  const HlRouteContext({
    required this.settings,
    required this.location,
    required this.arguments,
    required this.transition,
    required this.pathParameters,
    required this.queryParameters,
    required this.queryParametersAll,
    this.route,
  });

  /// 底层 [RouteSettings]。
  final RouteSettings settings;

  /// 当前导航的完整 location 字符串。
  final String location;

  /// 解包后的业务参数。
  final Object? arguments;

  /// 本次导航的过渡效果。
  final HlTransition transition;

  /// 路径参数映射，如 `order/:id` 匹配 `order/42` 时 `{id: '42'}`。
  final Map<String, String> pathParameters;

  /// 查询参数映射，重复键取第一个值。
  final Map<String, String> queryParameters;

  /// 查询参数映射，重复键保留全部值。
  final Map<String, List<String>> queryParametersAll;

  /// 命中的路由定义，未匹配时为 `null`。
  final HlRoute? route;

  /// 读取并校验导航参数。
  ///
  /// 参数不存在或类型不符时抛出 [ArgumentError]，错误信息中
  /// 会携带当前路由的 location 与期望类型，便于定位问题。
  T requireArguments<T>() {
    final value = arguments;
    if (value is T) return value;
    throw ArgumentError.value(
      value,
      'arguments',
      'Route "$location" requires arguments of type $T.',
    );
  }
}

/// 声明式路由定义。
///
/// [path] 支持静态片段、`:id` 形式的路径参数和 `*rest` 形式的尾部通配。
/// [children] 的相对路径会自动拼接到父级路径，便于按业务模块组织路由。
class HlRoute {
  /// 创建一条路由定义。
  ///
  /// - [path]: 路由路径，支持 `/order/:id`、`/files/*rest` 等模式。
  /// - [builder]: 页面构建器，接收 [HlRouteContext] 返回页面。
  /// - [name]: 可选的路由名称，用于调试与日志。
  /// - [transition]: 该路由专属的过渡效果；为 `null` 时使用
  ///   [HlRouter] 级配置。
  /// - [transitionDuration]: 该路由的进入过渡时长；为 `null` 时使用
  ///   [HlRouter] 级配置。
  /// - [reverseTransitionDuration]: 该路由的退出过渡时长；为 `null` 时使用
  ///   [HlRouter] 级配置。
  /// - [curve]: 过渡曲线，默认 [Curves.easeOutCubic]。
  /// - [transitionsBuilder]: 自定义过渡构建器；设置后优先于 [transition] 生效。
  /// - [routeFactory]: 自定义 [Route] 工厂；设置后优先于 [HlRouter] 级工厂生效。
  /// - [guards]: 进入该路由前执行的守卫列表，与 [HlRouter] 级守卫串联执行。
  /// - [children]: 子路由定义，相对路径会自动拼接到父级路径。
  const HlRoute({
    required this.path,
    required this.builder,
    this.name,
    this.transition,
    this.transitionDuration,
    this.reverseTransitionDuration,
    this.curve = Curves.easeOutCubic,
    this.transitionsBuilder,
    this.routeFactory,
    this.guards = const <HlRouteGuard>[],
    this.children = const <HlRoute>[],
  });

  /// 路由路径，如 `/order/:id`。
  final String path;

  /// 可选的路由名称。
  final String? name;

  /// 页面构建器。
  final HlRoutePageBuilder builder;

  /// 该路由专属的过渡效果，`null` 时使用 [HlRouter] 级配置。
  final HlTransition? transition;

  /// 该路由专属的进入过渡时长，`null` 时使用 [HlRouter] 级配置。
  final Duration? transitionDuration;

  /// 该路由专属的退出过渡时长，`null` 时使用 [HlRouter] 级配置。
  final Duration? reverseTransitionDuration;

  /// 过渡曲线。
  final Curve curve;

  /// 自定义过渡构建器，优先于 [transition] 生效。
  final RouteTransitionsBuilder? transitionsBuilder;

  /// 自定义 [Route] 工厂，优先于 [HlRouter] 级工厂生效。
  final HlRouteFactory? routeFactory;

  /// 进入该路由前执行的守卫列表。
  final List<HlRouteGuard> guards;

  /// 子路由定义。
  final List<HlRoute> children;

  /// 复制当前路由定义，可替换 [path] 与 [children]。
  ///
  /// 其余字段保持不变；为 `null` 的参数沿用当前值。
  ///
  /// - [path]: 新的路由路径；为 `null` 时沿用当前路径。
  /// - [children]: 新的子路由列表；为 `null` 时沿用当前子路由。
  HlRoute copyWith({String? path, List<HlRoute>? children}) {
    return HlRoute(
      path: path ?? this.path,
      name: name,
      builder: builder,
      transition: transition,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: reverseTransitionDuration,
      curve: curve,
      transitionsBuilder: transitionsBuilder,
      routeFactory: routeFactory,
      guards: guards,
      children: children ?? this.children,
    );
  }
}

/// 路由守卫的处理结果。
sealed class HlRouteGuardResult {
  const HlRouteGuardResult();

  /// 放行当前导航。
  static const HlRouteGuardAllow allow = HlRouteGuardAllow();

  /// 将当前导航转向 [location]。
  ///
  /// 可通过 [preserveArguments] 决定是否保留原导航参数。
  ///
  /// - [location]: 重定向目标 location（路径 + 查询串）。
  /// - [arguments]: 重定向后传给目标页面的新参数；为 `null` 且
  ///   [preserveArguments] 为 `true` 时沿用原参数。
  /// - [transition]: 重定向后的过渡效果；为 `null` 时沿用原导航的过渡配置。
  /// - [preserveArguments]: 是否保留原导航的业务参数，默认 `true`。
  static HlRouteGuardRedirect redirect(
    String location, {
    Object? arguments,
    HlTransition? transition,
    bool preserveArguments = true,
  }) {
    return HlRouteGuardRedirect(
      location,
      arguments: arguments,
      transition: transition,
      preserveArguments: preserveArguments,
    );
  }
}

/// 允许当前导航继续。
final class HlRouteGuardAllow extends HlRouteGuardResult {
  const HlRouteGuardAllow();
}

/// 将当前导航转向另一个位置。
final class HlRouteGuardRedirect extends HlRouteGuardResult {
  /// 创建重定向结果。
  ///
  /// - [location]: 重定向目标 location（路径 + 查询串）。
  /// - [arguments]: 重定向后传给目标页面的新参数；为 `null` 且
  ///   [preserveArguments] 为 `true` 时沿用原参数。
  /// - [transition]: 重定向后的过渡效果；为 `null` 时沿用原导航的过渡配置。
  /// - [preserveArguments]: 是否保留原导航的业务参数，默认 `true`。
  const HlRouteGuardRedirect(
    this.location, {
    this.arguments,
    this.transition,
    this.preserveArguments = true,
  });

  /// 重定向目标 location。
  final String location;

  /// 重定向后传给目标页面的新参数。
  final Object? arguments;

  /// 重定向后的过渡效果。
  final HlTransition? transition;

  /// 是否保留原导航的业务参数。
  final bool preserveArguments;
}

/// 构造带路径参数、查询参数的 location，避免业务层手写字符串拼接。
abstract final class HlRouteLocation {
  /// 将路径模板与参数拼接为完整 location 字符串。
  ///
  /// 路径模板中的 `:name` 占位符会以 [pathParameters] 中同名键的值替换并
  /// 进行 URL 编码；缺少对应值时抛出 [ArgumentError]。
  /// [queryParameters] 中的键值对会追加为查询串，值为 `null` 的条目会被跳过。
  ///
  /// - [path]: 路径模板，如 `/order/:id`。
  /// - [pathParameters]: 路径参数映射，键为 `:name` 中的 `name`，值会被
  ///   URL 编码。
  /// - [queryParameters]: 查询参数映射，键与值均会被 URL 编码；
  ///   `null` 值条目被跳过。
  static String build(
    String path, {
    Map<String, Object?> pathParameters = const <String, Object?>{},
    Map<String, Object?> queryParameters = const <String, Object?>{},
  }) {
    final replaced = path.replaceAllMapped(
      RegExp(r':([A-Za-z][A-Za-z0-9_]*)'),
      (match) {
        final key = match.group(1)!;
        final value = pathParameters[key];
        if (value == null) {
          throw ArgumentError.value(
            pathParameters,
            'pathParameters',
            'Missing value for path parameter ":$key".',
          );
        }
        return Uri.encodeComponent('$value');
      },
    );
    final query = queryParameters.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent('${entry.value}')}',
        )
        .join('&');
    return query.isEmpty ? replaced : '$replaced?$query';
  }
}
