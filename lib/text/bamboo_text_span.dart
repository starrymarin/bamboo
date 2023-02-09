import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class BambooTextSpan extends TextSpan {
  BambooTextSpan({
    required this.readOnly,
    super.text,
    super.children,
    super.style,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  }) : super(recognizer: (readOnly ? null : BambooTextSpanTapRecognizer()));

  final bool readOnly;
}

class BambooTextSpanTapRecognizer extends TapGestureRecognizer {

}
