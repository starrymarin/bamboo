import 'package:flutter/rendering.dart';

mixin RenderObjectWithLateChildMixin<ChildType extends RenderObject>
    on RenderObject implements RenderObjectWithChildMixin<ChildType> {
  ChildType? _child;

  @override
  ChildType? get child => _child;

  @override
  set child(ChildType? value) {
    _child = value;
  }
}

class RenderProxyBoxChild<ParentType extends RenderObject> extends RenderBox {
  @override
  ParentType? get parent => super.parent as ParentType?;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
}
