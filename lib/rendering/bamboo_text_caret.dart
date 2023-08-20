part of 'bamboo_text.dart';

const double _kCaretHeightOffset = 2.0; // pixels

mixin _RenderParagraphProxyCursorMixin
    on _ChildRenderParagraphMixin
    implements CaretVisible {
  Offset? _positionWhenFound;
  Rect? _caretPrototype;

  CaretVisibleRegistrar? _caretRegistrar;

  set caretRegistrar(CaretVisibleRegistrar value) {
    if (_caretRegistrar == value) {
      return;
    }
    _caretRegistrar?.remove(this);
    _caretRegistrar = value;
    _caretRegistrar!.add(this);
  }

  BambooTheme? _bambooTheme;

  set bambooTheme(BambooTheme value) {
    if (_bambooTheme == value) {
      return;
    }
    _bambooTheme = value;
    _caretPrototype = _computeCaretPrototype();
  }

  Rect? _computeCaretPrototype() {
    double cursorWidth = _bambooTheme!.cursorWidth;
    double cursorHeight = _bambooTheme!.cursorHeight ?? _renderParagraph.textPainter.preferredLineHeight;
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

  /// 如果position在这个RenderBox中，返回本身，否则返回null
  @override
  CaretVisible? findCaretVisible(Offset position) {
    if (Rect.fromLTWH(0, 0, size.width, size.height).contains(position)) {
      _positionWhenFound = position;
      return this;
    } else {
      return null;
    }
  }

  @override
  Rect? caretRect() {
    if (_positionWhenFound == null || _caretPrototype == null) {
      return null;
    }
    Offset offset = _positionWhenFound!;
    Rect caretPrototype = _caretPrototype!;
    RenderBambooParagraph paragraph = _renderParagraph;
    TextPosition textPosition = paragraph.getPositionForOffset(offset);
    Offset caretOffset =
    paragraph.getOffsetForCaret(textPosition, caretPrototype);
    Rect caretRect = caretPrototype.shift(caretOffset);

    final double? caretHeight = paragraph.getFullHeightForCaret(textPosition);
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
    return caretRect;
  }
}
