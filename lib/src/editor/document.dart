import 'package:bamboo/bamboo.dart';
import 'package:bamboo/constants.dart';
import 'package:bamboo/node.dart';
import 'package:bamboo/selection.dart';
import 'package:bamboo/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/widgets/keep_alive.dart';

class Document extends StatelessWidget {
  Document({
    super.key,
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
          node.path
              ..clear()
              ..addAll(node.parent?.path ?? [])
              ..add(nodes.length);
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

    BambooTheme theme = BambooTheme.of(context);

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
    return SelectionArea(
      child: SelectionContainer(
        delegate: BambooSelectionContainerDelegate(),
        child: ScrollConfiguration(
          behavior: BambooScrollBehavior(),
          child: Scrollbar(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: DefaultTextStyle(
                style: theme.textStyle,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DocumentProxy extends SingleChildRenderObjectWidget {
  const DocumentProxy({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDocumentProxy();
  }
}

/// 这个类的目的是用来判断[RenderEditor]中的哪一个child是用来渲染document的
class RenderDocumentProxy extends RenderProxyBox {}

class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({
    Key? key,
    this.keepAlive = true,
    required this.child,
  }) : super(key: key);
  final bool keepAlive;
  final Widget child;

  @override
  State createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  void didUpdateWidget(covariant KeepAliveWrapper oldWidget) {
    if(oldWidget.keepAlive != widget.keepAlive) {
      // keepAlive 状态需要更新，实现在 AutomaticKeepAliveClientMixin 中
      updateKeepAlive();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}