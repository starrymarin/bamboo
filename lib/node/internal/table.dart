import 'package:bamboo/bamboo.dart';
import 'package:bamboo/constants.dart';
import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/rendering.dart';
import 'package:bamboo/utils/collection.dart';
import 'package:bamboo/utils/color.dart';
import 'package:bamboo/widgets/scroll.dart';
import 'package:flutter/material.dart';

class TableNode extends BlockNode {
  TableNode({required super.json});

  late final List<TableRowNode> rows = () {
    return children.whereType<TableRowNode>().map((rowNode) {
      rowNode.tableNode = this;
      return rowNode;
    }).toList();
  }();

  late final List<NodeJson> _columns = () {
    return (json[JsonKey.columns] as List<dynamic>)
        .map((element) => element as NodeJson)
        .toList();
  }();

  late final List<double> columnsWidth = () {
    List<double> widthList = [];
    if (_columns.isNotEmpty) {
      widthList = _columns
          .map((column) => (column[JsonKey.width] as num).toDouble())
          .toList();
    } else {
      int columnsCount = 0;
      if (rows.isNotEmpty) {
        columnsCount = rows.first.cells.length;
      }
      double columnWidth = editorWidth / columnsCount;
      widthList = List.filled(columnsCount, columnWidth);
    }
    return widthList;
  }();

  @override
  WidgetRendering<Node> createRender() => _TableWidgetRendering(node: this);

  @override
  bool equals(Object other) {
    if (other is! TableNode) {
      return false;
    }
    return deepEquals(columnsWidth, other.columnsWidth)
        && deepChildrenEquals(other);
  }
}

class _TableWidgetRendering extends WidgetRendering<TableNode> {
  _TableWidgetRendering({required super.node});

  @override
  Widget build(BuildContext context) {
    List<Widget> rowWidgets = [];
    for (int index = 0; index < node.rows.length; index++) {
      final row = node.rows[index];
      rowWidgets.add(
        IntrinsicHeight(
          child: Builder(builder: (context) {
            return row.build(context);
          }),
        ),
      );
    }
    ScrollController scrollController = ScrollController();
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 30, 0, 0),
        child: ScrollConfiguration(
          behavior: BambooScrollBehavior(),
          child: Scrollbar(
            controller: scrollController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: scrollController,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(width: 1, color: Color(0xFFDDDDDD)),
                    bottom: BorderSide(width: 1, color: Color(0xFFDDDDDD)),
                  ),
                ),
                child: Column(children: rowWidgets),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TableNodePlugin extends NodePlugin {
  @override
  Node transform(NodeJson json) => TableNode(json: json);

  @override
  String type() => NodeType.table;
}

class TableRowNode extends BlockNode {
  TableRowNode({required super.json});

  late TableNode tableNode;

  late final List<TableCellNode> cells = () {
    return children.whereType<TableCellNode>().toList();
  }();

  @override
  WidgetRendering<Node> createRender() => _TableRowWidgetRendering(node: this);

  @override
  bool equals(Object other) {
    if (other is! TableRowNode) {
      return false;
    }
    return deepEquals(cells, other.cells);
  }
}

class _TableRowWidgetRendering extends WidgetRendering<TableRowNode> {
  _TableRowWidgetRendering({required super.node});

  @override
  Widget build(BuildContext context) {
    List<Widget> cellWidgets = [];
    for (int cellIndex = 0; cellIndex < node.cells.length; cellIndex++) {
      final cell = node.cells[cellIndex];
      cellWidgets.add(
        Builder(builder: (context) {
          return Container(
            width: node.tableNode.columnsWidth[cellIndex],
            constraints: BoxConstraints(
              minHeight: (node.json[JsonKey.height] as num?)?.toDouble() ?? 41,
            ),
            decoration: BoxDecoration(
              border: const Border(
                top: BorderSide(color: Color(0xFFDDDDDD), width: 1),
                right: BorderSide(color: Color(0xFFDDDDDD), width: 1),
              ),
              color: (node.json[JsonKey.header] as bool?) == true
                  ? const Color(0xFFF3F3F3)
                  : null,
            ),
            child: cell.build(context),
          );
        }),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cellWidgets,
    );
  }
}

class TableRowNodePlugin extends NodePlugin {
  @override
  Node transform(NodeJson json) => TableRowNode(json: json);

  @override
  String type() => NodeType.tableRow;
}

class TableCellNode extends BlockNode {
  TableCellNode({required super.json});

  @override
  WidgetRendering<Node> createRender() => _TableCellWidgetRendering(node: this);

  @override
  bool equals(Object other) {
    if (other is! TableCellNode) {
      return false;
    }
    return deepChildrenEquals(other);
  }
}

class _TableCellWidgetRendering extends WidgetRendering<TableCellNode> {
  _TableCellWidgetRendering({required super.node});

  @override
  Widget build(BuildContext context) {
    List<Widget> childrenWidgets = [];
    for (var child in node.children) {
      if (child is BlockNode) {
        childrenWidgets.add(Builder(builder: (context) {
          return child.build(context);
        }));
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: (node.json[JsonKey.tableCellBackgroundColor] as String?).toColor(),
      child: IntrinsicHeight(
        child: Column(
          children: childrenWidgets,
        ),
      ),
    );
  }
}

class TableCellNodePlugin extends NodePlugin {
  @override
  Node transform(NodeJson json) => TableCellNode(json: json);

  @override
  String type() => NodeType.tableCell;
}
