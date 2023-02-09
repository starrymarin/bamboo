import 'package:bamboo/constants.dart';
import 'package:bamboo/node/internal/block_quote.dart';
import 'package:bamboo/node/internal/inline_code.dart';
import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/node/internal/paragraph.dart';
import 'package:bamboo/node/internal/table.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/text.dart';
import 'package:bamboo/widgets/keep_alive.dart';
import 'package:bamboo/widgets/scroll.dart';
import 'package:flutter/material.dart';

class Bamboo extends StatefulWidget {
  Bamboo({
    super.key,
    this.document,
    List<NodePlugin>? nodePlugins,
    this.readOnly = true,
  }) {
    this.nodePlugins
      ..[NodeType.paragraph] = ParagraphNodePlugin()
      ..[NodeType.inlineCode] = InlineCodeNodePlugin()
      ..[NodeType.blockQuote] = BlockQuoteNodePlugin()
      ..[NodeType.table] = TableNodePlugin()
      ..[NodeType.tableRow] = TableRowNodePlugin()
      ..[NodeType.tableCell] = TableCellNodePlugin();
    nodePlugins?.forEach((plugin) {
      this.nodePlugins[plugin.type()] = plugin;
    });
  }

  final List<NodeJson>? document;

  final Map<String, NodePlugin> nodePlugins = {};

  final bool readOnly;

  @override
  State<StatefulWidget> createState() => _BambooState();
}

class _BambooState extends State<Bamboo> {
  @override
  Widget build(BuildContext context) {
    return BambooConfiguration(
      readOnly: widget.readOnly,
      child: _Editor(
        document: widget.document,
        nodePlugins: widget.nodePlugins,
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  _Editor({
    this.document,
    this.nodePlugins = const {},
  }) {
    Node? transform(NodeJson nodeJson, List<Node> nodes) {
      if (nodeJson.isText()) {
        TextNode textNode = TextNode(json: nodeJson);
        nodes.add(textNode);
        return textNode;
      } else {
        NodePlugin? plugin = nodePlugins[nodeJson.type()];
        if (plugin != null) {
          Node node = plugin.transform(nodeJson);
          nodes.add(node);
          List<dynamic>? childrenJson = nodeJson[JsonKey.children];
          childrenJson?.forEach((childNodeJson) {
            Node? childNode = transform(childNodeJson, node.children);
            childNode?.parent = node;
          });
          return node;
        }
      }
      return null;
    }

    document?.forEach((nodeJson) {
      transform(nodeJson, nodes);
    });
  }

  final List<NodeJson>? document;

  final Map<String, NodePlugin> nodePlugins;

  final List<Node> nodes = [];

  @override
  Widget build(BuildContext context) {
    ScrollController scrollController = ScrollController();
    List<BlockNode> blockNodes = nodes.whereType<BlockNode>().toList();

    Widget content;
    if (useListView) {
      content = ListView.builder(
        controller: scrollController,
        itemBuilder: (BuildContext context, int index) {
          return KeepAliveWrapper(
            child: blockNodes[index].build(context),
          );
        },
        itemCount: blockNodes.length,
      );
    } else {
      content = SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: blockNodes.map((node) {
            return Builder(
              builder: (context) {
                return node.build(context);
              },
            );
          }).toList(),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: BambooScrollBehavior(),
      child: Scrollbar(
        controller: scrollController,
        child: Center(
          child: Container(
            alignment: Alignment.topCenter,
            constraints: const BoxConstraints(
              maxWidth: editorWidth + 8 + 8,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: defaultFontSize,
                  color: Color(0xFF333333),
                  height: 1.6,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BambooConfiguration extends InheritedWidget {
  const BambooConfiguration({
    super.key,
    required super.child,
    required this.readOnly,
  });

  final bool readOnly;

  static BambooConfiguration of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BambooConfiguration>()!;
  }

  @override
  bool updateShouldNotify(covariant BambooConfiguration oldWidget) {
    return readOnly == oldWidget.readOnly;
  }

}
