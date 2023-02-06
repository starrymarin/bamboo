import 'dart:ui' as ui show TextHeightBehavior;

import 'package:bamboo/node/internal/json.dart';
import 'package:bamboo/utils/color.dart';
import 'package:bamboo/node/node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class TextNode extends Node implements SpanNode {
  TextNode({required super.json}) : super(display: _TextSpanDisplay());

  @override
  SpanDisplay get display => super.display as SpanDisplay;

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
    return display.buildSpan(textBuilderContext);
  }

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

class _TextSpanDisplay extends SpanDisplay<TextNode> {
  @override
  InlineSpan buildSpan(TextBuilderContext textBuilderContext) {
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
    required this.childNodes,
    this.textSpanBuilder,
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

  final List<Node> childNodes;

  final InlineSpan Function(TextBuilderContext textBuilderContext)?
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
  InlineSpan _buildTextSpan(TextBuilderContext textBuilderContext) {
    if (widget.textSpanBuilder != null) {
      return widget.textSpanBuilder!.call(textBuilderContext);
    } else {
      return TextSpan(
        children: widget.childNodes.whereType<SpanNode>().map((spanNode) {
          return spanNode.buildSpan(textBuilderContext);
        }).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext builderContext) {
        return _TextProxy(
          textStyle: widget.style,
          textAlign: widget.textAlign ?? TextAlign.start,
          textDirection: widget.textDirection,
          textScaleFactor: widget.textScaleFactor ?? 1.0,
          locale: widget.locale,
          strutStyle: widget.strutStyle,
          textWidthBasis: widget.textWidthBasis ?? TextWidthBasis.parent,
          textHeightBehavior: widget.textHeightBehavior,
          spanDisplays: widget.childNodes
              .map((node) => node.display)
              .whereType<SpanDisplay>()
              .toList(),
          child: Text.rich(
            _buildTextSpan(TextBuilderContext._wrap(builderContext)),
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
          ),
        );
      },
    );
  }
}

class _TextProxy extends SingleChildRenderObjectWidget {
  const _TextProxy({
    required Text super.child,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.textScaleFactor = 1.0,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    required this.spanDisplays,
  });

  final TextStyle? textStyle;

  final TextAlign textAlign;

  final TextDirection? textDirection;

  final double textScaleFactor;

  final Locale? locale;

  final StrutStyle? strutStyle;

  final TextWidthBasis textWidthBasis;

  final TextHeightBehavior? textHeightBehavior;

  final List<SpanDisplay> spanDisplays;

  @override
  Text get child => super.child! as Text;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderParagraphProxy(
      textStyle: textStyle,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      textScaleFactor: textScaleFactor,
      strutStyle: strutStyle,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      spanDisplays: spanDisplays,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderParagraphProxy renderObject) {
    renderObject
      ..textStyle = textStyle
      ..textAlign = textAlign
      ..textDirection = textDirection ?? Directionality.of(context)
      ..textScaleFactor = textScaleFactor
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..spanDisplays = spanDisplays;
  }
}

class _RenderParagraphProxy extends RenderProxyBox {
  _RenderParagraphProxy({
    TextStyle? textStyle,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    double textScaleFactor = 1.0,
    StrutStyle? strutStyle,
    Locale? locale,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    TextHeightBehavior? textHeightBehavior,
    required List<SpanDisplay> spanDisplays,
  })  : _spanDisplays = spanDisplays,
        _prototypePainter = TextPainter(
          text: TextSpan(text: ' ', style: textStyle),
          textAlign: textAlign,
          textDirection: textDirection,
          textScaleFactor: textScaleFactor,
          strutStyle: strutStyle,
          locale: locale,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
        );

  final TextPainter _prototypePainter;

  List<SpanDisplay> _spanDisplays;

  set textStyle(TextStyle? value) {
    if (_prototypePainter.text!.style == value) {
      return;
    }
    _prototypePainter.text = TextSpan(text: ' ', style: value);
    markNeedsLayout();
  }

  set textAlign(TextAlign value) {
    if (_prototypePainter.textAlign == value) {
      return;
    }
    _prototypePainter.textAlign = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection? value) {
    if (_prototypePainter.textDirection == value) {
      return;
    }
    _prototypePainter.textDirection = value;
    markNeedsLayout();
  }

  set textScaleFactor(double value) {
    if (_prototypePainter.textScaleFactor == value) {
      return;
    }
    _prototypePainter.textScaleFactor = value;
    markNeedsLayout();
  }

  set strutStyle(StrutStyle? value) {
    if (_prototypePainter.strutStyle == value) {
      return;
    }
    _prototypePainter.strutStyle = value;
    markNeedsLayout();
  }

  set locale(Locale? value) {
    if (_prototypePainter.locale == value) {
      return;
    }
    _prototypePainter.locale = value;
    markNeedsLayout();
  }

  set textWidthBasis(TextWidthBasis value) {
    if (_prototypePainter.textWidthBasis == value) {
      return;
    }
    _prototypePainter.textWidthBasis = value;
    markNeedsLayout();
  }

  set textHeightBehavior(TextHeightBehavior? value) {
    if (_prototypePainter.textHeightBehavior == value) {
      return;
    }
    _prototypePainter.textHeightBehavior = value;
    markNeedsLayout();
  }

  /// 如果[_spanDisplays]有变化，说明node有变化，那么[child]会markNeedsLayout
  /// 或markNeedsPaint，[_spanDisplays]不关心layout，所以只需markNeedsPaint
  set spanDisplays(List<SpanDisplay> value) {
    if (listEquals(_spanDisplays, value)) {
      return;
    }
    _spanDisplays = value;
    markNeedsPaint();
  }

  @override
  RenderParagraph get child => super.child! as RenderParagraph;

  @override
  void performLayout() {
    super.performLayout();
    _prototypePainter.layout(
        minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (SpanDisplay spanDisplay in _spanDisplays) {
      spanDisplay.paint(child, context, offset);
    }
    super.paint(context, offset);
  }
}

///
/// 包裹Builder的BuildContext，构造方法声明为私有，这限制了[SpanNode.buildSpan]只能
/// 在[BambooText]中调用
///
class TextBuilderContext {
  TextBuilderContext._wrap(BuildContext value)
      : _weakValue = WeakReference(value);

  final WeakReference<BuildContext> _weakValue;

  BuildContext? get value => _weakValue.target;
}
