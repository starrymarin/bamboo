import 'package:bamboo/node/render.dart';
import 'package:bamboo/utils/collection.dart';
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
    required this.render,
  }) {
    render.node = this;
  }

  final NodeJson json;

  final NodeRender render;

  Node? parent;

  late String? key = json[JsonKey.key];

  final List<Node> children = [];

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
  ElementNode({
    required super.json,
    required super.render,
  });
}

abstract class BlockNode extends ElementNode implements WidgetNode {
  BlockNode({
    required super.json,
    required WidgetRender super.render,
  });

  @override
  WidgetRender get render => super.render as WidgetRender;

  @override
  Widget build(BuildContext context) {
    return NodeWidget(node: this, widgetRender: render);
  }

  @override
  void update() {
    notifyListeners();
  }
}

abstract class InlineNode extends ElementNode implements SpanNode {
  InlineNode({
    required super.json,
    required SpanRender super.render,
  });

  @override
  SpanRender get render => super.render as SpanRender;

  @override
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext) {
    return render.buildSpan(bambooTextBuildContext);
  }

  @override
  void update() {
    parent?.update();
  }
}

///
/// [WidgetNode]会被对应到[NodeWidget]，这个widget会使用[WidgetRender]构建真正展示
/// 的Widget，而[NodeWidget]的作用是监听[Node.update]，以此重新构建widget
///
class NodeWidget extends StatefulWidget {
  const NodeWidget({
    super.key,
    required this.node,
    required this.widgetRender,
  });

  final Node node;

  final WidgetRender widgetRender;

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
    return widget.widgetRender.build(context);
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
