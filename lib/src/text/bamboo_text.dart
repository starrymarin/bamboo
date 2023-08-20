import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:bamboo/caret.dart';
import 'package:bamboo/node.dart';

import 'bamboo_paragraph.dart';

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
  /// style保存到[_BambooTextStyle]中，以便下层使用。新style的另一个作用则是生成strutStyle，
  /// 并将其设置给[_BambooRichText]
  ///
  /// 如果[BambooText.strutStyle]不为null，[_BambooRichText]使用[BambooText.strutStyle]，
  /// 如果为null，则使用新生成的strutStyle，保证Text的strutStyle不为空
  ///
  /// [Text.strutStyle]不能为空，否则某些样式会出现问题，比如InlineCode
  ///
  @override
  Widget build(BuildContext context) {
    DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle ancestorTextStyle =
        _BambooTextStyle.maybe(context)?.textStyle ?? defaultTextStyle.style;
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
    if (MediaQuery.boldTextOf(context)) {
      textStyle = textStyle.merge(const TextStyle(fontWeight: FontWeight.bold));
    }

    CaretVisibleRegistrar caretRegistrar = CaretContainer.maybeOf(context)!;

    CaretContainerDelegate caretContainerDelegate = CaretContainerDelegate();

    final SelectionRegistrar? registrar = SelectionContainer.maybeOf(context);

    Widget result = _BambooRichText(
      text: TextSpan(
        style: textStyle,
        children: [_buildTextSpan(BambooTextBuildContext._wrap(context))]
      ),
      textAlign:
          widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start,
      textDirection: widget.textDirection,
      // RichText uses Directionality.of to obtain a default if this is null.
      locale: widget.locale,
      // RichText uses Localizations.localeOf to obtain a default if this is null
      softWrap: widget.softWrap ?? defaultTextStyle.softWrap,
      overflow:
          widget.overflow ?? textStyle.overflow ?? defaultTextStyle.overflow,
      textScaleFactor:
          widget.textScaleFactor ?? MediaQuery.textScaleFactorOf(context),
      maxLines: widget.maxLines ?? defaultTextStyle.maxLines,
      strutStyle: widget.strutStyle ?? StrutStyle.fromTextStyle(textStyle),
      textWidthBasis: widget.textWidthBasis ?? defaultTextStyle.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior ??
          defaultTextStyle.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      selectionRegistrar: registrar,
      selectionColor: widget.selectionColor ??
          DefaultSelectionStyle.of(context).selectionColor ??
          DefaultSelectionStyle.defaultColor,
      spanRenders: widget.childNodes
          .map((node) => node.render)
          .whereType<SpanRendering>()
          .toList(),
    );
    if (registrar != null) {
      result = MouseRegion(
        cursor: DefaultSelectionStyle.of(context).mouseCursor ??
            SystemMouseCursors.text,
        child: result,
      );
    }
    if (widget.semanticsLabel != null) {
      result = Semantics(
        textDirection: widget.textDirection,
        label: widget.semanticsLabel,
        child: ExcludeSemantics(
          child: result,
        ),
      );
    }

    return CaretContainer(
      registrar: caretRegistrar,
      delegate: caretContainerDelegate,
      child: _BambooTextStyle(
        textStyle: textStyle,
        child: result,
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
//
// class _SelectableFragmentsGenerator extends SelectableFragmentsGenerator {
//   _SelectableFragmentsGenerator({
//     required this.text,
//   });
//
//   final InlineSpan text;
//
//   @override
//   List<SelectableFragment> generateSelectableFragments(
//       RenderParagraph paragraph) {
//     List<SelectableFragment> fragments = [];
//     int spanStart = 0;
//     text.visitChildren(
//       (span) {
//         int spanLength = 0;
//         if (span is TextSpan) {
//           spanLength = span.text?.length ?? 0;
//         } else if (span is PlaceholderSpan) {
//           spanLength = span.toPlainText(includeSemanticsLabels: false).length;
//         } else {
//           throw Exception("不支持除TextSpan和PlaceholderSpan之外的类型");
//         }
//         if (span is BambooTextSpan) {
//           TextRange range = TextRange(
//             start: spanStart,
//             end: spanStart + spanLength,
//           );
//           if (!range.isCollapsed) {
//             fragments.add(SelectableFragment(
//               paragraph: paragraph,
//               fullText: span.text,
//               range: range,
//             ));
//           }
//         }
//         spanStart += spanLength;
//         return true;
//       },
//     );
//     return fragments;
//   }
// }

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

mixin ChildRenderParagraphMixin on RenderProxyBox {
  late final RenderBambooParagraph renderParagraph = () {
    return _findRenderParagraph(child);
  }();

  RenderBambooParagraph _findRenderParagraph(RenderObject? renderObject) {
    if (renderObject is RenderBambooParagraph) {
      return renderObject;
    } else if (renderObject is RenderObjectWithChildMixin) {
      return _findRenderParagraph(renderObject.child);
    } else {
      throw Exception();
    }
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
    required this.spanRenders,
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

  final List<SpanRendering> spanRenders;

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
      spanRenders: spanRenders,
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
      ..spanRenders = spanRenders;
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
    required List<SpanRendering> spanRenders,
  }) : _spanRenders = spanRenders;

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
  List<_SelectableFragment> getSelectableFragments() {
    return [];
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (SpanRendering spanRender in _spanRenders) {
      spanRender.beforePaint(this, context, offset);
    }
    super.paint(context, offset);
    for (SpanRendering spanRender in _spanRenders) {
      spanRender.afterPaint(this, context, offset);
    }
  }
}

class _SelectableFragment extends SelectableFragment {
  @override
  void didChangeParagraphLayout() {
    // TODO: implement didChangeParagraphLayout
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

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    // TODO: implement getTransformTo
    throw UnimplementedError();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO: implement paint
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    // TODO: implement pushHandleLayers
  }

  @override
  // TODO: implement size
  ui.Size get size => throw UnimplementedError();

  @override
  // TODO: implement value
  SelectionGeometry get value => throw UnimplementedError();
}
