import 'dart:async';

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/caret.dart';
import 'package:bamboo/rendering/proxy.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'cursor.dart';

class Editor extends StatefulWidget {
  const Editor({super.key, required Document child}) : document = child;

  final Document document;

  static EditorState? maybeOf(BuildContext context) {
    _EditorScope? scope =
        context.dependOnInheritedWidgetOfExactType<_EditorScope>();
    return scope?._editorKey.currentContext
        ?.findAncestorStateOfType<EditorState>();
  }

  @override
  State<StatefulWidget> createState() => EditorState();
}

class EditorState extends State<Editor>
    with TickerProviderStateMixin<Editor>, _EditorStateFloatingCursorMixin {
  final GlobalKey _editorKey = GlobalKey();

  RenderEditor get renderEditor =>
      _editorKey.currentContext?.findRenderObject() as RenderEditor;

  @override
  Widget build(BuildContext context) {
    CaretContainerDelegate caretContainerDelegate = CaretContainerDelegate();
    return CaretContainer(
      registrar: this,
      delegate: caretContainerDelegate,
      child: _EditorScope(
        editorKey: _editorKey,
        child: GestureDetector(
          onTapDown: saveDownDetailsForCursor,
          onTap: showCursorByTap,
          child: _Editor(
            key: _editorKey,
            child: widget.document,
          ),
        ),
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

/// ?????????????????????????????????[RenderEditor]???????????????child???????????????document???
class _RenderDocumentProxy extends RenderProxyBox {}

class EditorParentData extends ContainerBoxParentData<RenderBox> {}

///
/// ?????????????????????RenderProxyBox???????????????Document???render?????????Document???render???
/// layout,paint?????????
///
/// ?????????????????????child????????????floatingCursor???render????????????????????????????????????????????????
/// ??????RenderFloatingCursor needsPaint?????????????????????????????????RenderEditor
///
class RenderEditor extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EditorParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EditorParentData>,
        RenderObjectWithLateChildMixin<_RenderDocumentProxy>,
        RenderProxyBoxMixin<_RenderDocumentProxy>,
        _RenderEditorFloatingCursorMixin {
  RenderEditor({
    required BambooTheme bambooTheme,
    required double devicePixelRatio,
  })  : _bambooTheme = bambooTheme,
        _devicePixelRatio = devicePixelRatio {
    renderEditorFloatingCursor = _RenderEditorFloatingCursor(
      bambooTheme: _bambooTheme,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  BambooTheme _bambooTheme;

  set bambooTheme(BambooTheme value) {
    if (_bambooTheme == value) {
      return;
    }
    _bambooTheme = value;
    renderEditorFloatingCursor.bambooTheme = _bambooTheme;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    renderEditorFloatingCursor.devicePixelRatio = _devicePixelRatio;
    markNeedsLayout();
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    super.insert(child, after: after);
    if (child is _RenderDocumentProxy) {
      this.child = child;
    }
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! EditorParentData) {
      child.parentData = EditorParentData();
    }
  }
}
