import 'package:bamboo/bamboo.dart';
import 'package:bamboo/rendering/bamboo_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const double _kCaretHeightOffset = 2.0; // pixels

class Editor extends StatefulWidget {
  const Editor({super.key, required Document child}) : document = child;

  final Document document;

  static RenderEditor renderObject(BuildContext context) {
    _EditorScope scope =
        context.dependOnInheritedWidgetOfExactType<_EditorScope>()!;
    return scope._editorKey.currentContext?.findRenderObject() as RenderEditor;
  }

  @override
  State<StatefulWidget> createState() => EditorState();
}

class EditorState extends State<Editor> with TickerProviderStateMixin<Editor> {
  final GlobalKey _editorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return _EditorScope(
      editorKey: _editorKey,
      child: _Editor(
        key: _editorKey,
        child: widget.document,
      ),
    );
  }
}

class _EditorScope extends InheritedWidget {
  const _EditorScope({required GlobalKey editorKey, required super.child})
      : _editorKey = editorKey;

  final GlobalKey _editorKey;

  @override
  bool updateShouldNotify(covariant _EditorScope oldWidget) {
    return _editorKey != oldWidget._editorKey;
  }
}

class _Editor extends MultiChildRenderObjectWidget {
  _Editor({
    required GlobalKey super.key,
    required Document child,
  }) : super(children: [_DocumentProxy(child: child)]);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderEditor(
      bambooTheme: BambooTheme.of(context),
      devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditor renderObject) {
    renderObject
      ..bambooTheme = BambooTheme.of(context)
      ..devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  }
}

class _DocumentProxy extends SingleChildRenderObjectWidget {
  const _DocumentProxy({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDocumentProxy();
  }
}

/// 这个类的目的是用来判断[RenderEditor]中的哪一个child是用来渲染document的
class _RenderDocumentProxy extends RenderProxyBox {}

class EditorParentData extends ContainerBoxParentData<RenderBox> {}

///
/// 本质上这是一个RenderProxyBox，代理的是Document的render，通过Document的render来
/// layout,paint等等。
///
/// 之所以需要多个child，是因为floatingCursor等render是独立的，这样在光标变动时，仅需
/// 标记RenderFloatingCursor needsPaint即可，而不需要标记整个RenderEditor
///
class RenderEditor extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EditorParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EditorParentData> {
  RenderEditor({
    required BambooTheme bambooTheme,
    required double devicePixelRatio,
  })  : _bambooTheme = bambooTheme,
        _devicePixelRatio = devicePixelRatio {
    _renderEditorCursor = _RenderEditorCursor(
      bambooTheme: _bambooTheme,
      devicePixelRatio: _devicePixelRatio,
    );
    adoptChild(_renderEditorCursor);
  }

  BambooTheme _bambooTheme;

  set bambooTheme(BambooTheme value) {
    if (_bambooTheme == value) {
      return;
    }
    _bambooTheme = value;
    _renderEditorCursor.bambooTheme = _bambooTheme;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    _renderEditorCursor.devicePixelRatio = _devicePixelRatio;
    markNeedsLayout();
  }

  late _RenderEditorCursor _renderEditorCursor;

  _RenderDocumentProxy? _renderDocument;

  void setDocumentScrollController(ScrollController scrollController) {
    scrollController.addListener(() {
      _renderEditorCursor.markNeedsPaint();
    });
  }

  void updateCursor(
    RenderParagraphProxy renderParagraphProxy,
    TextPosition textPosition,
  ) {
    _renderEditorCursor._updateCursor(renderParagraphProxy, textPosition);
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    super.insert(child, after: after);
    if (child is _RenderDocumentProxy && !identical(_renderDocument, child)) {
      _renderDocument = child;
    }
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! EditorParentData) {
      child.parentData = EditorParentData();
    }
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    _renderEditorCursor.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _renderEditorCursor.detach();
  }

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    _renderEditorCursor.markNeedsPaint();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_renderDocument != null) {
      return _renderDocument!.getMinIntrinsicWidth(height);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_renderDocument != null) {
      return _renderDocument!.getMaxIntrinsicWidth(height);
    }
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_renderDocument != null) {
      return _renderDocument!.getMinIntrinsicHeight(width);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (_renderDocument != null) {
      return _renderDocument!.getMaxIntrinsicHeight(width);
    }
    return 0.0;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (_renderDocument != null) {
      return _renderDocument!.getDistanceToActualBaseline(baseline);
    }
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_renderDocument != null) {
      return _renderDocument!.getDryLayout(constraints);
    }
    return computeSizeForNoChild(constraints);
  }

  @override
  void performLayout() {
    _renderEditorCursor.layout(constraints);
    if (_renderDocument != null) {
      _renderDocument!.layout(constraints, parentUsesSize: true);
      size = _renderDocument!.size;
    } else {
      size = computeSizeForNoChild(constraints);
    }
  }

  Size computeSizeForNoChild(BoxConstraints constraints) {
    return constraints.smallest;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return _renderDocument?.hitTest(result, position: position) ?? false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_renderDocument != null) {
      context.paintChild(_renderDocument!, offset);
    }
    context.paintChild(_renderEditorCursor, offset);
  }

  @override
  void dispose() {
    super.dispose();
    _renderEditorCursor.dispose();
  }
}

class _RenderEditorCustomPaint extends RenderBox {
  @override
  RenderEditor? get parent => super.parent as RenderEditor?;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
}

class _RenderEditorCursor extends _RenderEditorCustomPaint {
  _RenderEditorCursor({
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

  late Rect? _caretPrototype = _computeCaretPrototype();

  RenderParagraphProxy? _renderParagraphProxy;
  TextPosition? _caretPosition;

  void _updateCursor(
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
          ..color = _bambooTheme.cursorColor,
      );
    }
  }
}
