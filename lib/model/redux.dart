import 'package:flutter/foundation.dart';
import 'package:starklicht_flutter/model/enums.dart';
import 'package:starklicht_flutter/view/animations.dart';

enum Actions {
  SetAnimationSettingsConfig
}

class AnimationSettingsConfig {
  InterpolationType interpolationType;
  TimeFactor timefactor;
  int seconds;
  int millis;
  Function? callback;

  AnimationSettingsConfig(
      this.interpolationType,
      this.timefactor,
      this.seconds,
      this.millis
      );

  Map<String, dynamic> toJson() => {
    'interpolationType': interpolationType.toString().split('.')[1],
    'timeFactor': timefactor.toString().split('.')[1],
    'millis': millis,
    'seconds': seconds
  };

}

class GradientSettingsConfig {
  List<ColorPoint> colors;
  Function? callback;

  GradientSettingsConfig(
      this.colors,
      );
}