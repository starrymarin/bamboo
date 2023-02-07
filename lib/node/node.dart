import 'package:bamboo/utils/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/node/text.dart';
import 'package:collection/collection.dart';

typedef NodeJson = Map<String, dynamic>;

extension NodeJsonExtension on NodeJson {
  bool isText() => containsKey(JsonKey.text);

  String type() => this[JsonKey.type];
}

abstract class Node with ChangeNotifier {
  Node({
    required this.json,
    required this.display,
  }) {
    display.node = this;
  }

  final NodeJson json;

  final NodeDisplay display;

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
    required super.display,
  });
}

abstract class BlockNode extends ElementNode implements WidgetNode {
  BlockNode({
    required super.json,
    required WidgetDisplay super.display,
  });

  @override
  WidgetDisplay get display => super.display as WidgetDisplay;

  @override
  Widget build(BuildContext context) {
    return NodeWidget(node: this, widgetDisplay: display);
  }

  @override
  void update() {
    notifyListeners();
  }
}

abstract class InlineNode extends ElementNode implements SpanNode {
  InlineNode({
    required super.json,
    required SpanDisplay super.display,
  });

  @override
  SpanDisplay get display => super.display as SpanDisplay;

  @override
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext) {
    return display.buildSpan(bambooTextBuildContext);
  }

  @override
  void update() {
    parent?.update();
  }
}

///
/// [WidgetNode]会被对应到[NodeWidget]，这个widget会使用[WidgetDisplay]构建真正展示
/// 的Widget，而[NodeWidget]的作用是监听[Node.update]，以此重新构建widget
///
class NodeWidget extends StatefulWidget {
  const NodeWidget({
    super.key,
    required this.node,
    required this.widgetDisplay,
  });

  final Node node;

  final WidgetDisplay widgetDisplay;

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
    return widget.widgetDisplay.build(context);
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

abstract class NodeDisplay<T extends Node> {
  late T node;

  @override
  bool operator ==(Object other) {
    if (runtimeType != other.runtimeType) {
      return false;
    }

    return node == (other as NodeDisplay).node;
  }

  @override
  int get hashCode => node.hashCode;
}

abstract class WidgetDisplay<T extends Node> extends NodeDisplay<T> {
  Widget build(BuildContext context);
}

abstract class SpanDisplay<T extends Node> extends NodeDisplay<T> {
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext);

  void paint(
    RenderParagraph renderParagraph,
    PaintingContext context,
    Offset offset,
  ) {}
}

abstract class NodePlugin {
  String type();

  Node transform(NodeJson json);
}
