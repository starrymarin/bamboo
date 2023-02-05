import 'package:flutter/widgets.dart';
import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/text.dart';

class ParagraphNode extends BlockNode {
  ParagraphNode({
    required super.json,
  }) : super(displayBuilder: ParagraphWidgetBuilder());

  late int indent = json[JsonKey.indent] ?? 0;

  late TextAlign? align = () {
    switch (json[JsonKey.align]) {
      case "center":
        return TextAlign.center;
      case "right":
        return TextAlign.end;
    }
    return null;
  }();
}

class ParagraphWidgetBuilder extends WidgetDisplayBuilder<ParagraphNode> {
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
            textSpanBuilder: (TextBuilderContext textBuilderContext) {
              return TextSpan(
                children: node.children.whereType<SpanNode>().map((spanNode) {
                  return spanNode.buildSpan(textBuilderContext);
                }).toList(),
              );
            },
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
  Node transform(NodeJson nodeJson) => ParagraphNode(json: nodeJson);

  @override
  String type() => NodeType.paragraph;
}
