import 'dart:async';

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/rendering/bamboo_text.dart';
import 'package:bamboo/rendering/editor.dart';
import 'package:bamboo/rendering/proxy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const double _kCaretHeightOffset = 2.0; // pixels

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

  void paintCaret() {}
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
  }

  @override
  Widget build(BuildContext context) {
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

@protected
mixin EditorStateFloatingCursorMixin on TickerProviderStateMixin<Editor>
    implements CaretVisibleRegistrar {
  EditorState get _editorState => this as EditorState;

  late final RenderEditorFloatingCursor _renderEditorFloatingCursor =
      _editorState.renderEditor._renderEditorFloatingCursor;

  TapDownDetails? _tapDownDetails;

  CaretVisible? _entranceCursorVisible;

  late Animation<double> _blinkAnimation;
  late final AnimationController _blinkAnimationController = () {
    AnimationController controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _blinkAnimation = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 25,
      ),
    ]).animate(controller);
    _blinkAnimation.addListener(_updateBlinkValue);
    return controller;
  }();

  void saveDownDetailsForCursor(TapDownDetails downDetails) {
    _tapDownDetails = downDetails;
  }

  void showCursorByTap() {
    CaretVisible? result =
        _entranceCursorVisible?.findCaretVisible(_tapDownDetails!.localPosition);
    RenderParagraphProxy? paragraphProxy = _findTapDownParagraphProxy();
    if (paragraphProxy == null) {
      return;
    }
    RenderParagraph paragraph = paragraphProxy.child;
    TextPosition textPosition = paragraph.getPositionForOffset(
      _tapDownDetails!.localPosition -
          paragraph.localToGlobal(Offset.zero,
              ancestor: _editorState.renderEditor),
    );
    updateFloatingCursor(paragraphProxy, textPosition);
  }

  RenderParagraphProxy? _findTapDownParagraphProxy() {
    RenderParagraphProxy? paragraphProxy;
    if (_tapDownDetails == null) {
      return null;
    } else {
      void visitor(RenderObject child) {
        if (child is RenderBox) {
          Offset childOffset = child.localToGlobal(
            Offset.zero,
            ancestor: _editorState.renderEditor,
          );
          if ((childOffset & child.size)
              .contains(_tapDownDetails!.localPosition)) {
            if (child is RenderParagraphProxy) {
              paragraphProxy = child;
            }
            child.visitChildren(visitor);
          }
        } else {
          child.visitChildren(visitor);
        }
      }

      _editorState.renderEditor.visitChildren(visitor);
    }
    return paragraphProxy;
  }

  @override
  void add(CaretVisible cursorVisible) {
    _entranceCursorVisible = cursorVisible;
  }

  @override
  void remove(CaretVisible cursorVisible) {
    _entranceCursorVisible = null;
  }

  void updateFloatingCursor(
    RenderParagraphProxy? renderParagraphProxy,
    TextPosition? textPosition,
  ) {
    _renderEditorFloatingCursor._updateFloatingCursor(
      renderParagraphProxy,
      textPosition,
    );
    _startBlink();
  }

  void hideFloatingCursor() {
    updateFloatingCursor(null, null);
    _stopBlink();
  }

  void _startBlink() {
    if (_blinkAnimationController.isAnimating) {
      _stopBlink();
    }
    Timer(const Duration(milliseconds: 500), () {
      _blinkAnimationController.repeat();
    });
  }

  void _stopBlink() {
    _blinkAnimationController.reset();
    _blinkAnimationController.stop();
    _renderEditorFloatingCursor.blinkValue = 1;
  }

  void _updateBlinkValue() {
    _renderEditorFloatingCursor.blinkValue = _blinkAnimation.value;
  }

  @override
  void dispose() {
    super.dispose();
    _blinkAnimation.removeListener(_updateBlinkValue);
    _blinkAnimationController.dispose();
  }
}

@protected
mixin RenderEditorFloatingCursorMixin on RenderBox {
  late RenderEditorFloatingCursor _renderEditorFloatingCursor;

  RenderEditorFloatingCursor get renderEditorFloatingCursor =>
      _renderEditorFloatingCursor;

  set renderEditorFloatingCursor(RenderEditorFloatingCursor value) {
    _renderEditorFloatingCursor = value;
    adoptChild(_renderEditorFloatingCursor);
  }

  void setDocumentScrollController(ScrollController scrollController) {
    scrollController.addListener(() {
      _renderEditorFloatingCursor.markNeedsPaint();
    });
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    _renderEditorFloatingCursor.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _renderEditorFloatingCursor.detach();
  }

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    _renderEditorFloatingCursor.markNeedsPaint();
  }

  @override
  void performLayout() {
    _renderEditorFloatingCursor.layout(constraints);
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    context.paintChild(_renderEditorFloatingCursor, offset);
  }

  @override
  void dispose() {
    super.dispose();
    _renderEditorFloatingCursor.dispose();
  }
}

@protected
class RenderEditorFloatingCursor extends RenderProxyBoxChild<RenderEditor> {
  RenderEditorFloatingCursor({
    required BambooTheme bambooTheme,
    required double devicePixelRatio,
  })  : _bambooTheme = bambooTheme,
        _devicePixelRatio = devicePixelRatio;

  BambooTheme _bambooTheme;

  set bambooTheme(BambooTheme value) {
    if (_bambooTheme == value) {
      return;
    }
    _bambooTheme = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  double _blinkValue = 1;

  set blinkValue(double value) {
    if (_blinkValue == value) {
      return;
    }
    _blinkValue = value;
    markNeedsPaint();
  }

  late Rect? _caretPrototype = _computeCaretPrototype();

  RenderParagraphProxy? _renderParagraphProxy;
  TextPosition? _caretPosition;

  void _updateFloatingCursor(
    RenderParagraphProxy? renderParagraphProxy,
    TextPosition? textPosition,
  ) {
    _renderParagraphProxy = renderParagraphProxy;
    _caretPosition = textPosition;
    markNeedsPaint();
  }

  Rect? _computeCaretPrototype() {
    double cursorWidth = _bambooTheme.cursorWidth;
    double? cursorHeight =
        _bambooTheme.cursorHeight ?? _renderParagraphProxy?.preferredLineHeight;
    if (cursorHeight == null) {
      return null;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Rect.fromLTWH(0.0, 0.0, cursorWidth, cursorHeight + 2);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return Rect.fromLTWH(
          0.0,
          _kCaretHeightOffset,
          cursorWidth,
          cursorHeight - 2.0 * _kCaretHeightOffset,
        );
    }
  }

  @override
  void markNeedsPaint() {
    _caretPrototype = _computeCaretPrototype();
    super.markNeedsPaint();
  }

  // Computes the offset to apply to the given [sourceOffset] so it perfectly
  // snaps to physical pixels.
  Offset _snapToPhysicalPixel(Offset sourceOffset) {
    final Offset globalOffset = localToGlobal(sourceOffset);
    final double pixelMultiple = 1.0 / _devicePixelRatio;
    return Offset(
      globalOffset.dx.isFinite
          ? (globalOffset.dx / pixelMultiple).round() * pixelMultiple -
              globalOffset.dx
          : 0,
      globalOffset.dy.isFinite
          ? (globalOffset.dy / pixelMultiple).round() * pixelMultiple -
              globalOffset.dy
          : 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final renderParagraphProxy = _renderParagraphProxy;
    final caretPosition = _caretPosition;
    final caretPrototype = _caretPrototype;
    if (renderParagraphProxy == null ||
        caretPosition == null ||
        caretPrototype == null) {
      return;
    }

    RenderParagraph paragraph = renderParagraphProxy.child;
    Offset paragraphOffsetToRenderEditor =
        paragraph.localToGlobal(Offset.zero, ancestor: parent);
    Offset caretOffset =
        paragraph.getOffsetForCaret(caretPosition, caretPrototype);
    Rect caretRect = caretPrototype.shift(caretOffset);

    final double? caretHeight = paragraph.getFullHeightForCaret(caretPosition);
    if (caretHeight != null) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          final double heightDiff = caretHeight - caretRect.height;
          caretRect = Rect.fromLTWH(
            caretRect.left,
            caretRect.top + heightDiff / 2,
            caretRect.width,
            caretRect.height,
          );
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          caretRect = Rect.fromLTWH(
            caretRect.left,
            caretRect.top - _kCaretHeightOffset,
            caretRect.width,
            caretHeight,
          );
          break;
      }
    }
    caretRect = caretRect.shift(paragraphOffsetToRenderEditor);
    final Rect integralRect =
        caretRect.shift(_snapToPhysicalPixel(caretRect.topLeft));

    RRect caretRRect = RRect.fromRectAndRadius(
      integralRect,
      _bambooTheme.cursorRadius,
    );

    if (!caretRRect.hasNaN) {
      context.canvas.drawRRect(
        caretRRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = _bambooTheme.cursorColor.withOpacity(_blinkValue * 0.75),
      );
    }
  }
}
