import 'dart:ui';

import 'package:bamboo/bamboo.dart';
import 'package:bamboo/rendering/editor.dart';
import 'package:bamboo/rendering/bamboo_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class BambooTextSpan extends TextSpan {
  BambooTextSpan({
    required this.readOnly,
    required this.context,
    super.text,
    super.children,
    super.style,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  }) : super(
          recognizer:
              readOnly ? null : BambooTextSpanTapRecognizer(context: context),
        ) {
    context.state().registerBambooTextSpanGestureRecognizer(recognizer);
  }

  final bool readOnly;

  final BambooTextBuildContext context;
}

class BambooTextSpanTapRecognizer extends TapGestureRecognizer {
  BambooTextSpanTapRecognizer({required this.context});

  final BambooTextBuildContext context;

  late final RenderEditor _renderEditor = Editor.renderObject(context.value);

  TapDownDetails? _downDetails;

  late final RenderParagraphProxy? _paragraphProxy =
      _findRenderParagraph(context.value);

  RenderParagraphProxy? _findRenderParagraph(BuildContext context) {
    RenderParagraphProxy? paragraph;
    context.visitChildElements((element) {
      RenderObject? renderObject = element.renderObject;
      if (renderObject is RenderParagraphProxy) {
        paragraph = renderObject;
      } else {
        paragraph = _findRenderParagraph(element);
      }
    });
    return paragraph;
  }

  @override
  GestureTapDownCallback? get onTapDown => _onTapDown;

  @override
  GestureTapCallback? get onTap => _onTap;

  void _onTapDown(TapDownDetails downDetails) {
    _downDetails = downDetails;
  }

  void _onTap() {
    final paragraphProxy = _paragraphProxy;
    if (paragraphProxy == null) {
      return;
    }
    RenderParagraph paragraph = paragraphProxy.child;

    final downDetails = _downDetails;
    if (downDetails == null) {
      return;
    }

    TextPosition positionInParagraph =
        paragraph.getPositionForOffset(downDetails.localPosition);
    _renderEditor.updateCursor(paragraphProxy, positionInParagraph);
  }
}
