import 'package:flutter/widgets.dart';

enum Breakpoint { phone, tablet, desktop }

Breakpoint bpOf(BuildContext c) {
  final w = MediaQuery.sizeOf(c).width;
  if (w >= 1024) return Breakpoint.desktop;
  if (w >= 600) return Breakpoint.tablet;
  return Breakpoint.phone;
}
