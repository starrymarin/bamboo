
import 'package:flutter/widgets.dart';

import '../node.dart';
import '../rendering.dart';
import 'paragraph.dart';
import 'type.dart';

///
/// 目前认为block-quote里面只有blockNode，如果出现非BlockNode将会被忽略
///
class BlockQuoteNode extends BlockNode {
  BlockQuoteNode({required super.json});

  @override
  WidgetRendering<Node> createRendering() => _BlockQuoteWidgetRendering(node: this);

  @override
  bool equals(Object other) {
    if (other is! BlockQuoteNode) {
      return false;
    }
    return deepChildrenEquals(other);
  }
}

class _BlockQuoteWidgetRendering extends WidgetRendering<BlockQuoteNode> {
  _BlockQuoteWidgetRendering({required super.node});

  @override
  Widget build(BuildContext context) {
    List<Widget> childrenWidgets = [];
    for (int index = 0; index < node.children.length; index++) {
      Node child = node.children[index];
      if (child is! BlockNode) {
        continue;
      }
      childrenWidgets.add(
        ParagraphNodeStyle(
          inlineTextMargin: EdgeInsets.fromLTRB(
              0, 0, 0, index < node.children.length - 1 ? 8 : 0),
          child: Builder(builder: (context) => child.build(context)),
        ),
      );
    }

    return DefaultTextStyle.merge(
      style: const TextStyle(color: Color(0xFF999999)),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFEEEEEE), width: 4),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 5, 0, 5),
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Column(children: childrenWidgets),
      ),
    );
  }
}

class BlockQuoteNodePlugin extends NodePlugin {
  @override
  Node transform(NodeJson json) => BlockQuoteNode(json: json);

  @override
  String type() => NodeType.blockQuote;
}
