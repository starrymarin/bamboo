import 'dart:collection';
import 'dart:ui' as ui show TextHeightBehavior;

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/caret.dart';
import 'package:bamboo/node/node.dart';
import 'package:bamboo/node/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'bamboo_text_caret.dart';

///
/// 对[BambooText.build]context的封装，构造方法声明为私有，这限制了[SpanNode.buildSpan]
/// 只能在[BambooText]中调用
///
class BambooTextBuildContext {
  BambooTextBuildContext._wrap(BuildContext context)
      : _weakValue = WeakReference(context);

  final WeakReference<BuildContext> _weakValue;

  BuildContext? get value => _weakValue.target;

  BambooTextState? state() {
    return (value as StatefulElement?)?.state as BambooTextState?;
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

  void registerBambooTextSpanGestureRecognizer(GestureRecognizer? recognizer) {
    if (recognizer != null) {
      bambooTextSpanGestureRecognizers.add(recognizer);
    }
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

    CaretVisibleRegistrar caretRegistrar = CaretContainer.maybeOf(context)!;

    CaretContainerDelegate caretContainerDelegate = CaretContainerDelegate();

    return CaretContainer(
      registrar: caretRegistrar,
      delegate: caretContainerDelegate,
      child: _BambooTextStyle(
        textStyle: textStyle,
        child: _TextProxy(
          caretRegistrar: caretContainerDelegate,
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
              .whereType<SpanRendering>()
              .toList(),
          bambooTheme: BambooTheme.of(context),
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
    required this.caretRegistrar,
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
    required this.bambooTheme,
  });

  final CaretVisibleRegistrar caretRegistrar;

  final TextStyle? textStyle;

  final TextAlign textAlign;

  final TextDirection? textDirection;

  final double textScaleFactor;

  final Locale? locale;

  final StrutStyle? strutStyle;

  final TextWidthBasis textWidthBasis;

  final TextHeightBehavior? textHeightBehavior;

  final List<SpanRendering> spanRenders;

  final BambooTheme bambooTheme;

  @override
  Text get child => super.child! as Text;

  /// 从[Text.build]拷贝，需要保持和Text行为一致
  TextStyle? normalizeTextStyle(BuildContext context) {
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = textStyle;
    if (textStyle == null || textStyle!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(textStyle);
    }
    if (MediaQuery.boldTextOverride(context)) {
      effectiveTextStyle = effectiveTextStyle!
          .merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return effectiveTextStyle;
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderParagraphProxy(
      textStyle: normalizeTextStyle(context),
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      textScaleFactor: textScaleFactor,
      strutStyle: strutStyle,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      spanRenders: spanRenders,
      caretRegistrar: caretRegistrar,
      bambooTheme: bambooTheme,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderParagraphProxy renderObject) {
    renderObject
      ..textStyle = normalizeTextStyle(context)
      ..textAlign = textAlign
      ..textDirection = textDirection ?? Directionality.of(context)
      ..textScaleFactor = textScaleFactor
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..spanRenders = spanRenders
      ..caretRegistrar = caretRegistrar
      ..bambooTheme = bambooTheme;
  }
}

class RenderParagraphProxy extends RenderProxyBox
    with
        _ChildRenderParagraphMixin,
        _PrototypeTextPainterMixin,
        _RenderParagraphProxyCursorMixin {
  RenderParagraphProxy({
    TextStyle? textStyle,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    double textScaleFactor = 1.0,
    StrutStyle? strutStyle,
    Locale? locale,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    TextHeightBehavior? textHeightBehavior,
    required List<SpanRendering> spanRenders,
    required BambooTheme bambooTheme,
    required CaretVisibleRegistrar caretRegistrar,
  }) : _spanRenders = spanRenders {
    _painter = TextPainter(
      text: TextSpan(text: ' ', style: textStyle),
      textAlign: textAlign,
      textDirection: textDirection,
      textScaleFactor: textScaleFactor,
      strutStyle: strutStyle,
      locale: locale,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
    this.caretRegistrar = caretRegistrar;
    this.bambooTheme = bambooTheme;
  }

  List<SpanRendering> _spanRenders;

  /// 如果[_spanRenders]有变化，说明node有变化，那么[child]会markNeedsLayout
  /// 或markNeedsPaint，[_spanRenders]不关心layout，所以只需markNeedsPaint
  set spanRenders(List<SpanRendering> value) {
    if (listEquals(_spanRenders, value)) {
      return;
    }
    _spanRenders = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (SpanRendering spanRender in _spanRenders) {
      spanRender.beforePaint(_renderParagraph, context, offset);
    }
    super.paint(context, offset);
    for (SpanRendering spanRender in _spanRenders) {
      spanRender.afterPaint(_renderParagraph, context, offset);
    }
  }
}

mixin _ChildRenderParagraphMixin on RenderProxyBox {
  late final RenderParagraph _renderParagraph = () {
    return _findRenderParagraph(child);
  }();

  RenderParagraph _findRenderParagraph(RenderObject? renderObject) {
    if (renderObject is RenderParagraph) {
      return renderObject;
    } else if (renderObject is RenderObjectWithChildMixin) {
      return _findRenderParagraph(renderObject.child);
    } else {
      throw Exception();
    }
  }
}

mixin _PrototypeTextPainterMixin on RenderBox {
  late TextPainter _painter;

  set textStyle(TextStyle? value) {
    if (_painter.text!.style == value) {
      return;
    }
    _painter.text = TextSpan(text: ' ', style: value);
    markNeedsLayout();
  }

  set textAlign(TextAlign value) {
    if (_painter.textAlign == value) {
      return;
    }
    _painter.textAlign = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection? value) {
    if (_painter.textDirection == value) {
      return;
    }
    _painter.textDirection = value;
    markNeedsLayout();
  }

  set textScaleFactor(double value) {
    if (_painter.textScaleFactor == value) {
      return;
    }
    _painter.textScaleFactor = value;
    markNeedsLayout();
  }

  set strutStyle(StrutStyle? value) {
    if (_painter.strutStyle == value) {
      return;
    }
    _painter.strutStyle = value;
    markNeedsLayout();
  }

  set locale(Locale? value) {
    if (_painter.locale == value) {
      return;
    }
    _painter.locale = value;
    markNeedsLayout();
  }

  set textWidthBasis(TextWidthBasis value) {
    if (_painter.textWidthBasis == value) {
      return;
    }
    _painter.textWidthBasis = value;
    markNeedsLayout();
  }

  set textHeightBehavior(TextHeightBehavior? value) {
    if (_painter.textHeightBehavior == value) {
      return;
    }
    _painter.textHeightBehavior = value;
    markNeedsLayout();
  }

  double get preferredLineHeight => _painter.preferredLineHeight;

  @override
  void performLayout() {
    super.performLayout();
    _painter.layout(
        minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
  }
}
