import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/text.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

abstract class NodeRender<T extends Node> {
  const NodeRender({required this.node});

  final T node;

  @override
  bool operator ==(Object other) {
    if (runtimeType != other.runtimeType) {
      return false;
    }

    return node == (other as NodeRender).node;
  }

  @override
  int get hashCode => node.hashCode;
}

abstract class WidgetRender<T extends Node> extends NodeRender<T> {
  WidgetRender({required super.node});

  Widget build(BuildContext context);
}

abstract class SpanRender<T extends Node> extends NodeRender<T> {
  SpanRender({required super.node});

  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext);

  void paint(
    RenderParagraph renderParagraph,
    PaintingContext context,
    Offset offset,
  ) {}
}
