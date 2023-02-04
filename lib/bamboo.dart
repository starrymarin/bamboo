import 'dart:io';

import 'package:bamboo/constants.dart';
import 'package:flutter/widgets.dart';
import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/node/internal/paragraph.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/text.dart';

class Bamboo extends StatefulWidget {
  Bamboo({
    super.key,
    this.document,
    List<NodePlugin>? nodePlugins,
  }) {
    this.nodePlugins..[NodeType.paragraph] = ParagraphNodePlugin();
    nodePlugins?.forEach((plugin) {
      this.nodePlugins[plugin.type()] = plugin;
    });
  }

  final List<NodeJson>? document;

  final Map<String, NodePlugin> nodePlugins = {};

  @override
  State<StatefulWidget> createState() => _BambooState();
}

class _BambooState extends State<Bamboo> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Underlay(),
        _Editor(
          document: widget.document,
          nodePlugins: widget.nodePlugins,
        ),
      ],
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
    return ScrollConfiguration(
      behavior: _BambooScrollBehavior(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: BambooTextThemeController(
            textStyle: const TextStyle(
              fontSize: defaultFontSize,
              color: Color(0xFF333333),
              height: 1.6,
            ),
            child: Column(
              children: nodes.whereType<BlockNode>().map((node) {
                return Builder(builder: (context) {
                  return node.build(context);
                });
              }).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _BambooScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (Platform.isAndroid) {
      return StretchingOverscrollIndicator(
        axisDirection: details.direction,
        child: child,
      );
    }
    return super.buildOverscrollIndicator(context, child, details);
  }
}

class Underlay extends StatefulWidget {
  const Underlay({super.key});

  @override
  State<StatefulWidget> createState() => UnderlayState();
}

class UnderlayState extends State<Underlay> {
  @override
  Widget build(BuildContext context) {
    return Stack();
  }
}
