import 'package:bamboo/node/node.dart';
import 'package:bamboo/rendering/bamboo_text.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

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
    RenderParagraph renderParagraph,
    PaintingContext context,
    Offset offset,
  ) {}

  void afterPaint(
    RenderParagraph renderParagraph,
    PaintingContext context,
    Offset offset,
  ) {}
}
