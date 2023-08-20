import 'package:flutter/material.dart';

import 'package:bamboo/constants.dart';
import 'package:bamboo/node.dart';

import 'editor/document.dart';
import 'editor/editor.dart';

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
