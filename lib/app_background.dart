import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';

class AppBackground extends FlameGame {
  int score = 0; // Add the player's score

  // List to hold the different background images
  List<String> backgrounds = [
    'day_sun.png', // Day with sun and clouds
    'floating_clouds.png', // Clouds floating
    'rainy_day.png', // Rainy background
    'night_mode.png', // Night mode
  ];

  int currentBackgroundIndex = 0; // Keeps track of the current background state

  @override
  Future<void> onLoad() async {
    // Create parallax background
    await changeBackground(currentBackgroundIndex);

    // Optionally, add a listener for score change if using game state update
  }

  // Function to change background based on score
  Future changeBackground(int index) async {
    final parallax = await loadParallaxComponent(
      [
        ParallaxImageData(backgrounds[index]), // Load image based on index
      ],
      baseVelocity: Vector2(30, 0), // Adjust base velocity
      velocityMultiplierDelta: Vector2(1.5, 0), // Adjust velocity multiplier
      fill: LayerFill
          .height, // Ensures the background scales to fit the width of the screen
    );

    // Apply scaling to reduce the zoom
    parallax.scale = Vector2(1, 1); // Scale both X and Y by 0.5

    add(parallax);
  }

  // This function could be called after every score update
  void updateScore(int points) {
    score += points;

    // Check if score reached multiples of 50 to change the background
    if (score >= 50 && score < 100) {
      currentBackgroundIndex = 1; // Floating clouds
      changeBackground(currentBackgroundIndex);
    } else if (score >= 100 && score < 150) {
      currentBackgroundIndex = 2; // Rainy background
      changeBackground(currentBackgroundIndex);
    } else if (score >= 150) {
      currentBackgroundIndex = 3; // Night mode
      changeBackground(currentBackgroundIndex);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Call updateScore in a specific game loop based on your game logic
    // For example, updateScore(10) would be called when the player scores points
  }
}
