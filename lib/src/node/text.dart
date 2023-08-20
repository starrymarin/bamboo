import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/text.dart';
import 'package:bamboo/utils.dart';

import 'internal/json.dart';
import 'node.dart';
import 'graphics.dart';

class TextNode extends Node implements SpanNode {
  TextNode({required super.json});

  @override
  SpanGraphics get graphics => super.graphics as SpanGraphics;

  late String text = json[JsonKey.text] ?? "";

  late Color? backgroundColor =
      json[JsonKey.backgroundColor]?.toString().toColor();

  late Color? color = json[JsonKey.color]?.toString().toColor();

  late double? fontSize = json[JsonKey.fontSize]?.toDouble();

  late bool? bold = json[JsonKey.bold];

  late bool? italic = json[JsonKey.italic];

  late bool? underlined = json[JsonKey.underlined];

  late bool? strikethrough = json[JsonKey.strikethrough];

  @override
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext) {
    return graphics.buildSpan(bambooTextBuildContext);
  }

  @override
  NodeGraphics<Node> createGraphics() => _TextSpanRender(node: this);

  @override
  void update() {
    parent?.update();
  }

  @override
  bool equals(Object other) {
    if (other is! TextNode) {
      return false;
    }
    return text == other.text &&
        backgroundColor == other.backgroundColor &&
        color == other.color &&
        fontSize == other.fontSize &&
        bold == other.bold &&
        italic == other.italic &&
        underlined == other.underlined &&
        strikethrough == other.strikethrough;
  }
}

class _TextSpanRender extends SpanGraphics<TextNode> {
  _TextSpanRender({required super.node});

  @override
  InlineSpan buildSpan(BambooTextBuildContext bambooTextBuildContext) {
    BambooConfiguration configuration = BambooConfiguration.of(
      bambooTextBuildContext.value!,
    );
    TextStyle style = TextStyle(
      backgroundColor: node.backgroundColor,
      color: node.color,
      fontSize: node.fontSize,
      decoration: TextDecoration.combine([
        node.underlined ?? false
            ? TextDecoration.underline
            : TextDecoration.none,
        node.strikethrough ?? false
            ? TextDecoration.lineThrough
            : TextDecoration.none,
      ]),
    );
    if (node.bold == true) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    if (node.italic == true) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    return BambooTextSpan(
      readOnly: configuration.readOnly,
      context: bambooTextBuildContext,
      text: node.text,
      style: style,
    );
  }
}
