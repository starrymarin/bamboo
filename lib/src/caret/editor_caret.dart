import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/utils.dart';

import 'caret.dart';
import '../editor/editor.dart';

///
/// 是将[RenderEditorCaret]混入[RenderEditor]的辅助类
///
mixin RenderEditorCaretMixin on RenderBox implements RenderCaretScrollSupervisor {
  final List<WeakReference<ScrollPosition>> _trackedScrollPositions = [];

  late RenderEditorCaret _renderEditorCaret;

  RenderEditorCaret get renderEditorCaret =>
      _renderEditorCaret;

  set renderEditorCaret(RenderEditorCaret value) {
    _renderEditorCaret = value;
    adoptChild(_renderEditorCaret);
  }

  @override
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
    _renderEditorCaret.markNeedsPaint();
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    _renderEditorCaret.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _renderEditorCaret.detach();
  }

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    _renderEditorCaret.markNeedsPaint();
  }

  @override
  void performLayout() {
    _renderEditorCaret.layout(constraints);
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    context.paintChild(_renderEditorCaret, offset);
  }

  @override
  void dispose() {
    super.dispose();
    _renderEditorCaret.dispose();
    for (final trackedScrollPosition in _trackedScrollPositions) {
      trackedScrollPosition.target?.removeListener(_markCursorNeedsPaint);
    }
  }
}

///
/// 用来绘制浮动光标和插入符的RenderObject，是[RenderEditor]的child
///
class RenderEditorCaret extends RenderProxyBoxChild<RenderEditor> {
  RenderEditorCaret({
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

  void updateCaret(CaretVisible? caretVisible) {
    _caretVisible = caretVisible;
    markNeedsPaint();
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
