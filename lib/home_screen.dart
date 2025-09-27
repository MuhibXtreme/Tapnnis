import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:game/mini_games/mirror_dash.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _fadeIn.dispose();
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
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.center,

                // mainAxisSize: MainAxisSize.min,
                children: [
                  // --- LOTTIE ANIMATION ---
                  // Use an asset:
                  SizedBox(
                    height: 250,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(0), // adjust if needed
                      child: Lottie.asset(
                        'assets/animations/home_animation.json',
                        repeat: true,
                        width: 250, // 👈 make it bigger
                        height: 250, // 👈 make it bigger
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Or use a network animation (uncomment to try):
                  // SizedBox(
                  //   height: 220,
                  //   child: Lottie.network(
                  //     'https://assets10.lottiefiles.com/packages/lf20_puciaact.json',
                  //     repeat: true,
                  //     fit: BoxFit.contain,
                  //   ),
                  // ),
                  const SizedBox(height: 10),

                  // Title
                  const Text(
                    'Tapnnis!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          blurRadius: 12,
                          color: Colors.black54,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome to the adventure 🚀',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Start Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 10,
                      shadowColor: Colors.black45,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          transitionDuration:
                              const Duration(milliseconds: 1000),
                          pageBuilder: (_, __, ___) => Game1(),
                          transitionsBuilder: (_, animation, __, child) {
                            final curved = CurvedAnimation(
                                parent: animation, curve: Curves.easeInOut);

                            return FadeTransition(
                              opacity: curved,
                              child: ScaleTransition(
                                scale: curved,
                                child: child,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 26),
                    label: const Text(
                      'Start Game',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // How to Play
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(20), // Rounded corners
                          ),
                          backgroundColor: Colors.deepPurple[
                              50], // Light background for the dialog
                          title: Center(
                            child: const Text(
                              "How to Play",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                "🎮 Tap the screen to jump!\n\n"
                                "⭐ Collect stars to increase score.\n\n"
                                "🚀 Avoid obstacles and keep dashing.\n\n"
                                "⚡ Speed will increases as gradually!", // Added single line of text
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Got it!",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'How to Play?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
