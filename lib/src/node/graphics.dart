import 'package:flutter/widgets.dart';

import 'package:bamboo/text.dart';

import 'node.dart';

abstract class NodeGraphics<T extends Node> {
  const NodeGraphics({required this.node});

  final T node;

  @override
  bool operator ==(Object other) {
    if (runtimeType != other.runtimeType) {
      return false;
    }

    return node == (other as NodeGraphics).node;
  }

  @override
  int get hashCode => node.hashCode;
}

abstract class WidgetGraphics<T extends Node> extends NodeGraphics<T> {
  WidgetGraphics({required super.node});

  Widget build(BuildContext context);
}

abstract class SpanGraphics<T extends Node> extends NodeGraphics<T> {
  SpanGraphics({required super.node});

  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext);

  void beforePaint(
    BambooTextParagraph paragraph,
    PaintingContext context,
    Offset offset,
  ) {}

  void afterPaint(
    BambooTextParagraph paragraph,
    PaintingContext context,
    Offset offset,
  ) {}
}
