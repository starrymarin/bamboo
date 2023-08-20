import 'package:flutter/widgets.dart';

import 'package:bamboo/text.dart';

import '../node.dart';
import '../rendering.dart';
import '../text.dart';
import 'json.dart';
import 'type.dart';

class ParagraphNode extends BlockNode {
  ParagraphNode({
    required super.json,
  });

  late final int indent = json[JsonKey.indent] ?? 0;

  late final TextAlign? align = () {
    switch (json[JsonKey.align]) {
      case "center":
        return TextAlign.center;
      case "right":
        return TextAlign.end;
    }
    return null;
  }();

  @override
  WidgetRendering<Node> createRendering() => ParagraphWidgetRendering(node: this);

  @override
  bool equals(Object other) {
    if (other is! ParagraphNode) {
      return false;
    }
    return indent == other.indent &&
        align == other.align &&
        deepChildrenEquals(other);
  }
}

class ParagraphWidgetRendering extends WidgetRendering<ParagraphNode> {
  ParagraphWidgetRendering({required super.node});

  final int _indentSize = 30;

  @override
  Widget build(BuildContext context) {
    if (node.children.isNotEmpty == true) {
      Node firstChild = node.children.first;
      if (firstChild is BlockNode) {
        var childrenWidgets = node.children
            .whereType<BlockNode>()
            .map((child) => Builder(builder: (context) => child.build(context)))
            .toList();
        return Column(
          children: childrenWidgets,
        );
      }

      if (firstChild is InlineNode || firstChild is TextNode) {
        final style = ParagraphNodeStyle.maybe(context);
        return Container(
          margin:
              style?.inlineTextMargin ?? const EdgeInsets.fromLTRB(0, 8, 0, 8),
          padding: EdgeInsets.fromLTRB(
              (_indentSize * node.indent).toDouble(), 0, 0, 0),
          child: BambooText(
            childNodes: node.children,
            textAlign: node.align,
          ),
        );
      }
    }
    return Container();
  }
}

class ParagraphNodeStyle extends InheritedWidget {
  const ParagraphNodeStyle({
    super.key,
    this.inlineTextMargin,
    required super.child,
  });

  final EdgeInsetsGeometry? inlineTextMargin;

  static ParagraphNodeStyle? maybe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ParagraphNodeStyle>();

  @override
  bool updateShouldNotify(covariant ParagraphNodeStyle oldWidget) {
    return inlineTextMargin != oldWidget.inlineTextMargin;
  }
}

class ParagraphNodePlugin extends NodePlugin {
  @override
  Node transform(NodeJson json) => ParagraphNode(json: json);

  @override
  String type() => NodeType.paragraph;
}
