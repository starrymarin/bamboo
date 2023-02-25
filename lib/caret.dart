import 'package:bamboo/editor/editor.dart';
import 'package:flutter/widgets.dart';

abstract class CaretVisibleFinder {
  /// 查找落点所在的[CaretVisible]，如果此对象是一个[RenderObject]，那么[position]就是
  /// 落点相对于此[RenderObject]的位置。通常，该方法会由tap或者drag手势触发。
  ///
  /// 另请参阅：
  /// [CaretVisible]
  /// [CaretContainerDelegate]
  CaretVisible? findCaretVisible(Offset position);
}

mixin CaretVisible implements CaretVisibleFinder {
  Matrix4 getTransformTo(RenderObject? ancestor);

  Size get size;

  /// 返回caret的Rect，Rect都是相对于自身的
  Rect? caretRect() {
    return null;
  }
}

abstract class CaretVisibleRegistrar {
  void add(CaretVisible cursorVisible);

  void remove(CaretVisible cursorVisible);
}

///
/// [registrar]是上一层的registrar，CaretContainer会把自身的state注册到上一层，
/// [delegate]是为下层提供的registrar，下层的[CaretVisible]会被注册到[delegate]中，
/// [delegate]管理这些[CaretVisible]
///
class CaretContainer extends StatefulWidget {
  const CaretContainer({
    super.key,
    required this.registrar,
    required this.delegate,
    required this.child,
  });

  final CaretVisibleRegistrar registrar;

  final CaretContainerDelegate delegate;

  final Widget child;

  static CaretVisibleRegistrar? maybeOf(BuildContext context) {
    CaretVisibleRegistrarScope? scope = context
        .dependOnInheritedWidgetOfExactType<CaretVisibleRegistrarScope>();
    return scope?.registrar;
  }

  @override
  State<StatefulWidget> createState() => _CaretContainerState();
}

///
/// 该对象本身是一个[CaretVisible]，但实际上它是个代理，它不处理findCaretVisible，
/// 而是交给[delegate]处理，这样可以将处理逻辑外置，便于第三方拓展
///
class _CaretContainerState extends State<CaretContainer> with CaretVisible {
  @override
  void initState() {
    super.initState();
    widget.delegate.containerContext = context;
    registrar = widget.registrar;
  }

  CaretVisibleRegistrar? _registrar;

  set registrar(CaretVisibleRegistrar? value) {
    if (_registrar == value) {
      return;
    }
    _registrar?.remove(this);
    _registrar = value;
    _registrar?.add(this);
  }

  @override
  CaretVisible? findCaretVisible(Offset position) {
    return widget.delegate.findCaretVisible(position);
  }

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    return (context.findRenderObject() as RenderBox).getTransformTo(ancestor);
  }

  @override
  Size get size => (context.findRenderObject() as RenderBox).size;

  void _trackScrollPosition() {
    RenderEditor? editor = Editor.maybeOf(context)?.renderEditor;
    ScrollPosition? scrollPosition = Scrollable.maybeOf(context)?.position;
    if (editor != null && scrollPosition != null) {
      editor.caretTrack(scrollPosition);
    }
  }

  @override
  void didUpdateWidget(covariant CaretContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.delegate.containerContext = context;
    registrar = widget.registrar;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registrar = CaretContainer.maybeOf(context);
    _trackScrollPosition();
  }

  @override
  Widget build(BuildContext context) {
    _trackScrollPosition();
    return CaretVisibleRegistrarScope(
      registrar: widget.delegate,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget.registrar.remove(this);
    widget.delegate.containerContext = null;
  }
}

///
/// 保存一个[CaretVisibleRegistrar]，供下层使用
///
/// 另请参阅：
/// [_CaretContainerState.build]
/// [CaretContainer.maybeOf]
///
class CaretVisibleRegistrarScope extends InheritedWidget {
  const CaretVisibleRegistrarScope({
    super.key,
    required this.registrar,
    required super.child,
  });

  final CaretVisibleRegistrar registrar;

  @override
  bool updateShouldNotify(covariant CaretVisibleRegistrarScope oldWidget) {
    return registrar != oldWidget.registrar;
  }
}

///
/// [_CaretContainerState]会把自己注册到上层的[CaretVisibleRegistrar]，然后在build
/// 时，将[CaretContainerDelegate]作为[registrar]传递给[CaretVisibleRegistrarScope],
/// 因此下层的[CaretVisible]会被注册到[CaretContainerDelegate]中，然后
/// [_CaretContainerState.findCaretVisible]方法会调用
/// [CaretContainerDelegate.findCaretVisible]，实现[_CaretContainerState]对
/// [CaretContainerDelegate]的代理，[CaretContainerDelegate]实际负责对[CaretVisible]
/// 的管理
///
/// 在默认实现中，[CaretContainerDelegate]维护一个List，然后[findCaretVisible]方法
/// 递归查找包含落点的[CaretVisible]，并将其返回，以便绘制插入符
///
/// 如果想要自主实现其他管理方法，可以继承该类，并在[CaretContainer]创建时传入新类的对象
///
class CaretContainerDelegate
    implements CaretVisibleRegistrar, CaretVisibleFinder {
  BuildContext? containerContext;

  final List<CaretVisible> cursorVisibleList = [];

  @override
  void add(CaretVisible cursorVisible) {
    cursorVisibleList.add(cursorVisible);
  }

  @override
  void remove(CaretVisible cursorVisible) {
    cursorVisibleList.remove(cursorVisible);
  }

  @override
  CaretVisible? findCaretVisible(Offset position) {
    RenderObject? renderObject = containerContext?.findRenderObject();
    if (renderObject == null) {
      return null;
    }
    for (final caretVisible in cursorVisibleList) {
      final offset = MatrixUtils.transformPoint(
        caretVisible.getTransformTo(renderObject),
        Offset.zero,
      );
      CaretVisible? result = caretVisible.findCaretVisible(
        position.translate(-offset.dx, -offset.dy),
      );
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}