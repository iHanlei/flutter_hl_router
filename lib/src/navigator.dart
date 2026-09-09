import 'package:flutter/material.dart';

import 'route.dart';

/// 面向指定 Navigator 的导航控制器，适用于嵌套 Navigator 或多导航栈场景。
///
/// 通过持有的 [GlobalKey] 定位 [NavigatorState]，所有导航操作都会
/// 携带 [HlRouteArguments]（业务参数 + 过渡配置）转发给对应 Navigator。
class HlNavigatorController {
  /// 创建一个导航控制器。
  ///
  /// - [navigatorKey]: 目标 Navigator 的 [GlobalKey]，用于关联一个已有的
  ///   [Navigator]；为 `null` 时内部自动创建一个新的 [GlobalKey]。
  HlNavigatorController([GlobalKey<NavigatorState>? navigatorKey])
    : key = navigatorKey ?? GlobalKey<NavigatorState>();

  /// 用于定位目标 Navigator 的 [GlobalKey]。
  final GlobalKey<NavigatorState> key;

  /// 目标 Navigator 的当前状态。
  ///
  /// 当 Navigator 尚未挂载（[key] 未与任何 [NavigatorState] 关联）时
  /// 抛出 [StateError]。
  NavigatorState get state {
    final navigatorState = key.currentState;
    if (navigatorState == null) {
      throw StateError('The navigator is not ready.');
    }
    return navigatorState;
  }

  /// 目标 Navigator 的 [BuildContext]，未挂载时为 `null`。
  BuildContext? get context => key.currentContext;

  /// 目标 Navigator 当前是否可以返回（栈深度 > 1）。
  bool get canPop => state.canPop();

  /// 按名称推入一个路由并等待其返回结果。
  ///
  /// 返回的 [Future] 在路由弹出时携带 `pop` 传入的结果，类型为 [T]。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [arguments]: 传递给目标页面的业务参数，页面通过
  ///   [HlRouteContext.arguments] 读取。
  /// - [transition]: 路由过渡效果，默认跟随平台默认过渡。
  Future<T?> push<T>(
    String routeName, {
    Object? arguments,
    HlTransition transition = HlTransition.platform,
  }) {
    return state.pushNamed<T>(
      routeName,
      arguments: HlRouteArguments(data: arguments, transition: transition),
    );
  }

  /// 用新路由替换当前栈顶路由，并等待其返回结果。
  ///
  /// [result] 会作为被替换路由的返回值传给上一页。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [arguments]: 传递给目标页面的业务参数。
  /// - [result]: 作为被替换路由返回值传递的结果，类型为 [TO]。
  /// - [transition]: 路由过渡效果，默认跟随平台默认过渡。
  Future<T?> replace<T, TO>(
    String routeName, {
    Object? arguments,
    TO? result,
    HlTransition transition = HlTransition.platform,
  }) {
    return state.pushReplacementNamed<T, TO>(
      routeName,
      result: result,
      arguments: HlRouteArguments(data: arguments, transition: transition),
    );
  }

  /// 推入新路由，并移除栈中所有不满足 [predicate] 的旧路由。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [predicate]: 路由保留判定，返回 `true` 的路由保留，`false` 的被移除。
  /// - [arguments]: 传递给目标页面的业务参数。
  /// - [transition]: 路由过渡效果，默认无过渡。
  Future<T?> pushAndRemoveUntil<T>(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
    HlTransition transition = HlTransition.none,
  }) {
    return state.pushNamedAndRemoveUntil<T>(
      routeName,
      predicate,
      arguments: HlRouteArguments(data: arguments, transition: transition),
    );
  }

  /// 重置导航栈：推入新路由并清空栈内全部旧路由。
  ///
  /// 等价于 `pushAndRemoveUntil(routeName, (_) => false)`。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [arguments]: 传递给目标页面的业务参数。
  /// - [transition]: 路由过渡效果，默认无过渡。
  Future<T?> resetTo<T>(
    String routeName, {
    Object? arguments,
    HlTransition transition = HlTransition.none,
  }) {
    return pushAndRemoveUntil<T>(
      routeName,
      (_) => false,
      arguments: arguments,
      transition: transition,
    );
  }

  /// 直接推入一个自定义 [Route] 实例并等待其返回结果。
  ///
  /// - [route]: 自定义路由实例，页面与过渡完全由调用方构建。
  Future<T?> pushRoute<T>(Route<T> route) => state.push<T>(route);

  /// 从栈顶连续弹出 [count] 个路由。
  ///
  /// 实际弹出数量受栈深度限制；每个被弹出的路由都会收到 [result] 作为返回值。
  ///
  /// - [count]: 弹出层数，默认 1。
  /// - [result]: 传递给被弹出路由的返回值。
  void back({int count = 1, Object? result}) {
    while (count-- > 0 && state.canPop()) {
      state.pop<Object?>(result);
    }
  }

  /// 兼容旧版 [arguments] 命名的弹出方法；新代码建议使用 [back]。
  ///
  /// [result] 与 [arguments] 同时传入时抛出 [ArgumentError]。
  ///
  /// - [count]: 弹出层数，默认 1。
  /// - [result]: 传递给被弹出路由的返回值。
  /// - [arguments]: 旧版命名，与 [result] 含义相同，二者不可同时传入。
  void pop({int count = 1, Object? result, Object? arguments}) {
    if (result != null && arguments != null) {
      throw ArgumentError('Pass either result or arguments, not both.');
    }
    back(count: count, result: result ?? arguments);
  }

  /// 尝试弹出栈顶路由；栈中仅剩一个路由时不弹出。
  ///
  /// 返回 `true` 表示已弹出（或系统层面可关闭），`false` 表示无法返回。
  ///
  /// - [result]: 传递给被弹出路由的返回值。
  Future<bool> maybePop<T extends Object?>([T? result]) =>
      state.maybePop<T>(result);

  /// 依次弹出栈顶路由，直到 [predicate] 返回 `true` 为止。
  ///
  /// - [predicate]: 停止条件，对当前栈顶路由返回 `true` 时停止弹出。
  void popUntil(RoutePredicate predicate) => state.popUntil(predicate);

  /// 弹出所有路由，仅保留栈底首页。
  void popToRoot() => state.popUntil((route) => route.isFirst);

  /// 从栈中移除指定的 [route]，不触发任何过渡动画。
  ///
  /// - [route]: 要移除的路由实例。
  void removeRoute(Route<dynamic> route) => state.removeRoute(route);
}

/// 应用根 Navigator 的静态便捷入口，兼容旧版 API。
///
/// 持有全局唯一的 [GlobalKey]，所有静态导航方法均转发给内部
/// [HlNavigatorController]；适合单导航栈的应用直接调用。
class HlNavigator {
  HlNavigator._();

  /// 应用根 Navigator 的全局 [GlobalKey]。
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static final HlNavigatorController _controller = HlNavigatorController(key);

  /// 根 Navigator 的 [BuildContext]，未挂载时为 `null`。
  static BuildContext? get context => _controller.context;

  /// 根 Navigator 当前是否可以返回（栈深度 > 1）。
  static bool get canPop => _controller.canPop;

  /// 按名称在根 Navigator 上推入一个路由并等待其返回结果。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [arguments]: 传递给目标页面的业务参数。
  /// - [transition]: 路由过渡效果，默认跟随平台默认过渡。
  static Future<T?> push<T>(
    String routeName, {
    Object? arguments,
    HlTransition transition = HlTransition.platform,
  }) => _controller.push<T>(
    routeName,
    arguments: arguments,
    transition: transition,
  );

  /// 在根 Navigator 上用新路由替换当前栈顶路由。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [arguments]: 传递给目标页面的业务参数。
  /// - [result]: 作为被替换路由返回值传递的结果，类型为 [TO]。
  /// - [transition]: 路由过渡效果，默认跟随平台默认过渡。
  static Future<T?> replace<T, TO>(
    String routeName, {
    Object? arguments,
    TO? result,
    HlTransition transition = HlTransition.platform,
  }) => _controller.replace<T, TO>(
    routeName,
    arguments: arguments,
    result: result,
    transition: transition,
  );

  /// 在根 Navigator 上推入新路由，并移除栈中所有不满足 [predicate] 的旧路由。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [predicate]: 路由保留判定，返回 `true` 的路由保留，`false` 的被移除。
  /// - [arguments]: 传递给目标页面的业务参数。
  /// - [transition]: 路由过渡效果，默认无过渡。
  static Future<T?> pushAndRemoveUntil<T>(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
    HlTransition transition = HlTransition.none,
  }) => _controller.pushAndRemoveUntil<T>(
    routeName,
    predicate,
    arguments: arguments,
    transition: transition,
  );

  /// 重置根导航栈：推入新路由并清空栈内全部旧路由。
  ///
  /// - [routeName]: 目标路由名称（对应 [HlRouter] 中注册的路径）。
  /// - [arguments]: 传递给目标页面的业务参数。
  /// - [transition]: 路由过渡效果，默认无过渡。
  static Future<T?> resetTo<T>(
    String routeName, {
    Object? arguments,
    HlTransition transition = HlTransition.none,
  }) => _controller.resetTo<T>(
    routeName,
    arguments: arguments,
    transition: transition,
  );

  /// 在根 Navigator 上直接推入一个自定义 [Route] 实例。
  ///
  /// - [route]: 自定义路由实例，页面与过渡完全由调用方构建。
  static Future<T?> pushRoute<T>(Route<T> route) =>
      _controller.pushRoute<T>(route);

  /// 从根导航栈顶连续弹出 [count] 个路由。
  ///
  /// - [count]: 弹出层数，默认 1。
  /// - [result]: 传递给被弹出路由的返回值。
  static void back({int count = 1, Object? result}) =>
      _controller.back(count: count, result: result);

  /// 兼容旧版 [arguments] 命名的弹出方法；新代码建议使用 [back]。
  ///
  /// [result] 与 [arguments] 同时传入时抛出 [ArgumentError]。
  ///
  /// - [count]: 弹出层数，默认 1。
  /// - [result]: 传递给被弹出路由的返回值。
  /// - [arguments]: 旧版命名，与 [result] 含义相同，二者不可同时传入。
  static void pop({int count = 1, Object? result, Object? arguments}) =>
      _controller.pop(count: count, result: result, arguments: arguments);

  /// 尝试弹出根导航栈顶路由；栈中仅剩一个路由时不弹出。
  ///
  /// - [result]: 传递给被弹出路由的返回值。
  static Future<bool> maybePop<T extends Object?>([T? result]) =>
      _controller.maybePop<T>(result);

  /// 依次弹出根导航栈顶路由，直到 [predicate] 返回 `true` 为止。
  ///
  /// - [predicate]: 停止条件，对当前栈顶路由返回 `true` 时停止弹出。
  static void popUntil(RoutePredicate predicate) =>
      _controller.popUntil(predicate);

  /// 弹出根导航栈内所有路由，仅保留栈底首页。
  static void popToRoot() => _controller.popToRoot();
}
