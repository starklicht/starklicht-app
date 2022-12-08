import 'package:flutter/material.dart';

enum LampGroups { fill, key, back, atmosphere, effect, ambient, spot }

extension LampGroupsExtension on LampGroups {
  IconData get icon {
    switch (this) {
      case LampGroups.fill:
        return Icons.lightbulb_circle;
      case LampGroups.key:
        return Icons.lightbulb_outline;
      case LampGroups.back:
        return Icons.lightbulb_circle_outlined;
      case LampGroups.atmosphere:
        return Icons.landscape;
      case LampGroups.effect:
        return Icons.local_fire_department;
      case LampGroups.ambient:
        return Icons.light_sharp;
      case LampGroups.spot:
        return Icons.flare;
    }
  }
}
