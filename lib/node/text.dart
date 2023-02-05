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
    TextStyle? textStyle =
        _InheritedTextTheme.maybe(textBuilderContext.value)?.textStyle;

    TextStyle newStyle = TextStyle(
      backgroundColor: node.backgroundColor,
      color: node.color,
      fontSize: node.fontSize,
      fontWeight: node.bold ?? false ? FontWeight.bold : textStyle?.fontWeight,
      fontStyle: node.italic ?? false ? FontStyle.italic : textStyle?.fontStyle,
      decoration: TextDecoration.combine([
        node.underlined ?? false
            ? TextDecoration.underline
            : TextDecoration.none,
        node.strikethrough ?? false
            ? TextDecoration.lineThrough
            : TextDecoration.none,
      ]),
    );

    TextStyle style = textStyle?.merge(newStyle) ?? newStyle;
    return TextSpan(
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

class BambooTextThemeController extends StatelessWidget {
  const BambooTextThemeController({
    super.key,
    this.textStyle,
    this.textAlign,
    this.inherited = true,
    required this.child,
  });

  final TextStyle? textStyle;

  final TextAlign? textAlign;

  final bool inherited;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    TextStyle? finalTextStyle = textStyle;
    if (inherited) {
      TextStyle? ancestorTextStyle =
          _InheritedTextTheme.maybe(context)?.textStyle;
      finalTextStyle = ancestorTextStyle?.merge(textStyle) ?? textStyle;
    }
    return _InheritedTextTheme(finalTextStyle, textAlign, child);
  }
}

class _InheritedTextTheme extends InheritedWidget {
  static _InheritedTextTheme? maybe(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_InheritedTextTheme>();
  }

  const _InheritedTextTheme(
    this.textStyle,
    this.textAlign,
    Widget child,
  ) : super(child: child);

  final TextStyle? textStyle;

  final TextAlign? textAlign;

  @override
  bool updateShouldNotify(covariant _InheritedTextTheme oldWidget) {
    return oldWidget.textStyle != textStyle || oldWidget.textAlign != textAlign;
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
