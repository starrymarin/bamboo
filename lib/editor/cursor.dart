part of 'editor.dart';

///
/// 是将有关浮动光标和插入符的管理混入[EditorState]的辅助类
///
mixin _EditorStateFloatingCursorMixin on TickerProviderStateMixin<Editor>
    implements CaretVisibleRegistrar {
  EditorState get _editorState => this as EditorState;

  late final _RenderEditorFloatingCursor _renderEditorFloatingCursor =
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
    CaretVisible? effectiveCursorVisible = _entranceCursorVisible
        ?.findCaretVisible(_tapDownDetails!.localPosition);
    updateCaret(effectiveCursorVisible);
  }

  @override
  void add(CaretVisible cursorVisible) {
    _entranceCursorVisible = cursorVisible;
  }

  @override
  void remove(CaretVisible cursorVisible) {
    _entranceCursorVisible = null;
  }

  void updateCaret(CaretVisible? caretVisible) {
    _renderEditorFloatingCursor._updateCaret(caretVisible);
    _startBlink();
  }

  void hideFloatingCursor() {
    updateCaret(null);
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

///
/// 是将[_RenderEditorFloatingCursor]混入[RenderEditor]的辅助类
///
mixin _RenderEditorFloatingCursorMixin on RenderBox {
  final List<WeakReference<ScrollPosition>> _trackedScrollPositions = [];

  late _RenderEditorFloatingCursor _renderEditorFloatingCursor;

  _RenderEditorFloatingCursor get renderEditorFloatingCursor =>
      _renderEditorFloatingCursor;

  set renderEditorFloatingCursor(_RenderEditorFloatingCursor value) {
    _renderEditorFloatingCursor = value;
    adoptChild(_renderEditorFloatingCursor);
  }

  void caretTrack(ScrollPosition position) {
    position.removeListener(_markCursorNeedsPaint);
    position.addListener(_markCursorNeedsPaint);
    for (final trackedScrollPosition in _trackedScrollPositions) {
      if (trackedScrollPosition.target == position) {
        return;
      }
    }
    _trackedScrollPositions.add(WeakReference(position));
  }

  void _markCursorNeedsPaint() {
    _renderEditorFloatingCursor.markNeedsPaint();
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
    for (final trackedScrollPosition in _trackedScrollPositions) {
      trackedScrollPosition.target?.removeListener(_markCursorNeedsPaint);
    }
  }
}

///
/// 用来绘制浮动光标和插入符的RenderObject，是[RenderEditor]的child
///
class _RenderEditorFloatingCursor extends RenderProxyBoxChild<RenderEditor> {
  _RenderEditorFloatingCursor({
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

  CaretVisible? _caretVisible;

  void _updateCaret(CaretVisible? caretVisible) {
    _caretVisible = caretVisible;
    if (_caretVisible != null) {
      markNeedsPaint();
    }
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
    if (_caretVisible != null) {
      CaretVisible caretVisible = _caretVisible!;
      Rect? caretRect = caretVisible.caretRect();
      if (caretRect != null) {
        Offset caretVisibleOffsetToRenderEditor = MatrixUtils.transformPoint(
          caretVisible.getTransformTo(parent),
          Offset.zero,
        );
        caretRect = caretRect.shift(caretVisibleOffsetToRenderEditor);
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
              ..color =
                  _bambooTheme.cursorColor.withOpacity(_blinkValue * 0.75),
          );
        }
      }
    }
  }
}
