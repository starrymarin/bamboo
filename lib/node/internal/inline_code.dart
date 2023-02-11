import 'dart:ui';

import 'package:bamboo/constants.dart';
import 'package:bamboo/node/internal/type.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/render.dart';
import 'package:bamboo/rendering/bamboo_text.dart';
import 'package:bamboo/utils/key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class InlineCodeNode extends InlineNode {
  InlineCodeNode({
    required super.json,
    required this.softWrap,
  });

  final bool softWrap;

  @override
  String get key => super.key ?? randomKey();

  @override
  SpanRender<Node> createRender() => _InlineCodeRender(node: this);

  @override
  bool equals(Object other) {
    if (other is! InlineCodeNode) {
      return false;
    }
    return deepChildrenEquals(other);
  }
}

class _InlineCodeRender extends SpanRender<InlineCodeNode> {
  _InlineCodeRender({required super.node});

  @override
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext) {
    if (node.softWrap) {
      return TextSpan(
        children: [
          const WidgetSpan(
            baseline: TextBaseline.alphabetic,
            alignment: PlaceholderAlignment.baseline,
            child: _InlineCodeEdgeLabel(isLeft: true),
          ),
          _InlineCodeTextSpan(
            key: node.key,
            style: const TextStyle(
              fontFamily: monospace,
              color: Color(0xFF666666),
            ),
            children: node.children.whereType<SpanNode>().map((spanNode) {
              return spanNode.buildSpan(bambooTextBuildContext);
            }).toList(),
          ),
          const WidgetSpan(
            baseline: TextBaseline.alphabetic,
            alignment: PlaceholderAlignment.baseline,
            child: _InlineCodeEdgeLabel(isLeft: false),
          ),
        ],
      );
    } else {
      return WidgetSpan(
        baseline: TextBaseline.alphabetic,
        alignment: PlaceholderAlignment.baseline,
        child: NodeWidget(
          node: node,
          widgetRender: _InlineCodeWidgetRender(node: node),
        ),
      );
    }
  }

  @override
  void paint(
    RenderParagraph renderParagraph,
    PaintingContext context,
    Offset offset,
  ) {
    super.paint(renderParagraph, context, offset);
    int preLength = 0;
    _InlineCodeTextSpan? textSpan;
    renderParagraph.text.visitChildren((span) {
      if (span is _InlineCodeTextSpan && span.key == node.key) {
        textSpan = span;
        return false;
      }
      if (span is TextSpan) {
        preLength += span.text?.length ?? 0;
      } else if (span is PlaceholderSpan) {
        preLength += 1;
      } else {
        throw Exception("unknown span length");
      }
      return true;
    });

    if (textSpan == null) {
      return;
    }

    int length = 0;
    textSpan?.visitChildren((span) {
      if (span is TextSpan) {
        length += span.text?.length ?? 0;
      } else if (span is PlaceholderSpan) {
        length += 1;
      } else {
        throw Exception("unknown span length");
      }
      return true;
    });
    TextSelection selection = TextSelection(
      baseOffset: preLength,
      extentOffset: preLength + length,
    );

    List<TextBox> boxes = renderParagraph.getBoxesForSelection(selection,
        boxHeightStyle: BoxHeightStyle.strut);
    for (TextBox box in boxes) {
      const inlineVerticalPadding = 2;
      const lineWidth = 0.5;

      Rect rect = box.toRect().shift(offset);
      rect = Rect.fromLTRB(
        rect.left,
        rect.top - inlineVerticalPadding,
        rect.right,
        rect.bottom + inlineVerticalPadding,
      );

      Paint backgroundPaint = Paint()
        ..color = const Color(0xFFF5F5F5)
        ..style = PaintingStyle.fill;
      context.canvas.drawRect(
        rect,
        backgroundPaint,
      );
      context.canvas.save();

      Paint strokePaint = Paint()
        ..color = const Color(0xFFDDDDDD)
        ..style = PaintingStyle.fill
        ..strokeWidth = lineWidth;
      context.canvas.drawLine(
          Offset(rect.left - lineWidth, rect.top - lineWidth),
          Offset(rect.right + lineWidth, rect.top - lineWidth),
          strokePaint,
      );
      context.canvas.drawLine(
        Offset(rect.left - lineWidth, rect.bottom + lineWidth),
        Offset(rect.right + lineWidth, rect.bottom + lineWidth),
        strokePaint,
      );
      context.canvas.restore();
    }
  }
}

class _InlineCodeTextSpan extends TextSpan {
  const _InlineCodeTextSpan({required this.key, super.style, super.children});

  final String key;

  @override
  bool visitChildren(InlineSpanVisitor visitor) {
    if (!visitor(this)) {
      return false;
    }
    if (children != null) {
      for (final InlineSpan child in children!) {
        if (!child.visitChildren(visitor)) {
          return false;
        }
      }
    }
    return true;
  }
}

///
/// 为什么要先绘制一个完整的带边框圆角矩形，然后再用[ClipRect]裁剪一半？
/// 因为截止Flutter 3.7，绘制Container圆角边框，必须保证四边边框粗细颜色等一致
///
class _InlineCodeEdgeLabel extends StatelessWidget {
  const _InlineCodeEdgeLabel({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fill,
      child: ClipRect(
        child: Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          widthFactor: 0.5,
          child: Container(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
            margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFDDDDDD),
                width: 0.5,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              color: const Color(0xFFF5F5F5),
            ),
            child: const Text(""),
          ),
        ),
      ),
    );
  }
}

class _InlineCodeWidgetRender extends WidgetRender<InlineCodeNode> {
  _InlineCodeWidgetRender({required super.node});

  @override
  Widget build(BuildContext context) {
    Widget content = BambooText(
      childNodes: node.children,
      maxLines: 1,
      style: const TextStyle(
        fontFamily: monospace,
        color: Color(0xFF666666),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: const Color(0xFFF5F5F5),
      ),
      child: IntrinsicWidth(
        child: content,
      ),
    );
  }
}

class InlineCodeNodePlugin extends NodePlugin {
  InlineCodeNodePlugin({this.softWrap = true});

  final bool softWrap;

  @override
  Node transform(NodeJson json) {
    return InlineCodeNode(
      json: json,
      softWrap: softWrap,
    );
  }

  @override
  String type() => NodeType.inlineCode;
}
