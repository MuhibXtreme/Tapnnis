import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';

class AppBackground extends FlameGame {
  @override
  Future<void> onLoad() async {
    // Create parallax background
    final parallax = await loadParallaxComponent(
      [
        ParallaxImageData('bg_sky.png'),
        ParallaxImageData('bg_mountains.png'),
        ParallaxImageData('bg_ground.png'),
      ],
      baseVelocity: Vector2(20, 0),
      velocityMultiplierDelta: Vector2(1.5, 0),
    );

    add(parallax);
  }
}
