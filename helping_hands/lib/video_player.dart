import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String vidurl;

  const VideoPlayerScreen({super.key, required this.vidurl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  bool _isControllerInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideoController();
  }

  Future<void> _initVideoController() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.vidurl));

      await _controller.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: true,
        aspectRatio: 16 / 9,
      );

      setState(() {
        _isControllerInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      print('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "VIDEO PLAYER",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey.shade300,
        centerTitle: true,
      ),
      body: _hasError
          ? const Center(
              child: Text(
                'Error loading video. Please try again later.',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            )
          : _isControllerInitialized
              ? Center(
                  child: Chewie(
                    controller: _chewieController!,
                  ),
                )
              : Center(
                  child: Lottie.asset('asset/animations/loading.json'),
                ),
    );
  }
}
