import 'package:flutter/widgets.dart';
import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/node/text.dart';

typedef NodeJson = Map<String, dynamic>;

extension NodeJsonExtension on NodeJson {
  bool isText() => containsKey(JsonKey.text);

  String type() => this[JsonKey.type];
}

abstract class Node with ChangeNotifier {
  Node({
    required this.json,
    required this.displayBuilder,
  }) {
    displayBuilder.node = this;
  }

  final NodeJson json;

  final DisplayBuilder displayBuilder;

  Node? parent;

  final List<Node> children = [];

  void update();
}

abstract class WidgetNode {
  Widget build(BuildContext context);
}

abstract class SpanNode {
  InlineSpan buildSpan(TextKey textKey);
}

abstract class ElementNode extends Node {
  ElementNode({
    required super.json,
    required super.displayBuilder,
  });
}

class BlockNode extends ElementNode implements WidgetNode {
  BlockNode({
    required super.json,
    required WidgetDisplayBuilder super.displayBuilder,
  });

  @override
  WidgetDisplayBuilder get displayBuilder =>
      super.displayBuilder as WidgetDisplayBuilder;

  @override
  Widget build(BuildContext context) {
    return NodeWidget(node: this, widgetBuilder: displayBuilder);
  }

  @override
  void update() {
    notifyListeners();
  }
}

class InlineNode extends ElementNode implements SpanNode {
  InlineNode({
    required super.json,
    required SpanDisplayBuilder super.displayBuilder,
  });

  @override
  SpanDisplayBuilder get displayBuilder =>
      super.displayBuilder as SpanDisplayBuilder;

  @override
  InlineSpan buildSpan(TextKey textKey) {
    return displayBuilder.buildSpan(textKey);
  }

  @override
  void update() {
    parent?.update();
  }
}

///
/// [WidgetNode]会被对应到[NodeWidget]，这个widget会使用[WidgetDisplayBuilder]构建真正展示
/// 的Widget，而[NodeWidget]的作用是监听[Node.update]，以此重新构建widget
///
class NodeWidget extends StatefulWidget {
  const NodeWidget({
    super.key,
    required this.node,
    required this.widgetBuilder,
  });

  final Node node;

  final WidgetDisplayBuilder widgetBuilder;

  @override
  State<StatefulWidget> createState() => NodeWidgetState();
}

class NodeWidgetState extends State<NodeWidget> {
  @override
  void initState() {
    super.initState();
    widget.node.addListener(_update);
  }

  @override
  Widget build(BuildContext context) {
    return widget.widgetBuilder.build(context);
  }

  void _update() {
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    widget.node.removeListener(_update);
  }
}

abstract class DisplayBuilder<T extends Node> {
  late T node;
}

abstract class WidgetDisplayBuilder<T extends Node> extends DisplayBuilder<T> {
  Widget build(BuildContext context);
}

abstract class SpanDisplayBuilder<T extends Node> extends DisplayBuilder<T> {
  InlineSpan buildSpan(TextKey textKey);
}

abstract class NodePlugin {
  String type();

  Node transform(NodeJson nodeJson);
}
