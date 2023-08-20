import 'package:flutter/widgets.dart';

import 'package:bamboo/text.dart';
import 'package:bamboo/utils.dart';

import 'internal/json.dart';
import 'graphics.dart';

typedef NodeJson = Map<String, dynamic>;

extension NodeJsonExtension on NodeJson {
  bool isText() => containsKey(JsonKey.text);

  String type() => this[JsonKey.type];
}

abstract class Node with ChangeNotifier {
  Node({required this.json});

  final NodeJson json;

  Node? parent;

  late String? key = json[JsonKey.key];

  final List<Node> children = [];

  late final NodeGraphics graphics = () {
    return createGraphics();
  }();

  NodeGraphics createGraphics();

  void update();

  bool equals(Object other);

  bool deepChildrenEquals(Node other) {
    return deepEquals(children, other.children);
  }
}

abstract class WidgetNode {
  Widget build(BuildContext context);
}

abstract class SpanNode {
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext);
}

abstract class ElementNode extends Node {
  ElementNode({required super.json});
}

abstract class BlockNode extends ElementNode implements WidgetNode {
  BlockNode({required super.json});

  @override
  WidgetGraphics get graphics => super.graphics as WidgetGraphics;

  @override
  WidgetGraphics createGraphics();

  @override
  Widget build(BuildContext context) {
    return NodeWidget(node: this, widgetGraphics: graphics);
  }

  @override
  void update() {
    notifyListeners();
  }
}

abstract class InlineNode extends ElementNode implements SpanNode {
  InlineNode({required super.json});

  @override
  SpanGraphics get graphics => super.graphics as SpanGraphics;

  @override
  SpanGraphics createGraphics();

  @override
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext) {
    return graphics.buildSpan(bambooTextBuildContext);
  }

  @override
  void update() {
    parent?.update();
  }
}

///
/// [WidgetNode]会被对应到[NodeWidget]，这个widget会使用[WidgetGraphics]构建真正展示
/// 的Widget，而[NodeWidget]的作用是监听[Node.update]，以此重新构建widget
///
class NodeWidget extends StatefulWidget {
  const NodeWidget({
    super.key,
    required this.node,
    required this.widgetGraphics,
  });

  final Node node;

  final WidgetGraphics widgetGraphics;

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
    return widget.widgetGraphics.build(context);
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

abstract class NodePlugin {
  String type();

  Node transform(NodeJson json);
}
