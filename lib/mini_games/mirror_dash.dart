import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:game/game_over.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ------------------------------------------------------------
/// GAME 1 — Professionalized single-file version (streak reset)
/// Implements: animated themes, power-ups, invincibility, scaling
/// Added: streak reset when a score block is missed and on death
/// ------------------------------------------------------------
class Game1 extends StatefulWidget {
  const Game1({super.key});
  @override
  State<Game1> createState() => _Game1State();
}

class _Game1State extends State<Game1> with TickerProviderStateMixin {
  // =========================
  // Config
  // =========================

  int highScore = 0;

  late AnimationController _shieldPulseController;
  static const double _playerSize = 56;
  static const int _streakNeeded = 5; // streak for red pause / safe window
  static const int _invincibleEvery = 50; // every 50 points
  static const int _invincibleDuration = 10; // sec_coonds
  static const int _scoreBoostSeconds = 5;
  static const int _redPauseSeconds = 10; // streak protection duration
  static const int _safeZoneSeconds = 10; // after safe-zone orb
  static const int _slowdownSeconds = 6; // slow down dangerous
  static const int _doubleShieldSeconds = 10;

  final Random _rng = Random();

  // =========================
  // Player physics
  // =========================
  double playerY = 0;
  double velocity = 0;
  double gravity = 0.0012;
  double liftForce = -0.032;

  ///ground danger
  bool showGroundDanger = false;
  double groundDangerX = 1.3;
  double groundDangerWidth = 100;
  double groundDangerHeight = 120;

  // =========================
  // Game state
  // =========================
  int score = 0;
  int level = 1;
  bool gameStarted = false;
  bool gameOver = false;
  bool isPaused = false;
  // Score multiplier (from booster or invincible)
  int scoreMultiplier = 1;

  // =========================
  // Theme + Background
  // =========================
  late AnimationController _themeCtrl; // drives theme transition overlays
  int _themeIndex = 0;
  // 5 layered themes (top->bottom gradient)
  final List<List<Color>> _themes = [
    [const Color(0xFF10132F), const Color(0xFF2B3560)], // deep dusk
    [const Color(0xFF1B2838), const Color(0xFF0F2027)], // cold steel
    [const Color(0xFF3C1053), const Color(0xFFAD5389)], // violet bloom
    [const Color(0xFF093028), const Color(0xFF237A57)], // emerald line
    [const Color(0xFF1F1C2C), const Color(0xFF928DAB)], // storm haze
  ];
  // subtle “video-like” moving overlay
  late AnimationController _bgMotionCtrl;

  // =========================
  // Obstacles (score blocks) & danger
  // =========================
  // Score block (bottom neon pillar)
  double obstacleX = 1.3;
  double obstacleWidth = 100;
  double obstacleHeight = 120;
  // double baseObstacleSpeed = 0.010;
  double baseObstacleSpeed = 0.005;
  // scales with score
  bool showObstacle = true;
  bool hasCollided = false;
  Color scoreBlockColor = const Color(0xFFB3F2FF);

  // Dangerous floating block
  double dangerX = 0.0;
  double dangerY = -0.4;
  double dangerSize = 250;
  bool showDanger = false;
  // double dangerSpeedFactor = 1.35;
  double dangerSpeedFactor = 1.0;

  // =========================
  // Power-ups
  // =========================
  // Orbs control
  bool showScoreBoostOrb = false; // purple — double score for 5s
  double scoreBoostX = 2.3, scoreBoostY = 0.0;

  bool showShieldOrb = false; // blue — one hit
  double shieldX = 2.3, shieldY = 0.0;

  bool showSlowdownOrb = false; // snow — slow ONLY dangerous
  double slowX = 2.3, slowY = 0.0;

  bool showSafeZoneOrb = false; // gold — only scoring obstacles
  double safeX = 2.3, safeY = 0.0;

  bool showDoubleShieldOrb = false; // orange — 2 hits + slowdown
  double dShieldX = 2.3, dShieldY = 0.0;

  // Power-up timers/state
  Timer? _scoreBoostTimer;
  Timer? _slowdownTimer;
  Timer? _safeZoneTimer;
  Timer? _doubleShieldTimer;
  Timer? _redPauseTimer;
  Timer? _invTimer;
  Timer? _gameLoop;

  // Shields
  int shields = 0;

  // Streak
  int scoreStreak = 0;
  double streakProgress = 0.0;
  bool showStreakIndicator = false;

  // Flags
  bool redObstaclePaused = false; // streak protection on dangerous
  bool safeZoneActive = false; // only score blocks show up
  bool slowdownActive = false; // dangerous slowed
  bool invincible = false; // special every 50 points

  // =========================
  // Debug
  // =========================
  bool debugMode = false;

  // =========================
  // Anim helpers
  // =========================
  Rect _playerRect(Size s) {
    final px = s.width / 2 - _playerSize / 2;
    final py = (s.height / 2) + (playerY * s.height / 2) - _playerSize / 2;
    return Rect.fromLTWH(px, py, _playerSize, _playerSize);
  }

  Rect _groundDangerRect(Size s) {
    final gx =
        (s.width / 2) + (groundDangerX * s.width / 2) - (groundDangerWidth / 2);
    final gy = s.height - groundDangerHeight;
    return Rect.fromLTWH(gx, gy, groundDangerWidth, groundDangerHeight);
  }

  Rect _obstacleRect(Size s) {
    final ox = (s.width / 2) + (obstacleX * s.width / 2) - (obstacleWidth / 2);
    final oy = s.height - obstacleHeight;
    return Rect.fromLTWH(ox, oy, obstacleWidth, obstacleHeight);
  }

  Rect _dangerRect(Size s) {
    final dx = (s.width / 2) + (dangerX * s.width / 2) - (dangerSize / 2);
    final dy = (s.height / 2) + (dangerY * s.height / 2) - (dangerSize / 2);
    return Rect.fromLTWH(dx, dy, dangerSize, dangerSize);
  }

  Rect _orbRect(Size s, double normX, double normY, double pct) {
    final w = s.width * pct, h = w;
    final cx = (normX + 1) * s.width / 2;
    final cy = (normY + 1) * s.height / 2;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  @override
  void initState() {
    super.initState();
    _loadHighScore();

    _shieldPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _themeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _bgMotionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // kick off idle player float
    Future.delayed(const Duration(milliseconds: 400), () {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _scoreBoostTimer?.cancel();
    _slowdownTimer?.cancel();
    _safeZoneTimer?.cancel();
    _doubleShieldTimer?.cancel();
    _redPauseTimer?.cancel();
    _invTimer?.cancel();
    _themeCtrl.dispose();
    _bgMotionCtrl.dispose();

    _shieldPulseController.dispose();
    super.dispose();
  }

  Future<void> _updateHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (score > highScore) {
      setState(() {
        highScore = score;
      });
      await prefs.setInt('highScore', highScore);
    }
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
    });
  }

  // =========================
  // GAME FLOW
  // =========================

  void _startGame() {
    gameOver = false;
    gameStarted = true;
    score = 0;
    level = 1;
    playerY = 0;
    velocity = 0;
    gravity = 0.0012;
    liftForce = -0.032;
    obstacleWidth = 100;
    baseObstacleSpeed = 0.005;
    shields = 0;
    invincible = false;
    scoreMultiplier = 1;
    showObstacle = true;
    showDanger = false;
    redObstaclePaused = false;
    scoreStreak = 0;
    streakProgress = 0;
    safeZoneActive = false;
    slowdownActive = false;

    _spawnScoreBlock();
    dangerX = 3.0;

    _gameLoop?.cancel();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      setState(() {
        // physics
        velocity += gravity;
        playerY += velocity;

        // bounds
        if (playerY > 1 || playerY < -1) {
          _hitOrDie();
        }

        // move score block
        if (showObstacle) {
          obstacleX -= _currentSpeed();
          if (obstacleX < -1.25) {
            // <-- MISS: reset streak if player didn't collect this block
            if (!hasCollided) {
              scoreStreak = 0;
              streakProgress = 0.0;
              if (score > 20) {
                showStreakIndicator = true;
              } else {
                showStreakIndicator = false;
              }
            }
            showObstacle = false;
            _spawnScoreBlock();
          }
        }

        // spawn/move dangerous unless paused/safe zone
        if (!safeZoneActive && !redObstaclePaused && score >= 7) {
          if (!showDanger || dangerX < -1.2) {
            _spawnDanger();
          }
          if (showDanger) {
            final slow = slowdownActive ? 0.55 : 1.0;
            dangerX -= _currentSpeed() * dangerSpeedFactor * slow;
          }
        } else {
          showDanger = false;
          showGroundDanger = false;
        }

        final s = MediaQuery.of(context).size;

        // collisions
        if (!gameOver &&
            showObstacle &&
            _playerRect(s).overlaps(_obstacleRect(s))) {
          if (!hasCollided) {
            hasCollided = true;
            _scorePoint();
            Future.delayed(const Duration(milliseconds: 100), _spawnScoreBlock);
          }
        }
        // move ground danger
        if (showGroundDanger) {
          groundDangerX -= _currentSpeed();
          if (groundDangerX < -1.25) {
            showGroundDanger = false;
            _spawnScoreBlock();
          }
        }

// collision with ground danger
        if (!gameOver &&
            showGroundDanger &&
            _playerRect(s).overlaps(_groundDangerRect(s))) {
          if (invincible) {
            showGroundDanger = false;
          } else if (shields > 0) {
            shields--;
            showGroundDanger = false;
            _spawnScoreBlock();
          } else {
            _endGame();
          }
        }

        if (!gameOver &&
            showDanger &&
            _playerRect(s).overlaps(_dangerRect(s))) {
          if (invincible) {
            // ignore
            showDanger = false;
          } else if (shields > 0) {
            shields--;
            showDanger = false;
          } else {
            _endGame();
          }
        }

        // Power-up spawn/move
        _tickOrb(
            refShow: () => showScoreBoostOrb,
            setShow: (v) => showScoreBoostOrb = v,
            x: () => scoreBoostX,
            setX: (v) => scoreBoostX = v,
            y: () => scoreBoostY,
            minScore: 20,
            spawnProb: 0.004);

        if (score > 30) {
          _tickOrb(
              refShow: () => showShieldOrb,
              setShow: (v) => showShieldOrb = v,
              x: () => shieldX,
              setX: (v) => shieldX = v,
              y: () => shieldY,
              minScore: 10,
              spawnProb: 0.004);
        }

        if (score >= 50) {
          _tickOrb(
              refShow: () => showSlowdownOrb,
              setShow: (v) => showSlowdownOrb = v,
              x: () => slowX,
              setX: (v) => slowX = v,
              y: () => slowY,
              minScore: 50,
              spawnProb: 0.003);
        }
        if (score >= 70) {
          _tickOrb(
              refShow: () => showSafeZoneOrb,
              setShow: (v) => showSafeZoneOrb = v,
              x: () => safeX,
              setX: (v) => safeX = v,
              y: () => safeY,
              minScore: 70,
              spawnProb: 0.003);
        }
        if (score >= 80) {
          _tickOrb(
              refShow: () => showDoubleShieldOrb,
              setShow: (v) => showDoubleShieldOrb = v,
              x: () => dShieldX,
              setX: (v) => dShieldX,
              y: () => dShieldY,
              minScore: 80,
              spawnProb: 0.0025);
        }

        // orb collisions
        _collectIfOverlap(s, showScoreBoostOrb, scoreBoostX, scoreBoostY, () {
          showScoreBoostOrb = false;
          _activateScoreBoost();
        });
        _collectIfOverlap(s, showShieldOrb, shieldX, shieldY, () {
          showShieldOrb = false;
          shields = (shields + 1).clamp(0, 3);
        });
        _collectIfOverlap(s, showSlowdownOrb, slowX, slowY, () {
          showSlowdownOrb = false;
          _activateSlowdown();
        });
        _collectIfOverlap(s, showSafeZoneOrb, safeX, safeY, () {
          showSafeZoneOrb = false;
          _activateSafeZone();
        });
        _collectIfOverlap(s, showDoubleShieldOrb, dShieldX, dShieldY, () {
          showDoubleShieldOrb = false;
          _activateDoubleShieldSlow();
        });
      });
    });
  }

  void _endGame() {
    gameOver = true;
    _gameLoop?.cancel();

    _updateHighScore();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => GameOverScreen(
          score: score,
          highScore: highScore,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  void _reset() {
    _gameLoop?.cancel();
    _scoreBoostTimer?.cancel();
    _slowdownTimer?.cancel();
    _safeZoneTimer?.cancel();
    _doubleShieldTimer?.cancel();
    _redPauseTimer?.cancel();
    _invTimer?.cancel();
    scoreMultiplier = 1;
    invincible = false;
    shields = 0;
    slowdownActive = false;
    safeZoneActive = false;
    redObstaclePaused = false;
    showScoreBoostOrb = showShieldOrb = showSlowdownOrb = false;
    showSafeZoneOrb = showDoubleShieldOrb = false;
    _startGame();
  }

  // =========================
  // Mechanics
  // =========================
  void _hitOrDie() {
    // If invincible or shield, bounce; otherwise die and reset streak
    if (invincible) {
      // bounce back
      playerY = 0;
      velocity = 0;
      return;
    }
    if (shields > 0) {
      shields--;
      playerY = 0;
      velocity = 0;
      return;
    }

    // actual death -> reset streak and end game
    scoreStreak = 0;
    streakProgress = 0.0;
    showStreakIndicator = false;
    _endGame();
  }

  void _scorePoint() {
    // difficulty scaling
    score += (scoreMultiplier); // multiplier from booster/invincible
    if (score > 0 && score % 20 == 0) {
      level++;
      // Slightly harder jump curve & faster world
      gravity += 0.00012;
      liftForce -= 0.00035;
      baseObstacleSpeed = (baseObstacleSpeed + 0.0007).clamp(0.010, 0.032);
    }

    // narrower scoring obstacle with score
    if (score >= 30) {
      final reduce = (score - 30) * 0.9; // gently narrow
      obstacleWidth = (100 - reduce).clamp(40, 100);
    }

    // streak logic (only when not invincible/safe)
    if (!invincible && !safeZoneActive) {
      if (score > 20) {
        scoreStreak++;
        streakProgress = (scoreStreak / _streakNeeded).clamp(0.0, 1.0);
        showStreakIndicator = true;
      }
      if (scoreStreak >= _streakNeeded) {
        _activateRedPause(); // pause dangerous for 10s
        scoreStreak = 0;
        streakProgress = 0;
      }
    }

    // theme change + invincible every 50
    if (score > 0 && score % _invincibleEvery == 0) {
      _advanceTheme();
      _activateInvincible(); // 10s, double score
    }
  }

  void _advanceTheme() {
    _themeIndex = (_themeIndex + 1) % _themes.length;
    _themeCtrl
      ..reset()
      ..forward();
  }

  void _activateInvincible() {
    invincible = true;
    scoreMultiplier = 2;
    _invTimer?.cancel();
    _invTimer = Timer(const Duration(seconds: _invincibleDuration), () {
      invincible = false;
      scoreMultiplier = (_scoreBoostTimer?.isActive ?? false) ? 2 : 1;
      setState(() {});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✨ Invincible for 10s — Double Score!"),
        duration: Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  void _activateScoreBoost() {
    scoreMultiplier = 2;
    _scoreBoostTimer?.cancel();
    _scoreBoostTimer = Timer(const Duration(seconds: _scoreBoostSeconds), () {
      // if invincible is still active, keep 2x; else revert to 1x
      scoreMultiplier = invincible ? 2 : 1;
      setState(() {});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🟣 Score Booster: 2x for 5s")),
    );
    setState(() {});
  }

  void _activateRedPause() {
    redObstaclePaused = true;
    _redPauseTimer?.cancel();
    _redPauseTimer = Timer(const Duration(seconds: _redPauseSeconds), () {
      redObstaclePaused = false;
      setState(() {});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🔥 Streak! Danger paused for 10s")),
    );
    setState(() {});
  }

  void _activateSlowdown() {
    slowdownActive = true;
    _slowdownTimer?.cancel();
    _slowdownTimer = Timer(const Duration(seconds: _slowdownSeconds), () {
      slowdownActive = false;
      setState(() {});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❄️ Dangerous slowed")),
    );
    setState(() {});
  }

  void _activateSafeZone() {
    safeZoneActive = true;
    showDanger = false;
    _safeZoneTimer?.cancel();
    _safeZoneTimer = Timer(const Duration(seconds: _safeZoneSeconds), () {
      safeZoneActive = false;
      setState(() {});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🟡 Safe Zone: only score blocks for 10s")),
    );
    setState(() {});
  }

  void _activateDoubleShieldSlow() {
    shields = (shields + 2).clamp(0, 5);
    slowdownActive = true;
    _doubleShieldTimer?.cancel();
    _doubleShieldTimer =
        Timer(const Duration(seconds: _doubleShieldSeconds), () {
      slowdownActive = false;
      setState(() {});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🟠 Double Shield + Slowdown for 10s")),
    );
    setState(() {});
  }

  // =========================
  // Spawning
  // =========================
  void _spawnScoreBlock() {
    obstacleX = 1.25;
    hasCollided = false;

    // height logic
    if (score < 10) {
      obstacleHeight = 120;
    } else {
      obstacleHeight = 80 + _rng.nextInt(90).toDouble();
    }

    // 🚨 if streak pause active → always show score block, never danger
    if (redObstaclePaused) {
      showGroundDanger = false;
      showObstacle = true;
      scoreBlockColor = const Color(0xFFB3F2FF);
      return;
    }

    // Otherwise, normal spawn chance (danger or score)
    if (score > 15 && _rng.nextDouble() < 0.25) {
      showGroundDanger = true;
      showObstacle = false;
      groundDangerX = 1.25;
      groundDangerWidth = obstacleWidth;
      groundDangerHeight = obstacleHeight;
    } else {
      showGroundDanger = false;
      showObstacle = true;
      scoreBlockColor = const Color(0xFFB3F2FF);
    }
  }

  void _spawnDanger() {
    dangerX = 1.25;
    if (score <= 25) {
      dangerY = _rng.nextBool() ? -0.4 : 0.38;
    } else {
      // a bit more random later
      dangerY = (_rng.nextInt(5) - 2) * 0.25; // -0.5..0.5 steps
    }
    dangerSize = 56;
    showDanger = true;
  }

  // generic orb tick — move left & spawn chance
  void _tickOrb({
    required bool Function() refShow,
    required void Function(bool) setShow,
    required double Function() x,
    required void Function(double) setX,
    required double Function() y,
    required int minScore,
    required double spawnProb,
  }) {
    if (!refShow()) {
      if (score >= minScore && _rng.nextDouble() < spawnProb) {
        setX(2.35);
        // spawn somewhere in vertical game space
        final yy = _rng.nextDouble() * 1.3 - 0.65;
        // clip inside play zone
        setState(() {
          setShow(true);
          // assign y via closure param — workaround since y is getter-only
          if (y == scoreBoostY) {
            scoreBoostY = yy;
          } else if (y == shieldY) {
            shieldY = yy;
          } else if (y == slowY) {
            slowY = yy;
          } else if (y == safeY) {
            safeY = yy;
          } else if (y == dShieldY) {
            dShieldY = yy;
          }
        });
      }
    } else {
      // move left
      setX(x() - _currentSpeed());
      if (x() < -1.25) setShow(false);
    }
  }

  void _collectIfOverlap(
      Size s, bool visible, double nx, double ny, VoidCallback onCollect) {
    if (!visible) return;
    final pr = _playerRect(s);
    final or = _orbRect(s, nx, ny, 0.06);
    if (pr.overlaps(or)) onCollect();
  }

  double _currentSpeed() {
    // speed scales with score softly
    // final add = (score / 1200).clamp(0.0, 0.025); // gentle ramp
    final add = (score / 2000).clamp(0.0, 0.015);

    return (baseObstacleSpeed + add);
  }

  // =========================
  // Input
  // =========================
  void _tap() {
    if (gameOver) return;
    if (!gameStarted) {
      _startGame();
    }
    velocity = liftForce;
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final themeA = _themes[_themeIndex];
    final themeB = _themes[(_themeIndex + 1) % _themes.length];

    return GestureDetector(
      onTap: _tap,
      child: Scaffold(
        body: Stack(
          children: [
            // Base gradient
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: themeA,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // “Video-like” overlay: moving radial/sweeping highlights
            AnimatedBuilder(
              animation: _bgMotionCtrl,
              builder: (_, __) {
                final t = _bgMotionCtrl.value;
                return Opacity(
                  opacity: 0.55,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: SweepGradient(
                        colors: [
                          Colors.white.withOpacity(0.03),
                          Colors.transparent,
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                        ],
                        startAngle: t * 2 * pi,
                        endAngle: t * 2 * pi + pi * 2,
                        center: Alignment(0.0, -0.2),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Theme transition layer (crossfade to next theme)
            FadeTransition(
              opacity: _themeCtrl.drive(CurveTween(curve: Curves.easeInOut)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeB,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Star/particle field (subtle)
            IgnorePointer(child: _Stars(active: true)),

            // Game world
            SafeArea(
              child: Stack(
                children: [
                  // Top bar HUD
                  Positioned(
                    top: 10,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white24),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8)
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.emoji_events,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text("High Score",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(highScore.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (shields > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Row(
                                  children: List.generate(
                                    shields,
                                    (i) => const Icon(Icons.shield,
                                        size: 18, color: Colors.cyanAccent),
                                  ),
                                ),
                              ),
                            _PillStat(
                              icon: Icons.star_rounded,
                              label: "Score",
                              value:
                                  "$score${scoreMultiplier == 2 ? " ×2" : ""}",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Player (with invincible glow)
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 0),
                    alignment: Alignment(0, playerY),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // NEW: The animated, pulsing shield widget
                        if (invincible)
                          AnimatedBuilder(
                            animation: _shieldPulseController,
                            builder: (context, child) {
                              final scale = Tween<double>(begin: 1.0, end: 1.25)
                                  .evaluate(_shieldPulseController);
                              final opacity =
                                  Tween<double>(begin: 0.0, end: 0.8)
                                      .evaluate(CurvedAnimation(
                                parent: _shieldPulseController,
                                curve: const Interval(0.0, 0.5,
                                    curve: Curves.easeOut),
                              ));

                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Inner solid glow
                                  Container(
                                    width: _playerSize * 2.2,
                                    height: _playerSize * 2.2,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.blueAccent.withOpacity(0.5),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                  // Outer, pulsing ring
                                  Transform.scale(
                                    scale: scale,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: Container(
                                        width: _playerSize * 2.4,
                                        height: _playerSize * 2.4,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Colors.cyanAccent
                                                  .withOpacity(0.7),
                                              Colors.transparent,
                                            ],
                                            stops: const [0.1, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        // Your Player sphere (moved inside the Stack to be a sibling of the shield)
                        Container(
                            width: _playerSize,
                            height: _playerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: invincible
                                    ? [Colors.amberAccent, Colors.orangeAccent]
                                    : [
                                        const Color(
                                            0xFF4F2B10), // Deep Reddish-Brown
                                        const Color(
                                            0xFFFF9900) // Luminous Orange
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: invincible
                                      ? Colors.amberAccent.withOpacity(0.7)
                                      : const Color(0xFFFF6600).withOpacity(
                                          0.5), // Molten Orange Shadow
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                )
                              ],
                            )),
                        Container(
                          width: _playerSize,
                          height: _playerSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: invincible
                                  ? [Colors.amberAccent, Colors.orangeAccent]
                                  : [
                                      const Color.fromARGB(255, 208, 199,
                                          126), // Dark Slate Blue
                                      const Color.fromARGB(
                                          255, 118, 117, 84) // Soft Lavender
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: invincible
                                    ? Colors.amberAccent.withOpacity(0.7)
                                    : const Color(0xFF4B0082)
                                        .withOpacity(0.5), // Deep Purple Shadow
                                blurRadius: 22,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  // Score block (neon pillar)
                  if (showObstacle)
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 0),
                      alignment: Alignment(obstacleX, 1.0),
                      child: _NeonPillar(
                          width: obstacleWidth,
                          height: obstacleHeight,
                          color: scoreBlockColor),
                    ),
                  if (showGroundDanger)
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 0),
                      alignment: Alignment(groundDangerX, 1.0),
                      child: _NeonPillar(
                        width: groundDangerWidth,
                        height: groundDangerHeight,
                        color: Colors.redAccent, // 🔴 red danger
                      ),
                    ),

                  // Dangerous block
                  if (showDanger)
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 0),
                      alignment: Alignment(dangerX, dangerY),
                      child: _DangerImage(size: dangerSize),
                    ),

                  // Power-up orbs
                  if (showScoreBoostOrb)
                    _Orb(
                        x: scoreBoostX,
                        y: scoreBoostY,
                        gradient: const [Color(0xFF8A2BE2), Color(0xFFB490FF)],
                        icon: Icons.exposure_plus_2),
                  if (showShieldOrb)
                    _Orb(
                        x: shieldX,
                        y: shieldY,
                        gradient: const [Colors.cyanAccent, Color(0xFF1166FF)],
                        icon: Icons.shield),
                  if (showSlowdownOrb)
                    _Orb(
                        x: slowX,
                        y: slowY,
                        gradient: const [Color(0xFFB9F2FF), Color(0xFF5EC5FF)],
                        icon: Icons.slow_motion_video),
                  if (showSafeZoneOrb)
                    _Orb(
                        x: safeX,
                        y: safeY,
                        gradient: const [Color(0xFFFFE28A), Color(0xFFFFB300)],
                        icon: Icons.security),
                  if (showDoubleShieldOrb)
                    _Orb(
                        x: dShieldX,
                        y: dShieldY,
                        gradient: const [Color(0xFFFFA36C), Color(0xFFFF5E62)],
                        icon: Icons.shield_moon),

                  // Streak indicator (left)
                  if (showStreakIndicator)
                    Positioned(
                      left: 16,
                      top: 64,
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: streakProgress,
                              strokeWidth: 5,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.deepOrangeAccent),
                              backgroundColor: Colors.white24,
                            ),
                            Text(
                                '${(streakProgress * _streakNeeded).round()}/$_streakNeeded',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    ),

                  // Debug switch
                  // Positioned(
                  //   top: 10,
                  //   left: 16,
                  //   child: IconButton(
                  //     icon: Icon(
                  //         debugMode ? Icons.visibility_off : Icons.bug_report,
                  //         color: Colors.redAccent),
                  //     onPressed: () => setState(() => debugMode = !debugMode),
                  //   ),
                  // ),

                  if (debugMode)
                    Positioned(
                      top: 56,
                      left: 16,
                      child: Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => setState(() => score += 1),
                            child: const Text("+1"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => setState(() {
                              score += 10;
                              _advanceTheme();
                              _activateInvincible();
                            }),
                            child: const Text("+10 & inv"),
                          ),
                        ],
                      ),
                    ),

                  // Game over overlay
                  // if (gameOver)
                  //   Center(
                  //     child: Column(
                  //       mainAxisSize: MainAxisSize.min,
                  //       children: [
                  //         const Text("Game Over",
                  //             style: TextStyle(
                  //                 fontSize: 32,
                  //                 fontWeight: FontWeight.bold,
                  //                 color: Colors.white)),
                  //         const SizedBox(height: 12),
                  //         Text("Score: $score",
                  //             style: const TextStyle(color: Colors.white70)),
                  //         const SizedBox(height: 24),
                  //         ElevatedButton(
                  //           onPressed: _reset,
                  //           style: ElevatedButton.styleFrom(
                  //               backgroundColor: Colors.white,
                  //               foregroundColor: Colors.black87),
                  //           child: const Text("Restart"),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  if (!gameStarted && !gameOver)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 200),
                        child: Text(
                          "TAP TO START",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9),
                            shadows: [
                              Shadow(
                                offset: Offset(2, 2),
                                blurRadius: 6,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// UI Pieces
// =========================

class _PillStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PillStat(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

class _GlowRing extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowRing({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color, Colors.transparent], stops: const [0.2, 1.0]),
      ),
    );
  }
}

class _NeonPillar extends StatelessWidget {
  final double width, height;
  final Color color;
  const _NeonPillar(
      {required this.width, required this.height, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.95), color.withOpacity(0.55)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.7),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// class _DangerCrystal extends StatelessWidget {
//   final double size;
//   const _DangerCrystal({required this.size});
//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       size: Size(size, size),
//       painter: _CrystalPainter(),
//     );
//   }
// }
class _DangerImage extends StatelessWidget {
  final double size;
  const _DangerImage({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/danger_obstacle.png',
      // color: Colors.redAccent,
      // colorBlendMode: BlendMode.srcATop,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

// class _CrystalPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final r = Rect.fromLTWH(0, 0, size.width, size.height);
//     final path = Path()
//       ..moveTo(r.center.dx, 0)
//       ..lineTo(r.width, r.height * .35)
//       ..lineTo(r.center.dx, r.height)
//       ..lineTo(0, r.height * .35)
//       ..close();

//     final paint = Paint()
//       ..shader = const LinearGradient(
//         colors: [Color(0xFF5319A6), Color(0xFF2A0E57)],
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//       ).createShader(r)
//       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

//     final edge = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2
//       ..color = Colors.white.withOpacity(0.25);

//     canvas.drawPath(path, paint);
//     canvas.drawPath(path, edge);
//     canvas.drawShadow(path, Colors.black, 6, true);
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

class _Orb extends StatelessWidget {
  final double x, y;
  final List<Color> gradient;
  final IconData icon;
  const _Orb(
      {required this.x,
      required this.y,
      required this.gradient,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.1;
    return AnimatedAlign(
      duration: const Duration(milliseconds: 0),
      alignment: Alignment(x, y),
      child: Container(
        width: w,
        height: w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(
                color: gradient.last.withOpacity(0.7),
                blurRadius: 12,
                spreadRadius: 1)
          ],
        ),
        child: Center(
          child: Icon(icon, size: w * 0.76, color: Colors.white),
        ),
      ),
    );
  }
}

class _Stars extends StatefulWidget {
  final bool active;
  const _Stars({required this.active});
  @override
  State<_Stars> createState() => _StarsState();
}

class _StarsState extends State<_Stars> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late List<Offset> pts;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    pts =
        List.generate(28, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _StarsPainter(pts, _c.value),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  final List<Offset> pts;
  final double t;
  _StarsPainter(this.pts, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.6);
    for (final o in pts) {
      final x = o.dx * size.width;
      final y = o.dy * size.height;
      final r = 1.2 + 2.2 * sin(t * 2 * pi);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum Power { scoreBoost, shield, slowdown, safeZone, doubleShield }
