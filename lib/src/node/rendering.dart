import 'package:flutter/widgets.dart';

import 'package:bamboo/text.dart';

import 'node.dart';

abstract class NodeRendering<T extends Node> {
  const NodeRendering({required this.node});

  final T node;

  @override
  bool operator ==(Object other) {
    if (runtimeType != other.runtimeType) {
      return false;
    }

    return node == (other as NodeRendering).node;
  }

  @override
  int get hashCode => node.hashCode;
}

abstract class WidgetRendering<T extends Node> extends NodeRendering<T> {
  WidgetRendering({required super.node});

  Widget build(BuildContext context);
}

abstract class SpanRendering<T extends Node> extends NodeRendering<T> {
  SpanRendering({required super.node});

  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext);

  void beforePaint(
    RenderBambooParagraph paragraph,
    PaintingContext context,
    Offset offset,
  ) {}

  void afterPaint(
    RenderBambooParagraph paragraph,
    PaintingContext context,
    Offset offset,
  ) {}
}
