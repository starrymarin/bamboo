import 'package:bamboo/constants.dart';
import 'package:bamboo/node/internal/block_quote.dart';
import 'package:bamboo/node/internal/inline_code.dart';
import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/node/internal/paragraph.dart';
import 'package:bamboo/node/internal/table.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/text.dart';
import 'package:bamboo/editor/editor.dart';
import 'package:bamboo/widgets/keep_alive.dart';
import 'package:bamboo/widgets/scroll.dart';
import 'package:flutter/material.dart';

class Bamboo extends StatefulWidget {
  Bamboo({
    super.key,
    this.document,
    List<NodePlugin>? nodePlugins,
    this.readOnly = true,
    this.bambooTheme,
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

  final BambooTheme? bambooTheme;

  @override
  State<StatefulWidget> createState() => _BambooState();
}

class _BambooState extends State<Bamboo> {
  BambooTheme checkBambooTheme(BuildContext context) {
    ThemeData appTheme = Theme.of(context);
    BambooTheme checkTheme = widget.bambooTheme ?? BambooTheme();
    if (checkTheme._cursorColor == null) {
      checkTheme =
          checkTheme.copyWith(cursorColor: appTheme.colorScheme.primary);
    }
    return checkTheme;
  }

  @override
  Widget build(BuildContext context) {
    BambooTheme theme = checkBambooTheme(context);
    return BambooConfiguration(
      readOnly: widget.readOnly,
      theme: theme,
      child: Editor(
        child: Document(
          document: widget.document,
          nodePlugins: widget.nodePlugins,
        ),
      ),
    );
  }
}

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
    return ScrollConfiguration(
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
    );
  }
}

class BambooTheme {
  BambooTheme({
    this.textStyle = const TextStyle(
        fontSize: defaultFontSize, color: Color(0xFF333333), height: 1.6),
    Color? cursorColor,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius = const Radius.circular(2.0),
    this.cursorOffset = Offset.zero,
  }) : _cursorColor = cursorColor;

  final TextStyle textStyle;

  /// 在[_BambooState]中会检查这个值，如果为空则赋默认值，所以取的时候不会为空
  final Color? _cursorColor;

  Color get cursorColor => _cursorColor!;

  final double cursorWidth;
  final double? cursorHeight;
  final Radius cursorRadius;
  final Offset cursorOffset;

  BambooTheme copyWith({
    TextStyle? textStyle,
    Color? cursorColor,
    Color? backgroundCursorColor,
    double? cursorWidth,
    double? cursorHeight,
    Radius? cursorRadius,
    Offset? cursorOffset,
  }) {
    return BambooTheme(
      textStyle: textStyle ?? this.textStyle,
      cursorColor: cursorColor ?? this.cursorColor,
      cursorWidth: cursorWidth ?? this.cursorWidth,
      cursorHeight: cursorHeight ?? this.cursorHeight,
      cursorRadius: cursorRadius ?? this.cursorRadius,
      cursorOffset: cursorOffset ?? this.cursorOffset,
    );
  }

  static BambooTheme of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BambooConfiguration>()!
        .theme;
  }
}

class BambooConfiguration extends InheritedWidget {
  const BambooConfiguration({
    super.key,
    required super.child,
    required this.readOnly,
    required this.theme,
  });

  final bool readOnly;

  final BambooTheme theme;

  static BambooConfiguration of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BambooConfiguration>()!;
  }

  @override
  bool updateShouldNotify(covariant BambooConfiguration oldWidget) {
    return readOnly == oldWidget.readOnly;
  }
}
