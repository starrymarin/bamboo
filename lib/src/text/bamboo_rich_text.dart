import 'dart:ui' as ui;

import 'package:bamboo/node.dart';
import 'package:bamboo/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'bamboo_paragraph.dart';
import 'bamboo_text_span.dart';

class BambooRichText extends StatelessWidget {
  const BambooRichText({
    super.key,
    required this.textSpan,
    required this.childNodes,
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
  }) : data = null;

  final String? data;

  final InlineSpan? textSpan;

  final List<Node> childNodes;

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
  Widget build(BuildContext context) {
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }
    if (MediaQuery.boldTextOf(context)) {
      effectiveTextStyle = effectiveTextStyle!
          .merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final SelectionRegistrar? registrar = SelectionContainer.maybeOf(context);
    Widget result = _BambooRichText(
      textAlign: textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start,
      textDirection: textDirection,
      // RichText uses Directionality.of to obtain a default if this is null.
      locale: locale,
      // RichText uses Localizations.localeOf to obtain a default if this is null
      softWrap: softWrap ?? defaultTextStyle.softWrap,
      overflow:
          overflow ?? effectiveTextStyle?.overflow ?? defaultTextStyle.overflow,
      textScaleFactor: textScaleFactor ?? MediaQuery.textScaleFactorOf(context),
      maxLines: maxLines ?? defaultTextStyle.maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis ?? defaultTextStyle.textWidthBasis,
      textHeightBehavior: textHeightBehavior ??
          defaultTextStyle.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      selectionRegistrar: registrar,
      selectionColor: selectionColor ??
          DefaultSelectionStyle.of(context).selectionColor ??
          DefaultSelectionStyle.defaultColor,
      text: TextSpan(
        style: effectiveTextStyle,
        text: data,
        children: textSpan != null ? <InlineSpan>[textSpan!] : null,
      ),
      spanGraphicsList: childNodes
          .map((node) => node.graphics)
          .whereType<SpanGraphics>()
          .toList(),
    );
    if (registrar != null) {
      result = MouseRegion(
        cursor: DefaultSelectionStyle.of(context).mouseCursor ??
            SystemMouseCursors.text,
        child: result,
      );
    }
    if (semanticsLabel != null) {
      result = Semantics(
        textDirection: textDirection,
        label: semanticsLabel,
        child: ExcludeSemantics(
          child: result,
        ),
      );
    }
    return result;
  }
}

class _BambooRichText extends MultiChildRenderObjectWidget {
  _BambooRichText({
    super.key,
    required this.text,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.textScaleFactor = 1.0,
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.selectionRegistrar,
    this.selectionColor,
    required this.spanGraphicsList,
  }) : super(children: WidgetSpan.extractFromInlineSpan(text, textScaleFactor));

  final InlineSpan text;

  final TextAlign textAlign;

  final TextDirection? textDirection;

  final bool softWrap;

  final TextOverflow overflow;

  final double textScaleFactor;

  final int? maxLines;

  final Locale? locale;

  final StrutStyle? strutStyle;

  final TextWidthBasis textWidthBasis;

  final ui.TextHeightBehavior? textHeightBehavior;

  final SelectionRegistrar? selectionRegistrar;

  final Color? selectionColor;

  final List<SpanGraphics> spanGraphicsList;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBambooParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      registrar: selectionRegistrar,
      selectionColor: selectionColor,
      spanGraphicsList: spanGraphicsList,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderBambooParagraph renderObject) {
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..textDirection = textDirection ?? Directionality.of(context)
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaleFactor = textScaleFactor
      ..maxLines = maxLines
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..registrar = selectionRegistrar
      ..selectionColor = selectionColor
      ..spanGraphicsList = spanGraphicsList;
  }
}

class _RenderBambooParagraph extends RenderBambooParagraph {
  _RenderBambooParagraph(
    super.text, {
    super.textAlign = TextAlign.start,
    required super.textDirection,
    super.softWrap = true,
    super.overflow = TextOverflow.clip,
    super.textScaleFactor = 1.0,
    super.maxLines,
    super.locale,
    super.strutStyle,
    super.textWidthBasis = TextWidthBasis.parent,
    super.textHeightBehavior,
    super.children,
    super.selectionColor,
    super.registrar,
    required List<SpanGraphics> spanGraphicsList,
  }) : _spanGraphicsList = spanGraphicsList;

  List<SpanGraphics> _spanGraphicsList;

  /// 如果[_spanGraphicsList]有变化，说明node有变化，那么[child]会markNeedsLayout
  /// 或markNeedsPaint，[_spanGraphicsList]不关心layout，所以只需markNeedsPaint
  set spanGraphicsList(List<SpanGraphics> value) {
    if (listEquals(_spanGraphicsList, value)) {
      return;
    }
    _spanGraphicsList = value;
    markNeedsPaint();
  }

  @override
  List<_SelectableFragment> getSelectableFragments() {
    List<_SelectableFragment> fragments = [];
    int spanStart = 0;
    text.visitChildren((span) {
      int spanLength = 0;
      if (span is TextSpan) {
        spanLength = span.text?.length ?? 0;
      } else if (span is PlaceholderSpan) {
        spanLength = span.toPlainText(includeSemanticsLabels: false).length;
      } else {
        throw Exception("不支持除TextSpan和PlaceholderSpan之外的类型");
      }
      if (span is BambooTextSpan) {
        TextRange range = TextRange(
          start: spanStart,
          end: spanStart + spanLength,
        );
        if (!range.isCollapsed) {
          fragments.add(_SelectableFragment(
            node: span.textNode,
            paragraph: this,
            range: range,
          ));
        }
      }
      spanStart += spanLength;
      return true;
    });
    return [];
    // return fragments;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (SpanGraphics spanRender in _spanGraphicsList) {
      spanRender.beforePaint(
        BambooTextParagraph.custom(paragraph: this),
        context,
        offset,
      );
    }
    super.paint(context, offset);
    for (SpanGraphics spanRender in _spanGraphicsList) {
      spanRender.afterPaint(
        BambooTextParagraph.custom(paragraph: this),
        context,
        offset,
      );
    }
  }

  Offset _getOffsetForPosition(TextPosition position) {
    return getOffsetForCaret(position, Rect.zero) +
        Offset(0, getFullHeightForCaret(position) ?? 0.0);
  }
}

class _SelectableFragment extends SelectableFragment {
  _SelectableFragment({
    required super.node,
    required this.paragraph,
    required this.range,
  });

  final _RenderBambooParagraph paragraph;

  final TextRange range;

  @override
  void didChangeParagraphLayout() {
    _cachedRect = null;
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    // TODO: implement dispatchSelectionEvent
    throw UnimplementedError();
  }

  @override
  SelectedContent? getSelectedContent() {
    // TODO: implement getSelectedContent
    throw UnimplementedError();
  }

  Matrix4 getTransformToParagraph() {
    return Matrix4.translationValues(_rect.left, _rect.top, 0.0);
  }

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    return getTransformToParagraph()
      ..multiply(paragraph.getTransformTo(ancestor));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO: implement paint
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    // TODO: implement pushHandleLayers
  }

  /// 如果[_cachedRect]为空，则计算从[range.start]到[range.end]构成的rect，然后把结果
  /// 设置给[_cachedRect]，并返回
  Rect get _rect {
    if (_cachedRect == null) {
      final List<TextBox> boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: range.start,
          extentOffset: range.end,
        ),
      );
      if (boxes.isNotEmpty) {
        Rect result = boxes.first.toRect();
        for (int index = 1; index < boxes.length; index += 1) {
          result = result.expandToInclude(boxes[index].toRect());
        }
        _cachedRect = result;
      } else {
        final Offset offset = paragraph._getOffsetForPosition(
          TextPosition(offset: range.start),
        );
        _cachedRect = Rect.fromPoints(
          offset,
          offset.translate(0, -paragraph.textPainter.preferredLineHeight),
        );
      }
    }
    return _cachedRect!;
  }

  /// [_rect]的shadow，在[didChangeParagraphLayout]的时候被置空
  Rect? _cachedRect;

  @override
  ui.Size get size => _rect.size;

  @override
  // TODO: implement value
  SelectionGeometry get value => throw UnimplementedError();
}
