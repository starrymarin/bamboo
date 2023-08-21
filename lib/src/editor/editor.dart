import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/utils.dart';

import '../caret/caret.dart';
import '../caret/editor_caret.dart';
import 'document.dart';

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
    with TickerProviderStateMixin<Editor> implements CaretVisibleRegistrar {
  final GlobalKey _editorKey = GlobalKey();

  RenderEditor get renderEditor =>
      _editorKey.currentContext?.findRenderObject() as RenderEditor;

  RenderEditorCaret get _renderEditorCaret => renderEditor.renderEditorCaret;

  TapDownDetails? _tapDownDetails;

  CaretVisible? _entranceCaretVisible;

  final FocusNode _focusNode = FocusNode();

  late Animation<double> _caretBlinkAnimation;
  late final AnimationController _caretBlinkAnimationController = () {
    AnimationController controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _caretBlinkAnimation = TweenSequence([
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
    _caretBlinkAnimation.addListener(_updateBlinkValue);
    return controller;
  }();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleTapDown(TapDownDetails downDetails) {
    _tapDownDetails = downDetails;
  }

  /// 当点击的时候，应该让[_focusNode]获取焦点，从而显示光标。如果[_focusNode]已经获取焦点
  /// 则手动调用[_handleFocusChanged]，命令其更新光标
  void _handleTap() {
    if (_focusNode.hasFocus) {
      _handleFocusChanged();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      TapDownDetails? tapDownDetails = _tapDownDetails;
      CaretVisible? effectiveCaretVisible;
      if (tapDownDetails != null) {
        effectiveCaretVisible = _entranceCaretVisible
            ?.findCaretVisible(tapDownDetails.localPosition);
      }
      if (effectiveCaretVisible != null) {
        _renderEditorCaret.updateCaret(effectiveCaretVisible);
        _startBlink();
      }
    } else {
      _renderEditorCaret.updateCaret(null);
      _stopBlink();
      _tapDownDetails = null;
    }
  }

  @override
  void add(CaretVisible cursorVisible) {
    _entranceCaretVisible = cursorVisible;
  }

  @override
  void remove(CaretVisible cursorVisible) {
    _entranceCaretVisible = null;
  }

  void _startBlink() {
    if (_caretBlinkAnimationController.isAnimating) {
      _stopBlink();
    }
    Timer(const Duration(milliseconds: 500), () {
      _caretBlinkAnimationController.repeat();
    });
  }

  void _stopBlink() {
    _caretBlinkAnimationController.reset();
    _caretBlinkAnimationController.stop();
    _renderEditorCaret.blinkValue = 1;
  }

  void _updateBlinkValue() {
    _renderEditorCaret.blinkValue = _caretBlinkAnimation.value;
  }

  @override
  Widget build(BuildContext context) {
    CaretContainerDelegate caretContainerDelegate = CaretContainerDelegate();
    return CaretContainer(
      registrar: this,
      delegate: caretContainerDelegate,
      child: Focus(
        focusNode: _focusNode,
        child: _EditorScope(
          editorKey: _editorKey,
          child: CaretScrollSupervisor(
            supervisorKey: _editorKey,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTap: _handleTap,
              child: _Editor(
                key: _editorKey,
                child: widget.document,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _caretBlinkAnimation.removeListener(_updateBlinkValue);
    _caretBlinkAnimationController.dispose();
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
  }) : super(children: [DocumentProxy(child: child)]);

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
        RenderBoxContainerDefaultsMixin<RenderBox, EditorParentData>,
        RenderObjectWithLateChildMixin<RenderDocumentProxy>,
        RenderProxyBoxMixin<RenderDocumentProxy>,
        RenderEditorCaretMixin {
  RenderEditor({
    required BambooTheme bambooTheme,
    required double devicePixelRatio,
  })  : _bambooTheme = bambooTheme,
        _devicePixelRatio = devicePixelRatio {
    renderEditorCaret = RenderEditorCaret(
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
    renderEditorCaret.bambooTheme = _bambooTheme;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    renderEditorCaret.devicePixelRatio = _devicePixelRatio;
    markNeedsLayout();
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    super.insert(child, after: after);
    if (child is RenderDocumentProxy) {
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
