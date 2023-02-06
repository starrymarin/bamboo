import 'package:bamboo/constants.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class InlineCodeNode extends InlineNode {
  InlineCodeNode({
    required super.json,
    required this.softWrap,
  }) : super(display: _InlineCodeDisplay());

  final bool softWrap;

  @override
  bool equals(Object other) {
    if (other is! InlineCodeNode) {
      return false;
    }
    return deepChildrenEquals(other);
  }
}

class _InlineCodeDisplay extends SpanDisplay<InlineCodeNode> {
  @override
  InlineSpan buildSpan(TextBuilderContext textBuilderContext) {
    if (node.softWrap) {
      return TextSpan(
        children: [
          const WidgetSpan(
            baseline: TextBaseline.alphabetic,
            alignment: PlaceholderAlignment.baseline,
            child: _InlineCodeEdgeLabel(isLeft: true),
          ),
          TextSpan(
            style: const TextStyle(
              fontFamily: monospace,
              color: Color(0xFF666666),
            ),
            children: node.children.whereType<SpanNode>().map((spanNode) {
              return spanNode.buildSpan(textBuilderContext);
            }).toList(),
          ),
          const WidgetSpan(
            baseline: TextBaseline.alphabetic,
            alignment: PlaceholderAlignment.baseline,
            child: _InlineCodeEdgeLabel(isLeft: false),
          ),
        ],
      );
    } else {
      return WidgetSpan(
        baseline: TextBaseline.alphabetic,
        alignment: PlaceholderAlignment.baseline,
        child: NodeWidget(
          node: node,
          widgetDisplay: _InlineCodeWidgetDisplay(node: node),
        ),
      );
    }
  }

  @override
  void paint(
    RenderParagraph renderParagraph,
    PaintingContext context,
    Offset offset,
  ) {
    super.paint(renderParagraph, context, offset);
  }
}

///
/// 为什么要先绘制一个完整的带边框圆角矩形，然后再用[ClipRect]裁剪一半？
/// 因为截止Flutter 3.7，绘制Container圆角边框，必须保证四边边框粗细颜色等一致
///
class _InlineCodeEdgeLabel extends StatelessWidget {
  const _InlineCodeEdgeLabel({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fill,
      child: ClipRect(
        child: Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          widthFactor: 0.5,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            margin: const EdgeInsets.fromLTRB(2, 4, 2, 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFDDDDDD),
                width: 0.5,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              color: const Color(0xFFF5F5F5),
            ),
            child: const Text(""),
          ),
        ),
      ),
    );
  }
}

class _InlineCodeWidgetDisplay extends WidgetDisplay<InlineCodeNode> {
  _InlineCodeWidgetDisplay({required InlineCodeNode node}) {
    super.node = node;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = BambooText(
      childNodes: node.children,
      maxLines: 1,
      style: const TextStyle(
        fontFamily: monospace,
        color: Color(0xFF666666),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 2, 6),
      // 本来left也应该是2，但不知为何TextField右边总是有大约2的padding
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: const Color(0xFFF5F5F5),
      ),
      child: IntrinsicWidth(
        child: content,
      ),
    );
  }
}

class InlineCodeNodePlugin extends NodePlugin {
  InlineCodeNodePlugin({this.softWrap = true});

  final bool softWrap;

  @override
  Node transform(NodeJson nodeJson) {
    return InlineCodeNode(
      json: nodeJson,
      softWrap: softWrap,
    );
  }

  @override
  String type() => NodeType.inlineCode;
}
