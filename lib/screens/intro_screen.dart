import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dashboard_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late VideoPlayerController _controller;
  final AudioPlayer _audioFocusTrigger = AudioPlayer();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  Future<void> _initVideo() async {
    await _audioFocusTrigger.setReleaseMode(ReleaseMode.stop);
    await _audioFocusTrigger.setVolume(0.0);
    await _audioFocusTrigger.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.gain,
          usageType: AndroidUsageType.media,
          contentType: AndroidContentType.movie,
          isSpeakerphoneOn: false,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );

    _controller = VideoPlayerController.asset('assets/video/intro.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.setLooping(false);
          _controller.setVolume(1.0);
          _controller.play();
        }
      });

    _controller.addListener(() {
      if (_controller.value.isInitialized &&
          !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration) {
        _goToDashboard();
      }
    });
  }

  void _goToDashboard() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    _audioFocusTrigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _goToDashboard,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video cover: fit width layar, height ikut aspect ratio, crop kalau overflow
              if (_initialized)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final screenW = constraints.maxWidth;
                    final screenH = constraints.maxHeight;
                    final videoRatio = _controller.value.aspectRatio;

                    // Fit ke lebar layar, height mengikuti rasio video
                    final videoW = screenW;
                    final videoH = screenW / videoRatio;

                    return ClipRect(
                      child: SizedBox(
                        width: screenW,
                        height: screenH,
                        child: OverflowBox(
                          maxWidth: videoW,
                          maxHeight: videoH,
                          child: SizedBox(
                            width: videoW,
                            height: videoH,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                    );
                  },
                )
              else
                const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

              // Bottom gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Text overlay
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'PEGASUS-X',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Deltha',
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 6,
                        shadows: [
                          Shadow(
                            color: Colors.blue.withOpacity(0.9),
                            blurRadius: 24,
                          ),
                          Shadow(
                            color: Colors.blue.withOpacity(0.5),
                            blurRadius: 48,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'R E V E N G E',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade300,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(
                            color: Colors.blue.withOpacity(0.7),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tap To Skip',
                      style: TextStyle(
                        fontFamily: 'ShareTechMono',
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
