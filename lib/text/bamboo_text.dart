import 'dart:collection';
import 'dart:ui' as ui show TextHeightBehavior;

import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/render.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

///
/// 对[BambooText.build]context的封装，构造方法声明为私有，这限制了[SpanNode.buildSpan]
/// 只能在[BambooText]中调用
///
/// 使用[value]构建的InlineSpan一定在[BambooText]内部，[BambooText]销毁时会一并销毁，
/// 所以无需担心[BuildContext]泄露的问题
///
class BambooTextBuildContext {
  BambooTextBuildContext._wrap(this.value);

  final BuildContext value;

  BambooTextState state() {
    return (value as StatefulElement).state as BambooTextState;
  }
}

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

  final InlineSpan Function(BambooTextBuildContext bambooTextBuildContext)?
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
  final HashSet<GestureRecognizer> bambooTextSpanGestureRecognizers =
      HashSet.identity();

  InlineSpan _buildTextSpan(BambooTextBuildContext bambooTextBuildContext) {
    if (widget.textSpanBuilder != null) {
      return widget.textSpanBuilder!.call(bambooTextBuildContext);
    } else {
      return TextSpan(
        children: widget.childNodes.whereType<SpanNode>().map((spanNode) {
          return spanNode.buildSpan(bambooTextBuildContext);
        }).toList(),
      );
    }
  }

  void registerBambooTextSpanGestureRecognizer(GestureRecognizer recognizer) {
    bambooTextSpanGestureRecognizers.add(recognizer);
  }

  ///
  /// 首先找到本[BambooText]上层设置的textStyle，如果本[BambooText.style.inherit]为
  /// true，则与上层的style合并生成新的style，如果为false，则使用本身的style，然后将新
  /// style保存到[_BambooTextStyle]中，以便下层使用。新style只需要传输给
  /// [_BambooTextStyle]，不需要传输给[_TextProxy]和[Text]，因为他们的textPainter会
  /// 默认合并上层的样式，而新style的作用则是生成strutStyle，并将其设置给[_TextProxy]和
  /// [Text]
  ///
  /// 如果[BambooText.strutStyle]不为null，[_TextProxy]和[Text]使用
  /// [BambooText.strutStyle]，如果为null，则使用新生成的strutStyle，保证Text的
  /// strutStyle不为空
  ///
  /// [Text.strutStyle]不能为空，否则某些样式会出现问题，比如InlineCode
  ///
  @override
  Widget build(BuildContext context) {
    TextStyle ancestorTextStyle = _BambooTextStyle.maybe(context)?.textStyle ??
        DefaultTextStyle.of(context).style;
    TextStyle textStyle;
    if (widget.style == null) {
      textStyle = ancestorTextStyle;
    } else {
      if (widget.style?.inherit == true) {
        textStyle = widget.style!.merge(ancestorTextStyle);
      } else {
        textStyle = widget.style!;
      }
    }
    StrutStyle? mergedStrutStyle = StrutStyle.fromTextStyle(textStyle);

    return _BambooTextStyle(
      textStyle: textStyle,
      child: _TextProxy(
        textStyle: widget.style,
        textAlign: widget.textAlign ?? TextAlign.start,
        textDirection: widget.textDirection,
        textScaleFactor: widget.textScaleFactor ?? 1.0,
        locale: widget.locale,
        strutStyle: widget.strutStyle ?? mergedStrutStyle,
        textWidthBasis: widget.textWidthBasis ?? TextWidthBasis.parent,
        textHeightBehavior: widget.textHeightBehavior,
        spanRenders: widget.childNodes
            .map((node) => node.render)
            .whereType<SpanRender>()
            .toList(),
        child: Text.rich(
          _buildTextSpan(BambooTextBuildContext._wrap(context)),
          style: widget.style,
          strutStyle: widget.strutStyle ?? mergedStrutStyle,
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
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (var recognizer in bambooTextSpanGestureRecognizers) {
      recognizer.dispose();
    }
  }
}

///
/// 保存与上层合并之后的textStyle，查看[BambooText.build]
///
class _BambooTextStyle extends InheritedWidget {
  const _BambooTextStyle({
    required this.textStyle,
    required super.child,
  });

  final TextStyle? textStyle;

  static _BambooTextStyle? maybe(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_BambooTextStyle>();
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    if (oldWidget is! _BambooTextStyle) {
      return false;
    }
    return textStyle != oldWidget.textStyle;
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
    required this.spanRenders,
  });

  final TextStyle? textStyle;

  final TextAlign textAlign;

  final TextDirection? textDirection;

  final double textScaleFactor;

  final Locale? locale;

  final StrutStyle? strutStyle;

  final TextWidthBasis textWidthBasis;

  final TextHeightBehavior? textHeightBehavior;

  final List<SpanRender> spanRenders;

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
      spanRenders: spanRenders,
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
      ..spanRenders = spanRenders;
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
    required List<SpanRender> spanRenders,
  })  : _spanRenders = spanRenders,
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

  List<SpanRender> _spanRenders;

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

  /// 如果[_spanRenders]有变化，说明node有变化，那么[child]会markNeedsLayout
  /// 或markNeedsPaint，[_spanRenders]不关心layout，所以只需markNeedsPaint
  set spanRenders(List<SpanRender> value) {
    if (listEquals(_spanRenders, value)) {
      return;
    }
    _spanRenders = value;
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
    for (SpanRender spanRender in _spanRenders) {
      spanRender.paint(child, context, offset);
    }
    super.paint(context, offset);
  }
}
