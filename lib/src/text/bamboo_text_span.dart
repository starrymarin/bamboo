import 'package:bamboo/node.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'bamboo_text.dart';

///
/// 因为TextSpan可能会被复用，所以属性与context相关时，需要提供更新的方法，并在compare
/// 中更新
///
class BambooTextSpan extends TextSpan {
  BambooTextSpan({
    required this.textNode,
    required this.readOnly,
    required this.context,
    super.children,
    super.style,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  }) : super(text: textNode.text);

  final TextNode textNode;

  final bool readOnly;

  final BambooTextBuildContext context;

  @override
  String get text => super.text as String;

  ///
  /// [other]是旧的span，如果super对比的结果是identical或者metadata，[RenderParagraph]
  /// 则继续使用旧的span，避免重绘，因此，此处需要将旧span中的相关数据更新
  ///
  // @override
  // RenderComparison compareTo(InlineSpan other) {
  //   RenderComparison result = super.compareTo(other);
  //   if (other is BambooTextSpan &&
  //       (result == RenderComparison.identical ||
  //           result == RenderComparison.metadata)) {
  //     BambooTextSpanTapRecognizer tapRecognizer =
  //         recognizer as BambooTextSpanTapRecognizer;
  //     BambooTextSpanTapRecognizer otherTapRecognizer =
  //         other.recognizer as BambooTextSpanTapRecognizer;
  //     tapRecognizer.context = otherTapRecognizer._context;
  //   }
  //   return result;
  // }
}
