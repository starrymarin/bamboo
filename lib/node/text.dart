import 'dart:ui' as ui show TextHeightBehavior;

import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/utils/color.dart';
import 'package:bamboo/node/node.dart';
import 'package:flutter/widgets.dart';

class TextNode extends Node implements SpanNode {
  TextNode({required super.json}) : super(displayBuilder: _TextSpanBuilder());

  @override
  SpanDisplayBuilder get displayBuilder =>
      super.displayBuilder as SpanDisplayBuilder;

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
  InlineSpan buildSpan(TextBuilderContext textBuilderContext) {
    return displayBuilder.buildSpan(textBuilderContext);
  }

  @override
  void update() {
    parent?.update();
  }
}

class _TextSpanBuilder extends SpanDisplayBuilder<TextNode> {
  @override
  InlineSpan buildSpan(TextBuilderContext textBuilderContext) {
    TextStyle textStyle =
        BambooTextThemeController.style(textBuilderContext.value);

    TextStyle newStyle = TextStyle(
      backgroundColor: node.backgroundColor,
      color: node.color,
      fontSize: node.fontSize,
      fontWeight: node.bold ?? false ? FontWeight.bold : textStyle.fontWeight,
      fontStyle: node.italic ?? false ? FontStyle.italic : textStyle.fontStyle,
      decoration: TextDecoration.combine([
        node.underlined ?? false
            ? TextDecoration.underline
            : TextDecoration.none,
        node.strikethrough ?? false
            ? TextDecoration.lineThrough
            : TextDecoration.none,
      ]),
    );

    TextStyle style = textStyle.merge(newStyle);
    return InheritedStyleTextSpan(
      text: node.text,
      style: style,
    );
  }
}

///
/// 使用[Builder]构建一个[Text]，并将Builder context传输给[SpanNode.buildSpan]，这意
/// 味着[SpanNode]必须被包含在[BambooText]中，而不能是[Text],[RichText]等
///
class BambooText extends StatefulWidget {
  const BambooText({
    super.key,
    required this.textSpanBuilder,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final InlineSpan Function(TextBuilderContext textBuilderContext)
      textSpanBuilder;

  final TextStyle? style;

  final StrutStyle? strutStyle;

  final TextAlign? textAlign;

  final TextDirection? textDirection;

  final Locale? locale;

  final bool? softWrap;

  final TextOverflow? overflow;

  final double? textScaleFactor;

  final int? maxLines;

  final String? semanticsLabel;

  final TextWidthBasis? textWidthBasis;

  final ui.TextHeightBehavior? textHeightBehavior;

  final Color? selectionColor;

  @override
  State<StatefulWidget> createState() => BambooTextState();
}

class BambooTextState extends State<BambooText> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext builderContext) {
        return Text.rich(
          widget.textSpanBuilder.call(
            TextBuilderContext._wrap(builderContext),
          ),
          style: widget.style,
          strutStyle: widget.strutStyle,
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
          locale: widget.locale,
          softWrap: widget.softWrap,
          overflow: widget.overflow,
          textScaleFactor: widget.textScaleFactor,
          maxLines: widget.maxLines,
          semanticsLabel: widget.semanticsLabel,
          textWidthBasis: widget.textWidthBasis,
          textHeightBehavior: widget.textHeightBehavior,
          selectionColor: widget.selectionColor,
        );
      },
    );
  }
}

///
/// 包裹Builder的BuildContext，构造方法声明为私有，这限制了[SpanNode.buildSpan]只能
/// 在[BambooText]中调用
///
class TextBuilderContext {
  const TextBuilderContext._wrap(this.value);

  final BuildContext value;
}

class BambooTextThemeController extends StatelessWidget {
  const BambooTextThemeController({
    super.key,
    this.textStyle = const TextStyle(),
    this.textAlign,
    this.inherited = true,
    required this.child,
  });

  static TextStyle style(BuildContext context) {
    return DefaultTextStyle.of(context).style;
  }

  final TextStyle textStyle;

  final TextAlign? textAlign;

  final bool inherited;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (inherited) {
      return DefaultTextStyle.merge(
        child: child,
        style: textStyle,
        textAlign: textAlign,
      );
    }
    return DefaultTextStyle(
      style: textStyle,
      textAlign: textAlign,
      child: child,
    );
  }
}

// ignore: must_be_immutable
class InheritedStyleTextSpan extends TextSpan {
  InheritedStyleTextSpan({
    super.text,
    super.children,
    TextStyle? style,
    super.recognizer,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  }) : _textStyle = style {
    children?.forEach((child) {
      if (child is InheritedStyleTextSpan) {
        child._textStyle = child._textStyle?.merge(style);
      }
    });
  }

  TextStyle? _textStyle;

  @override
  TextStyle? get style => _textStyle;
}
