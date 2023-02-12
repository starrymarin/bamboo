import 'package:bamboo/rendering/editor.dart';
import 'package:bamboo/rendering/bamboo_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

///
/// 因为TextSpan可能会被复用，所以属性与context相关时，需要提供更新的方法，并在compare
/// 中更新
///
class BambooTextSpan extends TextSpan {
  BambooTextSpan({
    required this.readOnly,
    required this.context,
    super.text,
    super.children,
    super.style,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  }) : super(recognizer: readOnly ? null : BambooTextSpanTapRecognizer()) {
    context.state()?.registerBambooTextSpanGestureRecognizer(recognizer);
    (recognizer as BambooTextSpanTapRecognizer).context = context;
  }

  final bool readOnly;

  final BambooTextBuildContext context;

  ///
  /// [other]是旧的span，如果super对比的结果是identical或者metadata，[RenderParagraph]
  /// 则继续使用旧的span，避免重绘，因此，此处需要将旧span中的相关数据更新
  ///
  @override
  RenderComparison compareTo(InlineSpan other) {
    RenderComparison result = super.compareTo(other);
    if (other is BambooTextSpan &&
        (result == RenderComparison.identical ||
            result == RenderComparison.metadata)) {
      BambooTextSpanTapRecognizer tapRecognizer =
          recognizer as BambooTextSpanTapRecognizer;
      BambooTextSpanTapRecognizer otherTapRecognizer =
          other.recognizer as BambooTextSpanTapRecognizer;
      tapRecognizer.context = otherTapRecognizer._context;
    }
    return result;
  }
}

class BambooTextSpanTapRecognizer extends TapGestureRecognizer {
  BambooTextBuildContext? _context;

  set context(BambooTextBuildContext? value) {
    if (_context == value) {
      return;
    }
    _context = value;
    _editorState = null;
    _paragraphProxy = null;
  }

  EditorState? _editorState;

  ///
  /// 这个值在第一次点击的时候获取，并在[context]重置时重置label [_editorState]，用于
  /// 下一次点击时更新
  ///
  EditorState? get editorState =>
      _editorState ??
      () {
        BuildContext? context = _context?.value;
        if (context == null) {
          return null;
        } else {
          return Editor.of(context);
        }
      }();

  TapDownDetails? _downDetails;

  RenderParagraphProxy? _paragraphProxy;

  ///
  /// 和[editorState]相同
  ///
  RenderParagraphProxy? get paragraphProxy =>
      _paragraphProxy ??
      () {
        BuildContext? context = _context?.value;
        if (context == null) {
          return null;
        } else {
          return _findRenderParagraph(context);
        }
      }();

  RenderParagraphProxy? _findRenderParagraph(BuildContext context) {
    RenderParagraphProxy? paragraph;
    context.visitChildElements((element) {
      RenderObject? renderObject = element.renderObject;
      if (renderObject is RenderParagraphProxy) {
        paragraph = renderObject;
      } else {
        paragraph = _findRenderParagraph(element);
      }
    });
    return paragraph;
  }

  @override
  GestureTapDownCallback? get onTapDown => _onTapDown;

  @override
  GestureTapCallback? get onTap => _onTap;

  void _onTapDown(TapDownDetails downDetails) {
    _downDetails = downDetails;
  }

  void _onTap() {
    if (paragraphProxy == null || editorState == null) {
      return;
    }
    RenderParagraph paragraph = paragraphProxy!.child;

    final downDetails = _downDetails;
    if (downDetails == null) {
      return;
    }

    TextPosition positionInParagraph =
        paragraph.getPositionForOffset(downDetails.localPosition);
    editorState!.updateFloatingCursor(paragraphProxy, positionInParagraph);
  }
}
