import 'package:bamboo/node.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

abstract class BambooSelectable with Selectable, ChangeNotifier {
  BambooSelectable({
    required this.node
  });

  final Node node;
}

class BambooSelectionContainerDelegate extends MultiSelectableSelectionContainerDelegate {
  @override
  List<Selectable> get selectables => super.selectables as List<BambooSelectable>;

  @override
  void ensureChildUpdated(Selectable selectable) {
    // TODO: implement ensureChildUpdated
  }

  @override
  void add(Selectable selectable) {
    if (selectable is! BambooSelectable) {
      return;
    }
    super.add(selectable);
  }

  @override
  Comparator<Selectable> get compareOrder => _compareBambooSelectableOrder;

  int _compareBambooSelectableOrder(Selectable a, Selectable b) {
    if (a is! BambooSelectable || b is! BambooSelectable) {
      throw Exception("不接受非BambooSelectable类型");
    }
    List<int> aPath = a.node.path;
    List<int> bPath = b.node.path;
    if (aPath.length != bPath.length) {
      // 如果a.length比b.length长，说明a比b深，深的node要排在前面
      return -(aPath.length - bPath.length);
    } else {
      for (int index = 0; index < aPath.length; index++) {
        if (aPath[index] != bPath[index]) {
          return -(aPath[index] - bPath[index]);
        } else {
          continue;
        }
      }
      return 0;
    }
  }
}