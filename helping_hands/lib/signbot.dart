import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:helping_hands/camera.dart';
import 'package:helping_hands/url.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

class SignBot extends StatefulWidget {
  const SignBot({super.key});

  @override
  State<SignBot> createState() => _SignBotState();
}

class _SignBotState extends State<SignBot> {
  bool isLoading = false;
  var url = "";
  var _text = "";
  VideoPlayerController? _videoController;
  bool _isRequestInProgress = false;
  final apiKey = 'AIzaSyBtMdFsAHQmcYLZ_A-guBukyF-lK1zsy8k';

  final String serverUrl = '${Config.url}:8080/text';

  final List<Map<String, String>> messages = []; 

  @override
  void initState() {
    super.initState();
    _initializeStandVideo();
  }

  void _initializeStandVideo() {
    _videoController = VideoPlayerController.asset('assets1/stand.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController?.setLooping(true);
        _videoController?.play();
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<String> _getResponse(String text) async {
    setState(() {
      isLoading = true;
    });
    try {
      final model = GenerativeModel(
        apiKey: apiKey,
        model: 'gemini-1.5-flash-latest',
      );

      final prompt = '$text (give response without any special characters)';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text?.trim() ?? 'Translation failed';
    } finally {
      _isRequestInProgress = false;
    }
  }

  Future<void> _sendTextToServer(String text) async {
    setState(() {
      isLoading = true;
    });
    if (_isRequestInProgress) return;

    setState(() {
      isLoading = true;
      _isRequestInProgress = true;
    });

    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final Uint8List videoData = response.bodyBytes;
        _playReceivedVideo(videoData);
      } else {
        print('Failed to get video from server: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending request: $e');
    } finally {
      setState(() {
        isLoading = false;
        _isRequestInProgress = false;
      });
    }
  }

  void _playReceivedVideo(Uint8List videoData) async {
    const videoFilePath = '/sdcard/Download/received_video.mp4';

    final videoFile = File(videoFilePath);
    await videoFile.writeAsBytes(videoData);

    _videoController?.dispose();
    _videoController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        setState(() {});
        _videoController?.play();
        _videoController?.addListener(_onReceivedVideoEnd);
      }).catchError((error) {
        print("Error loading video: $error");
        _initializeStandVideo();
      });
  }

  void _onReceivedVideoEnd() {
    if (_videoController != null &&
        _videoController!.value.position == _videoController!.value.duration) {
      _videoController?.removeListener(_onReceivedVideoEnd);
      _initializeStandVideo();
    }
  }

  void _addMessage(String message, String sender) {
    setState(() {
      messages.add({'text': message, 'sender': sender});
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade400,
        title: const Text("SignBot"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Video Player
            _videoController != null && _videoController!.value.isInitialized
                ? SizedBox(
                    height: 200,
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            if (messages.isEmpty)
              const Center(
                child: Text("No Messages"),
              ),
            // Chat Interface - Scrollable
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isUser = message['sender'] == 'user';

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 250),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Colors.blue.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        message['text'] ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Loading Animation
            if (isLoading)
              Center(
                child: Lottie.asset('asset/animations/loading.json'),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          color: Colors.grey.shade500,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2.0,
              ),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Camera(
                      onProgress: (progress) {
                        setState(() {
                          isLoading = progress;
                        });
                      },
                      onResponse: (responseText) async {
                        setState(() {
                          _text = responseText;
                        });
                        _addMessage(_text,
                            'user'); 
                        var res = await _getResponse(_text);
                        var r = res.toLowerCase();
                        _addMessage(
                            res, 'bot');
                        _sendTextToServer(r); 
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.camera_alt_outlined,
                size: 30,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
