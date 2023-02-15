import 'dart:async';

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/rendering/bamboo_text.dart';
import 'package:bamboo/rendering/editor.dart';
import 'package:bamboo/rendering/proxy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const double _kCaretHeightOffset = 2.0; // pixels

@protected
mixin EditorStateFloatingCursorMixin on TickerProviderStateMixin<Editor> {
  static const Duration _kFloatingCursorResetTime = Duration(milliseconds: 125);

  EditorState get _editorState => this as EditorState;

  late final RenderEditorFloatingCursor _renderEditorFloatingCursor =
      _editorState.renderEditor._renderEditorFloatingCursor;

  TapDownDetails? _tapDownDetails;

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
    RenderParagraphProxy? paragraphProxy = _findTapDownParagraphProxy();
    debugPrint("$paragraphProxy");
    if (paragraphProxy == null) {
      return;
    }
    RenderParagraph paragraph = paragraphProxy.child;
    TextPosition textPosition = paragraph.getPositionForOffset(
      _tapDownDetails!.globalPosition - paragraph.localToGlobal(Offset.zero),
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
          Offset childOffset = child.localToGlobal(Offset.zero);
          if ((childOffset & child.size).contains(
              _tapDownDetails!.globalPosition)) {
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
    Offset paragraphOffset =
        paragraph.localToGlobal(Offset.zero) - localToGlobal(Offset.zero);
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
    caretRect = caretRect.shift(paragraphOffset);
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
