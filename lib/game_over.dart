import 'package:flutter/material.dart';
import 'package:game/mini_games/mirror_dash.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int highScore;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.highScore,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Title bounce animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouncing Title with glow
              ScaleTransition(
                scale: _scaleAnimation,
                child: Text(
                  'Game Over',
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 20,
                        color: Colors.blueAccent.withOpacity(0.8),
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Lottie character animation
              Lottie.asset(
                'assets/animations/Bouncy_ball.json',
                width: 150,
                height: 150,
                repeat: true,
              ),
              const SizedBox(height: 12),

              Text(
                "Score: ${widget.score}",
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                "High Score: ${widget.highScore}",
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 30),

              // Restart Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const Game1()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text("Restart"),
              ),
              // const SizedBox(height: 12),

              // // Back to Home
              // OutlinedButton.icon(
              //   onPressed: () {
              //     Navigator.popUntil(context, (route) => route.isFirst);
              //   },
              //   style: OutlinedButton.styleFrom(
              //     foregroundColor: Colors.white,
              //     side: const BorderSide(color: Colors.white54),
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //   ),
              //   icon: const Icon(Icons.home),
              //   label: const Text("Home"),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
