import 'package:bamboo/constants.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/text.dart';
import 'package:flutter/widgets.dart';

class InlineCodeNode extends InlineNode {
  InlineCodeNode({
    required super.json,
    required this.softWrap,
  }) : super(displayBuilder: InlineCodeSpanBuilder());

  final bool softWrap;
}

class InlineCodeSpanBuilder extends SpanDisplayBuilder<InlineCodeNode> {
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
          widgetBuilder: InlineCodeWidgetBuilder(node: node),
        ),
      );
    }
  }
}

class _InlineCodeEdgeLabel extends StatelessWidget {
  const _InlineCodeEdgeLabel({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fill,
      child: ClipRect(
        child: Align(
          alignment: isLeft ? Alignment.topLeft : Alignment.topRight,
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

class InlineCodeWidgetBuilder extends WidgetDisplayBuilder<InlineCodeNode> {
  InlineCodeWidgetBuilder({required InlineCodeNode node}) {
    super.node = node;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = BambooText(
      textSpanBuilder: (textBuilderContext) {
        return TextSpan(
          children: node.children.whereType<SpanNode>().map((spanNode) {
            return spanNode.buildSpan(textBuilderContext);
          }).toList(),
        );
      },
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
