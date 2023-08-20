import 'dart:ui';

extension StringToColor on String? {
  Color? toColor() {
    if (this == null) {
      return null;
    }
    var hexColor = this!.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
