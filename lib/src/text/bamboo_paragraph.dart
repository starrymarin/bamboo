import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bamboo/selection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

const String _kEllipsis = '\u2026';

/// 因为选区的绘制和操作需要更多的[_textPainter]功能，但是flutter sdk中提供的[RenderParagraph]
/// 中[RenderParagraph._textPainter]是私有的，无法访问到，为了达成目的，设想了三种方案
/// 1. 修改flutter sdk源码
/// 2. 继承[RenderParagraph]，在子类中新建一个textPainter，复制部分[RenderParagraph]的
/// 代码，保证子类的textPainter和[RenderParagraph._textPainter]行为保持一致
/// 3. 复制[RenderParagraph]代码
///
/// 最终选择了方案三是因为：
/// 1. 修改flutter sdk源码对其他开发者不友好
/// 2. [RenderParagraph]源码大致由"textPainter相关操作"、"无障碍"和"selectableFragment"
/// 三部分组成，如果采用方案二，实际上复制的代码量也并不少，更重要的是存在两个textPainter，就需要
/// layout两次，会影响性能。"无障碍"和"selectableFragment"相关代码量并不大，所以不如全部复
/// 制过来，还有更大的灵活性，唯一不足的是可能无法及时同步flutter官方的更新
///
/// 修改部分如下：
/// 1. [RenderBambooParagraph]修改为abstract类，使用时需要实现[getSelectableFragments]
/// 2. [_lastSelectableFragments]类型由[_selectableFragment]替换为[SelectableFragment]
/// 3. 开放了[textPainter]
/// 4. 修改[getBoxesForSelection]boxHeightStyle默认值为[ui.BoxHeightStyle.strut]
abstract class RenderBambooParagraph extends RenderBox with ContainerRenderObjectMixin<RenderBox, TextParentData>, RenderInlineChildrenContainerDefaults, RelayoutWhenSystemFontsChangeMixin {
  /// Creates a paragraph render object.
  ///
  /// The [text], [textAlign], [textDirection], [overflow], [softWrap], and
  /// [textScaleFactor] arguments must not be null.
  ///
  /// The [maxLines] property may be null (and indeed defaults to null), but if
  /// it is not null, it must be greater than zero.
  RenderBambooParagraph(InlineSpan text, {
    TextAlign textAlign = TextAlign.start,
    required TextDirection textDirection,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    double textScaleFactor = 1.0,
    int? maxLines,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    ui.TextHeightBehavior? textHeightBehavior,
    List<RenderBox>? children,
    Color? selectionColor,
    SelectionRegistrar? registrar,
  }) : assert(text.debugAssertIsValid()),
        assert(maxLines == null || maxLines > 0),
        _softWrap = softWrap,
        _overflow = overflow,
        _selectionColor = selectionColor,
        _textPainter = TextPainter(
          text: text,
          textAlign: textAlign,
          textDirection: textDirection,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          ellipsis: overflow == TextOverflow.ellipsis ? _kEllipsis : null,
          locale: locale,
          strutStyle: strutStyle,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
        ) {
    addAll(children);
    this.registrar = registrar;
  }

  static final String _placeholderCharacter = String.fromCharCode(PlaceholderSpan.placeholderCodeUnit);
  final TextPainter _textPainter;

  ///
  TextPainter get textPainter => _textPainter;

  List<AttributedString>? _cachedAttributedLabels;

  List<InlineSpanSemanticsInformation>? _cachedCombinedSemanticsInfos;

  /// The text to display.
  InlineSpan get text => _textPainter.text!;
  set text(InlineSpan value) {
    switch (_textPainter.text!.compareTo(value)) {
      case RenderComparison.identical:
        return;
      case RenderComparison.metadata:
        _textPainter.text = value;
        _cachedCombinedSemanticsInfos = null;
        markNeedsSemanticsUpdate();
      case RenderComparison.paint:
        _textPainter.text = value;
        _cachedAttributedLabels = null;
        _canComputeIntrinsicsCached = null;
        _cachedCombinedSemanticsInfos = null;
        markNeedsPaint();
        markNeedsSemanticsUpdate();
      case RenderComparison.layout:
        _textPainter.text = value;
        _overflowShader = null;
        _cachedAttributedLabels = null;
        _cachedCombinedSemanticsInfos = null;
        _canComputeIntrinsicsCached = null;
        markNeedsLayout();
        _removeSelectionRegistrarSubscription();
        _disposeSelectableFragments();
        _updateSelectionRegistrarSubscription();
    }
  }

  /// The ongoing selections in this paragraph.
  ///
  /// The selection does not include selections in [PlaceholderSpan] if there
  /// are any.
  @visibleForTesting
  List<TextSelection> get selections {
    if (_lastSelectableFragments == null) {
      return const <TextSelection>[];
    }
    final List<TextSelection> results = <TextSelection>[];
    for (final SelectableFragment fragment in _lastSelectableFragments!) {
      if (fragment.textSelectionStart != null &&
          fragment.textSelectionEnd != null &&
          fragment.textSelectionStart!.offset != fragment.textSelectionEnd!.offset) {
        results.add(
            TextSelection(
                baseOffset: fragment.textSelectionStart!.offset,
                extentOffset: fragment.textSelectionEnd!.offset
            )
        );
      }
    }
    return results;
  }

  // Should be null if selection is not enabled, i.e. _registrar = null. The
  // paragraph splits on [PlaceholderSpan.placeholderCodeUnit], and stores each
  // fragment in this list.
  List<SelectableFragment>? _lastSelectableFragments;

  /// The [SelectionRegistrar] this paragraph will be, or is, registered to.
  SelectionRegistrar? get registrar => _registrar;
  SelectionRegistrar? _registrar;
  set registrar(SelectionRegistrar? value) {
    if (value == _registrar) {
      return;
    }
    _removeSelectionRegistrarSubscription();
    _disposeSelectableFragments();
    _registrar = value;
    _updateSelectionRegistrarSubscription();
  }

  void _updateSelectionRegistrarSubscription() {
    if (_registrar == null) {
      return;
    }
    _lastSelectableFragments ??= getSelectableFragments();
    _lastSelectableFragments!.forEach(_registrar!.add);
  }

  void _removeSelectionRegistrarSubscription() {
    if (_registrar == null || _lastSelectableFragments == null) {
      return;
    }
    _lastSelectableFragments!.forEach(_registrar!.remove);
  }

  List<SelectableFragment> getSelectableFragments();

  void _disposeSelectableFragments() {
    if (_lastSelectableFragments == null) {
      return;
    }
    for (final SelectableFragment fragment in _lastSelectableFragments!) {
      fragment.dispose();
    }
    _lastSelectableFragments = null;
  }

  @override
  void markNeedsLayout() {
    _lastSelectableFragments?.forEach((SelectableFragment element) => element.didChangeParagraphLayout());
    super.markNeedsLayout();
  }

  @override
  void dispose() {
    _removeSelectionRegistrarSubscription();
    // _lastSelectableFragments may hold references to this RenderParagraph.
    // Release them manually to avoid retain cycles.
    _lastSelectableFragments = null;
    _textPainter.dispose();
    super.dispose();
  }

  /// How the text should be aligned horizontally.
  TextAlign get textAlign => _textPainter.textAlign;
  set textAlign(TextAlign value) {
    if (_textPainter.textAlign == value) {
      return;
    }
    _textPainter.textAlign = value;
    markNeedsPaint();
  }

  /// The directionality of the text.
  ///
  /// This decides how the [TextAlign.start], [TextAlign.end], and
  /// [TextAlign.justify] values of [textAlign] are interpreted.
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the [text] is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  ///
  /// This must not be null.
  TextDirection get textDirection => _textPainter.textDirection!;
  set textDirection(TextDirection value) {
    if (_textPainter.textDirection == value) {
      return;
    }
    _textPainter.textDirection = value;
    markNeedsLayout();
  }

  /// Whether the text should break at soft line breaks.
  ///
  /// If false, the glyphs in the text will be positioned as if there was
  /// unlimited horizontal space.
  ///
  /// If [softWrap] is false, [overflow] and [textAlign] may have unexpected
  /// effects.
  bool get softWrap => _softWrap;
  bool _softWrap;
  set softWrap(bool value) {
    if (_softWrap == value) {
      return;
    }
    _softWrap = value;
    markNeedsLayout();
  }

  /// How visual overflow should be handled.
  TextOverflow get overflow => _overflow;
  TextOverflow _overflow;
  set overflow(TextOverflow value) {
    if (_overflow == value) {
      return;
    }
    _overflow = value;
    _textPainter.ellipsis = value == TextOverflow.ellipsis ? _kEllipsis : null;
    markNeedsLayout();
  }

  /// The number of font pixels for each logical pixel.
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  double get textScaleFactor => _textPainter.textScaleFactor;
  set textScaleFactor(double value) {
    if (_textPainter.textScaleFactor == value) {
      return;
    }
    _textPainter.textScaleFactor = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// An optional maximum number of lines for the text to span, wrapping if
  /// necessary. If the text exceeds the given number of lines, it will be
  /// truncated according to [overflow] and [softWrap].
  int? get maxLines => _textPainter.maxLines;
  /// The value may be null. If it is not null, then it must be greater than
  /// zero.
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (_textPainter.maxLines == value) {
      return;
    }
    _textPainter.maxLines = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// Used by this paragraph's internal [TextPainter] to select a
  /// locale-specific font.
  ///
  /// In some cases, the same Unicode character may be rendered differently
  /// depending on the locale. For example, the '骨' character is rendered
  /// differently in the Chinese and Japanese locales. In these cases, the
  /// [locale] may be used to select a locale-specific font.
  Locale? get locale => _textPainter.locale;
  /// The value may be null.
  set locale(Locale? value) {
    if (_textPainter.locale == value) {
      return;
    }
    _textPainter.locale = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// {@macro flutter.painting.textPainter.strutStyle}
  StrutStyle? get strutStyle => _textPainter.strutStyle;
  /// The value may be null.
  set strutStyle(StrutStyle? value) {
    if (_textPainter.strutStyle == value) {
      return;
    }
    _textPainter.strutStyle = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// {@macro flutter.painting.textPainter.textWidthBasis}
  TextWidthBasis get textWidthBasis => _textPainter.textWidthBasis;
  set textWidthBasis(TextWidthBasis value) {
    if (_textPainter.textWidthBasis == value) {
      return;
    }
    _textPainter.textWidthBasis = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// {@macro dart.ui.textHeightBehavior}
  ui.TextHeightBehavior? get textHeightBehavior => _textPainter.textHeightBehavior;
  set textHeightBehavior(ui.TextHeightBehavior? value) {
    if (_textPainter.textHeightBehavior == value) {
      return;
    }
    _textPainter.textHeightBehavior = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  /// The color to use when painting the selection.
  ///
  /// Ignored if the text is not selectable (e.g. if [registrar] is null).
  Color? get selectionColor => _selectionColor;
  Color? _selectionColor;
  set selectionColor(Color? value) {
    if (_selectionColor == value) {
      return;
    }
    _selectionColor = value;
    if (_lastSelectableFragments?.any((SelectableFragment fragment) => fragment.value.hasSelection) ?? false) {
      markNeedsPaint();
    }
  }

  Offset _getOffsetForPosition(TextPosition position) {
    return getOffsetForCaret(position, Rect.zero) + Offset(0, getFullHeightForCaret(position) ?? 0.0);
  }

  List<ui.LineMetrics> _computeLineMetrics() {
    return _textPainter.computeLineMetrics();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (!_canComputeIntrinsics()) {
      return 0.0;
    }
    _textPainter.setPlaceholderDimensions(layoutInlineChildren(
      double.infinity,
          (RenderBox child, BoxConstraints constraints) => Size(child.getMinIntrinsicWidth(double.infinity), 0.0),
    ));
    _layoutText(); // layout with infinite width.
    return _textPainter.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (!_canComputeIntrinsics()) {
      return 0.0;
    }
    _textPainter.setPlaceholderDimensions(layoutInlineChildren(
      double.infinity,
      // Height and baseline is irrelevant as all text will be laid
      // out in a single line. Therefore, using 0.0 as a dummy for the height.
          (RenderBox child, BoxConstraints constraints) => Size(child.getMaxIntrinsicWidth(double.infinity), 0.0),
    ));
    _layoutText(); // layout with infinite width.
    return _textPainter.maxIntrinsicWidth;
  }

  double _computeIntrinsicHeight(double width) {
    if (!_canComputeIntrinsics()) {
      return 0.0;
    }
    _textPainter.setPlaceholderDimensions(layoutInlineChildren(width, ChildLayoutHelper.dryLayoutChild));
    _layoutText(minWidth: width, maxWidth: width);
    return _textPainter.height;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _computeIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _computeIntrinsicHeight(width);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    assert(constraints.debugAssertIsValid());
    _layoutTextWithConstraints(constraints);
    // TODO(garyq): Since our metric for ideographic baseline is currently
    // inaccurate and the non-alphabetic baselines are based off of the
    // alphabetic baseline, we use the alphabetic for now to produce correct
    // layouts. We should eventually change this back to pass the `baseline`
    // property when the ideographic baseline is properly implemented
    // (https://github.com/flutter/flutter/issues/22625).
    return _textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  /// Whether all inline widget children of this [RenderBox] support dry layout
  /// calculation.
  bool _canComputeDryLayoutForInlineWidgets() {
    // Dry layout cannot be calculated without a full layout for
    // alignments that require the baseline (baseline, aboveBaseline,
    // belowBaseline).
    return text.visitChildren((InlineSpan span) {
      return (span is! PlaceholderSpan) || switch (span.alignment) {
        ui.PlaceholderAlignment.baseline ||
        ui.PlaceholderAlignment.aboveBaseline ||
        ui.PlaceholderAlignment.belowBaseline => false,
        ui.PlaceholderAlignment.top ||
        ui.PlaceholderAlignment.middle ||
        ui.PlaceholderAlignment.bottom => true,
      };
    });
  }

  bool? _canComputeIntrinsicsCached;
  // Intrinsics cannot be calculated without a full layout for
  // alignments that require the baseline (baseline, aboveBaseline,
  // belowBaseline).
  bool _canComputeIntrinsics() {
    final bool returnValue = _canComputeIntrinsicsCached ??= _canComputeDryLayoutForInlineWidgets();
    assert(
    returnValue || RenderObject.debugCheckingIntrinsics,
    'Intrinsics are not available for PlaceholderAlignment.baseline, '
        'PlaceholderAlignment.aboveBaseline, or PlaceholderAlignment.belowBaseline.',
    );
    return returnValue;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    final TextPosition textPosition = _textPainter.getPositionForOffset(position);
    final Object? span = _textPainter.text!.getSpanForPosition(textPosition);
    if (span is HitTestTarget) {
      result.add(HitTestEntry(span));
      return true;
    }
    return hitTestInlineChildren(result, position);
  }

  bool _needsClipping = false;
  ui.Shader? _overflowShader;

  /// Whether this paragraph currently has a [dart:ui.Shader] for its overflow
  /// effect.
  ///
  /// Used to test this object. Not for use in production.
  @visibleForTesting
  bool get debugHasOverflowShader => _overflowShader != null;

  void _layoutText({ double minWidth = 0.0, double maxWidth = double.infinity }) {
    final bool widthMatters = softWrap || overflow == TextOverflow.ellipsis;
    _textPainter.layout(
      minWidth: minWidth,
      maxWidth: widthMatters ? maxWidth : double.infinity,
    );
  }

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _textPainter.markNeedsLayout();
  }

  // Placeholder dimensions representing the sizes of child inline widgets.
  //
  // These need to be cached because the text painter's placeholder dimensions
  // will be overwritten during intrinsic width/height calculations and must be
  // restored to the original values before final layout and painting.
  List<PlaceholderDimensions>? _placeholderDimensions;

  void _layoutTextWithConstraints(BoxConstraints constraints) {
    _textPainter.setPlaceholderDimensions(_placeholderDimensions);
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (!_canComputeIntrinsics()) {
      assert(debugCannotComputeDryLayout(
        reason: 'Dry layout not available for alignments that require baseline.',
      ));
      return Size.zero;
    }
    _textPainter.setPlaceholderDimensions(layoutInlineChildren(constraints.maxWidth, ChildLayoutHelper.dryLayoutChild));
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    return constraints.constrain(_textPainter.size);
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    _placeholderDimensions = layoutInlineChildren(constraints.maxWidth, ChildLayoutHelper.layoutChild);
    _layoutTextWithConstraints(constraints);
    positionInlineChildren(_textPainter.inlinePlaceholderBoxes!);

    // We grab _textPainter.size and _textPainter.didExceedMaxLines here because
    // assigning to `size` will trigger us to validate our intrinsic sizes,
    // which will change _textPainter's layout because the intrinsic size
    // calculations are destructive. Other _textPainter state will also be
    // affected. See also RenderEditable which has a similar issue.
    final Size textSize = _textPainter.size;
    final bool textDidExceedMaxLines = _textPainter.didExceedMaxLines;
    size = constraints.constrain(textSize);

    final bool didOverflowHeight = size.height < textSize.height || textDidExceedMaxLines;
    final bool didOverflowWidth = size.width < textSize.width;
    // TODO(abarth): We're only measuring the sizes of the line boxes here. If
    // the glyphs draw outside the line boxes, we might think that there isn't
    // visual overflow when there actually is visual overflow. This can become
    // a problem if we start having horizontal overflow and introduce a clip
    // that affects the actual (but undetected) vertical overflow.
    final bool hasVisualOverflow = didOverflowWidth || didOverflowHeight;
    if (hasVisualOverflow) {
      switch (_overflow) {
        case TextOverflow.visible:
          _needsClipping = false;
          _overflowShader = null;
        case TextOverflow.clip:
        case TextOverflow.ellipsis:
          _needsClipping = true;
          _overflowShader = null;
        case TextOverflow.fade:
          _needsClipping = true;
          final TextPainter fadeSizePainter = TextPainter(
            text: TextSpan(style: _textPainter.text!.style, text: '\u2026'),
            textDirection: textDirection,
            textScaleFactor: textScaleFactor,
            locale: locale,
          )..layout();
          if (didOverflowWidth) {
            double fadeEnd, fadeStart;
            switch (textDirection) {
              case TextDirection.rtl:
                fadeEnd = 0.0;
                fadeStart = fadeSizePainter.width;
                break;
              case TextDirection.ltr:
                fadeEnd = size.width;
                fadeStart = fadeEnd - fadeSizePainter.width;
                break;
            }
            _overflowShader = ui.Gradient.linear(
              Offset(fadeStart, 0.0),
              Offset(fadeEnd, 0.0),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          } else {
            final double fadeEnd = size.height;
            final double fadeStart = fadeEnd - fadeSizePainter.height / 2.0;
            _overflowShader = ui.Gradient.linear(
              Offset(0.0, fadeStart),
              Offset(0.0, fadeEnd),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          }
          fadeSizePainter.dispose();
      }
    } else {
      _needsClipping = false;
      _overflowShader = null;
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    defaultApplyPaintTransform(child, transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Ideally we could compute the min/max intrinsic width/height with a
    // non-destructive operation. However, currently, computing these values
    // will destroy state inside the painter. If that happens, we need to get
    // back the correct state by calling _layout again.
    //
    // TODO(abarth): Make computing the min/max intrinsic width/height a
    //  non-destructive operation.
    //
    // If you remove this call, make sure that changing the textAlign still
    // works properly.
    _layoutTextWithConstraints(constraints);

    assert(() {
      if (debugRepaintTextRainbowEnabled) {
        final Paint paint = Paint()
          ..color = debugCurrentRepaintColor.toColor();
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    }());

    if (_needsClipping) {
      final Rect bounds = offset & size;
      if (_overflowShader != null) {
        // This layer limits what the shader below blends with to be just the
        // text (as opposed to the text and its background).
        context.canvas.saveLayer(bounds, Paint());
      } else {
        context.canvas.save();
      }
      context.canvas.clipRect(bounds);
    }

    if (_lastSelectableFragments != null) {
      for (final SelectableFragment fragment in _lastSelectableFragments!) {
        fragment.paint(context, offset);
      }
    }

    _textPainter.paint(context.canvas, offset);

    paintInlineChildren(context, offset);

    if (_needsClipping) {
      if (_overflowShader != null) {
        context.canvas.translate(offset.dx, offset.dy);
        final Paint paint = Paint()
          ..blendMode = BlendMode.modulate
          ..shader = _overflowShader;
        context.canvas.drawRect(Offset.zero & size, paint);
      }
      context.canvas.restore();
    }
  }

  /// Returns the offset at which to paint the caret.
  ///
  /// Valid only after [layout].
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getOffsetForCaret(position, caretPrototype);
  }

  /// {@macro flutter.painting.textPainter.getFullHeightForCaret}
  ///
  /// Valid only after [layout].
  double? getFullHeightForCaret(TextPosition position) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getFullHeightForCaret(position, Rect.zero);
  }

  /// Returns a list of rects that bound the given selection.
  ///
  /// The [boxHeightStyle] and [boxWidthStyle] arguments may be used to select
  /// the shape of the [TextBox]es. These properties default to
  /// [ui.BoxHeightStyle.tight] and [ui.BoxWidthStyle.tight] respectively and
  /// must not be null.
  ///
  /// A given selection might have more than one rect if the [RenderParagraph]
  /// contains multiple [InlineSpan]s or bidirectional text, because logically
  /// contiguous text might not be visually contiguous.
  ///
  /// Valid only after [layout].
  ///
  /// See also:
  ///
  ///  * [TextPainter.getBoxesForSelection], the method in TextPainter to get
  ///    the equivalent boxes.
  List<ui.TextBox> getBoxesForSelection(
      TextSelection selection, {
        ui.BoxHeightStyle boxHeightStyle = ui.BoxHeightStyle.strut,
        ui.BoxWidthStyle boxWidthStyle = ui.BoxWidthStyle.tight,
      }) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getBoxesForSelection(
      selection,
      boxHeightStyle: boxHeightStyle,
      boxWidthStyle: boxWidthStyle,
    );
  }

  /// Returns the position within the text for the given pixel offset.
  ///
  /// Valid only after [layout].
  TextPosition getPositionForOffset(Offset offset) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getPositionForOffset(offset);
  }

  /// Returns the text range of the word at the given offset. Characters not
  /// part of a word, such as spaces, symbols, and punctuation, have word breaks
  /// on both sides. In such cases, this method will return a text range that
  /// contains the given text position.
  ///
  /// Word boundaries are defined more precisely in Unicode Standard Annex #29
  /// <http://www.unicode.org/reports/tr29/#Word_Boundaries>.
  ///
  /// Valid only after [layout].
  TextRange getWordBoundary(TextPosition position) {
    assert(!debugNeedsLayout);
    _layoutTextWithConstraints(constraints);
    return _textPainter.getWordBoundary(position);
  }

  TextRange _getLineAtOffset(TextPosition position) => _textPainter.getLineBoundary(position);

  TextPosition _getTextPositionAbove(TextPosition position) {
    // -0.5 of preferredLineHeight points to the middle of the line above.
    final double preferredLineHeight = _textPainter.preferredLineHeight;
    final double verticalOffset = -0.5 * preferredLineHeight;
    return _getTextPositionVertical(position, verticalOffset);
  }

  TextPosition _getTextPositionBelow(TextPosition position) {
    // 1.5 of preferredLineHeight points to the middle of the line below.
    final double preferredLineHeight = _textPainter.preferredLineHeight;
    final double verticalOffset = 1.5 * preferredLineHeight;
    return _getTextPositionVertical(position, verticalOffset);
  }

  TextPosition _getTextPositionVertical(TextPosition position, double verticalOffset) {
    final Offset caretOffset = _textPainter.getOffsetForCaret(position, Rect.zero);
    final Offset caretOffsetTranslated = caretOffset.translate(0.0, verticalOffset);
    return _textPainter.getPositionForOffset(caretOffsetTranslated);
  }

  /// Returns the size of the text as laid out.
  ///
  /// This can differ from [size] if the text overflowed or if the [constraints]
  /// provided by the parent [RenderObject] forced the layout to be bigger than
  /// necessary for the given [text].
  ///
  /// This returns the [TextPainter.size] of the underlying [TextPainter].
  ///
  /// Valid only after [layout].
  Size get textSize {
    assert(!debugNeedsLayout);
    return _textPainter.size;
  }

  /// Collected during [describeSemanticsConfiguration], used by
  /// [assembleSemanticsNode] and [_combineSemanticsInfo].
  List<InlineSpanSemanticsInformation>? _semanticsInfo;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    _semanticsInfo = text.getSemanticsInformation();
    bool needsAssembleSemanticsNode = false;
    bool needsChildConfigrationsDelegate = false;
    for (final InlineSpanSemanticsInformation info in _semanticsInfo!) {
      if (info.recognizer != null) {
        needsAssembleSemanticsNode = true;
        break;
      }
      needsChildConfigrationsDelegate = needsChildConfigrationsDelegate || info.isPlaceholder;
    }

    if (needsAssembleSemanticsNode) {
      config.explicitChildNodes = true;
      config.isSemanticBoundary = true;
    } else if (needsChildConfigrationsDelegate) {
      config.childConfigurationsDelegate = _childSemanticsConfigurationsDelegate;
    } else {
      if (_cachedAttributedLabels == null) {
        final StringBuffer buffer = StringBuffer();
        int offset = 0;
        final List<StringAttribute> attributes = <StringAttribute>[];
        for (final InlineSpanSemanticsInformation info in _semanticsInfo!) {
          final String label = info.semanticsLabel ?? info.text;
          for (final StringAttribute infoAttribute in info.stringAttributes) {
            final TextRange originalRange = infoAttribute.range;
            attributes.add(
              infoAttribute.copy(
                range: TextRange(
                  start: offset + originalRange.start,
                  end: offset + originalRange.end,
                ),
              ),
            );
          }
          buffer.write(label);
          offset += label.length;
        }
        _cachedAttributedLabels = <AttributedString>[AttributedString(buffer.toString(), attributes: attributes)];
      }
      config.attributedLabel = _cachedAttributedLabels![0];
      config.textDirection = textDirection;
    }
  }

  ChildSemanticsConfigurationsResult _childSemanticsConfigurationsDelegate(List<SemanticsConfiguration> childConfigs) {
    final ChildSemanticsConfigurationsResultBuilder builder = ChildSemanticsConfigurationsResultBuilder();
    int placeholderIndex = 0;
    int childConfigsIndex = 0;
    int attributedLabelCacheIndex = 0;
    InlineSpanSemanticsInformation? seenTextInfo;
    _cachedCombinedSemanticsInfos ??= combineSemanticsInfo(_semanticsInfo!);
    for (final InlineSpanSemanticsInformation info in _cachedCombinedSemanticsInfos!) {
      if (info.isPlaceholder) {
        if (seenTextInfo != null) {
          builder.markAsMergeUp(_createSemanticsConfigForTextInfo(seenTextInfo, attributedLabelCacheIndex));
          attributedLabelCacheIndex += 1;
        }
        // Mark every childConfig belongs to this placeholder to merge up group.
        while (childConfigsIndex < childConfigs.length &&
            childConfigs[childConfigsIndex].tagsChildrenWith(PlaceholderSpanIndexSemanticsTag(placeholderIndex))) {
          builder.markAsMergeUp(childConfigs[childConfigsIndex]);
          childConfigsIndex += 1;
        }
        placeholderIndex += 1;
      } else {
        seenTextInfo = info;
      }
    }

    // Handle plain text info at the end.
    if (seenTextInfo != null) {
      builder.markAsMergeUp(_createSemanticsConfigForTextInfo(seenTextInfo, attributedLabelCacheIndex));
    }
    return builder.build();
  }

  SemanticsConfiguration _createSemanticsConfigForTextInfo(InlineSpanSemanticsInformation textInfo, int cacheIndex) {
    assert(!textInfo.requiresOwnNode);
    final List<AttributedString> cachedStrings = _cachedAttributedLabels ??= <AttributedString>[];
    assert(cacheIndex <= cachedStrings.length);
    final bool hasCache = cacheIndex < cachedStrings.length;

    late AttributedString attributedLabel;
    if (hasCache) {
      attributedLabel = cachedStrings[cacheIndex];
    } else {
      assert(cachedStrings.length == cacheIndex);
      attributedLabel = AttributedString(
        textInfo.semanticsLabel ?? textInfo.text,
        attributes: textInfo.stringAttributes,
      );
      cachedStrings.add(attributedLabel);
    }
    return SemanticsConfiguration()
      ..textDirection = textDirection
      ..attributedLabel = attributedLabel;
  }

  // Caches [SemanticsNode]s created during [assembleSemanticsNode] so they
  // can be re-used when [assembleSemanticsNode] is called again. This ensures
  // stable ids for the [SemanticsNode]s of [TextSpan]s across
  // [assembleSemanticsNode] invocations.
  LinkedHashMap<Key, SemanticsNode>? _cachedChildNodes;

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    assert(_semanticsInfo != null && _semanticsInfo!.isNotEmpty);
    final List<SemanticsNode> newChildren = <SemanticsNode>[];
    TextDirection currentDirection = textDirection;
    Rect currentRect;
    double ordinal = 0.0;
    int start = 0;
    int placeholderIndex = 0;
    int childIndex = 0;
    RenderBox? child = firstChild;
    final LinkedHashMap<Key, SemanticsNode> newChildCache = LinkedHashMap<Key, SemanticsNode>();
    _cachedCombinedSemanticsInfos ??= combineSemanticsInfo(_semanticsInfo!);
    for (final InlineSpanSemanticsInformation info in _cachedCombinedSemanticsInfos!) {
      final TextSelection selection = TextSelection(
        baseOffset: start,
        extentOffset: start + info.text.length,
      );
      start += info.text.length;

      if (info.isPlaceholder) {
        // A placeholder span may have 0 to multiple semantics nodes, we need
        // to annotate all of the semantics nodes belong to this span.
        while (children.length > childIndex &&
            children.elementAt(childIndex).isTagged(PlaceholderSpanIndexSemanticsTag(placeholderIndex))) {
          final SemanticsNode childNode = children.elementAt(childIndex);
          final TextParentData parentData = child!.parentData! as TextParentData;
          // parentData.scale may be null if the render object is truncated.
          if (parentData.offset != null) {
            newChildren.add(childNode);
          }
          childIndex += 1;
        }
        child = childAfter(child!);
        placeholderIndex += 1;
      } else {
        final TextDirection initialDirection = currentDirection;
        final List<ui.TextBox> rects = getBoxesForSelection(selection);
        if (rects.isEmpty) {
          continue;
        }
        Rect rect = rects.first.toRect();
        currentDirection = rects.first.direction;
        for (final ui.TextBox textBox in rects.skip(1)) {
          rect = rect.expandToInclude(textBox.toRect());
          currentDirection = textBox.direction;
        }
        // Any of the text boxes may have had infinite dimensions.
        // We shouldn't pass infinite dimensions up to the bridges.
        rect = Rect.fromLTWH(
          math.max(0.0, rect.left),
          math.max(0.0, rect.top),
          math.min(rect.width, constraints.maxWidth),
          math.min(rect.height, constraints.maxHeight),
        );
        // round the current rectangle to make this API testable and add some
        // padding so that the accessibility rects do not overlap with the text.
        currentRect = Rect.fromLTRB(
          rect.left.floorToDouble() - 4.0,
          rect.top.floorToDouble() - 4.0,
          rect.right.ceilToDouble() + 4.0,
          rect.bottom.ceilToDouble() + 4.0,
        );
        final SemanticsConfiguration configuration = SemanticsConfiguration()
          ..sortKey = OrdinalSortKey(ordinal++)
          ..textDirection = initialDirection
          ..attributedLabel = AttributedString(info.semanticsLabel ?? info.text, attributes: info.stringAttributes);
        final GestureRecognizer? recognizer = info.recognizer;
        if (recognizer != null) {
          if (recognizer is TapGestureRecognizer) {
            if (recognizer.onTap != null) {
              configuration.onTap = recognizer.onTap;
              configuration.isLink = true;
            }
          } else if (recognizer is DoubleTapGestureRecognizer) {
            if (recognizer.onDoubleTap != null) {
              configuration.onTap = recognizer.onDoubleTap;
              configuration.isLink = true;
            }
          } else if (recognizer is LongPressGestureRecognizer) {
            if (recognizer.onLongPress != null) {
              configuration.onLongPress = recognizer.onLongPress;
            }
          } else {
            assert(false, '${recognizer.runtimeType} is not supported.');
          }
        }
        if (node.parentPaintClipRect != null) {
          final Rect paintRect = node.parentPaintClipRect!.intersect(currentRect);
          configuration.isHidden = paintRect.isEmpty && !currentRect.isEmpty;
        }
        late final SemanticsNode newChild;
        if (_cachedChildNodes?.isNotEmpty ?? false) {
          newChild = _cachedChildNodes!.remove(_cachedChildNodes!.keys.first)!;
        } else {
          final UniqueKey key = UniqueKey();
          newChild = SemanticsNode(
            key: key,
            showOnScreen: _createShowOnScreenFor(key),
          );
        }
        newChild
          ..updateWith(config: configuration)
          ..rect = currentRect;
        newChildCache[newChild.key!] = newChild;
        newChildren.add(newChild);
      }
    }
    // Makes sure we annotated all of the semantics children.
    assert(childIndex == children.length);
    assert(child == null);

    _cachedChildNodes = newChildCache;
    node.updateWith(config: config, childrenInInversePaintOrder: newChildren);
  }

  VoidCallback? _createShowOnScreenFor(Key key) {
    return () {
      final SemanticsNode node = _cachedChildNodes![key]!;
      showOnScreen(descendant: this, rect: node.rect);
    };
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _cachedChildNodes = null;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      text.toDiagnosticsNode(
        name: 'text',
        style: DiagnosticsTreeStyle.transition,
      ),
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
    properties.add(
      FlagProperty(
        'softWrap',
        value: softWrap,
        ifTrue: 'wrapping at box width',
        ifFalse: 'no wrapping except at line break characters',
        showName: true,
      ),
    );
    properties.add(EnumProperty<TextOverflow>('overflow', overflow));
    properties.add(
      DoubleProperty(
        'textScaleFactor',
        textScaleFactor,
        defaultValue: 1.0,
      ),
    );
    properties.add(
      DiagnosticsProperty<Locale>(
        'locale',
        locale,
        defaultValue: null,
      ),
    );
    properties.add(IntProperty('maxLines', maxLines, ifNull: 'unlimited'));
  }
}

abstract class SelectableFragment extends BambooSelectable {
  SelectableFragment({required super.node});

  TextPosition? textSelectionStart;
  TextPosition? textSelectionEnd;

  void didChangeParagraphLayout();

  void paint(PaintingContext context, Offset offset);
}
