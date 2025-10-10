import 'package:flutter/widgets.dart';

bool _isBlocker(Element e) =>
    e.widget is AbsorbPointer ||
    e.widget is IgnorePointer ||
    e.widget.runtimeType.toString() == 'ModalBarrier';

/// Use only in asserts.
void debugAssertNoInteractionBlocker(BuildContext context) {
  assert(() {
    var blocked = false;
    context.visitAncestorElements((el) {
      if (_isBlocker(el)) blocked = true;
      return true;
    });
    assert(
      !blocked,
      'Interaction blocked by AbsorbPointer/IgnorePointer/ModalBarrier above this widget.',
    );
    return true;
  }());
}
