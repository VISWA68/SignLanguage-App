import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:helping_hands/camera.dart';
import 'package:helping_hands/url.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

class RealTime1 extends StatefulWidget {
  const RealTime1({super.key});

  @override
  _SignLanguageScreenState createState() => _SignLanguageScreenState();
}

class _SignLanguageScreenState extends State<RealTime1> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isRequestInProgress = false;
  String _recognizedText = '';
  String _translatedText = '';
  String _translatedTextFromEnglish = '';
  VideoPlayerController? _videoController;
  final TextEditingController _textController = TextEditingController();
  Timer? _autoStopTimer;
  bool isLoading = false;
  var _text;
  late FlutterTts _flutterTts;
  String _selectedLanguage = 'English';

  final apiKey = 'AIzaSyBtMdFsAHQmcYLZ_A-guBukyF-lK1zsy8k';
  final String serverUrl = '${Config.url}:8080/text';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
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
    _textController.dispose();
    _autoStopTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });

      String localeId = _getLocaleForLanguage(_selectedLanguage);

      _speech.listen(
        localeId: localeId,
        onResult: (val) async {
          if (_isRequestInProgress) return;

          String recognizedWords = val.recognizedWords;

          if (recognizedWords.isNotEmpty) {
            setState(() {
              _recognizedText = recognizedWords;
            });

            if (_selectedLanguage != 'English') {
              var translated =
                  await _translateText(_recognizedText, _selectedLanguage);
              setState(() {
                _translatedText = translated.toLowerCase();
              });
            }
          }

          _resetAutoStopTimer();
        },
        listenMode: stt.ListenMode.dictation,
        pauseFor: const Duration(seconds: 2),
      );

      _startAutoStopTimer();
    }
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
    });

    _speech.stop();
    _autoStopTimer?.cancel();

    if (_selectedLanguage != 'English') {
      _sendTextToServer(_translatedText);
    } else {
      _sendTextToServer(_recognizedText);
    }
  }

  void _startAutoStopTimer() {
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening) {
        _stopListening();
      }
    });
  }

  void _resetAutoStopTimer() {
    _autoStopTimer?.cancel();
    _startAutoStopTimer();
  }

  void _handleTextSubmission() {
    if (_isRequestInProgress) return;

    String text = _textController.text.toLowerCase();
    _textController.clear();
    setState(() {
      _recognizedText = text;
    });
    _sendTextToServer(_recognizedText);
  }

  void _speakText(String text) async {
    await _flutterTts.setLanguage(_selectedLanguage);
    await _flutterTts.speak(text);
  }

  Future<String> _translateText(String text, String targetLanguage) async {
    try {
      final model = GenerativeModel(
        apiKey: apiKey,
        model: 'gemini-1.5-flash-latest',
      );

      final prompt =
          'Translate the following sentence fully from $targetLanguage to English: "$text". Give me only the translated sentence without any special characters and question marks.';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text?.trim() ?? 'Translation failed';
    } finally {
      _isRequestInProgress = false;
    }
  }

  Future<String> _translateTexttoEnglish(
      String text, String targetLanguage) async {
    try {
      final model = GenerativeModel(
        apiKey: apiKey,
        model: 'gemini-1.5-pro',
      );

      final prompt =
          'Translate the following sentence fully from English to $targetLanguage: "$text". Give me only the translated sentence in the translated language without any special characters and question marks.';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text?.trim() ?? 'Translation failed';
    } finally {
      _isRequestInProgress = false;
    }
  }

  Future<void> _sendTextToServer(String text) async {
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

  String _getLocaleForLanguage(String language) {
    switch (language) {
      case 'Tamil':
        return 'ta_IN';
      case 'Hindi':
        return 'hi_IN';
      case 'Malayalam':
        return 'ml_IN';
      case 'Kannada':
        return 'kn_IN';
      case 'Telugu':
        return 'te_IN';
      default:
        return 'en_US';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HELPING HANDS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade400,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  break;
                case 'about':
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Settings'),
                ),
                const PopupMenuItem<String>(
                  value: 'about',
                  child: Text('About'),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 40),
                  _videoController != null &&
                          _videoController!.value.isInitialized
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
                  const SizedBox(height: 20),
                  _buildRecognizedTextBox(),
                  const SizedBox(height: 15),
                  _buildControlButtons(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type something...',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _handleTextSubmission,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onSubmitted: (value) => _handleTextSubmission(),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: const Color(0xFFF5F5DC),
                      elevation: 15,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: _text != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Recognized text: $_translatedTextFromEnglish",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        
                                        color: Color(0xFF36454F),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up),
                                    color: const Color(0xFF008080),
                                    onPressed: () =>
                                        _speakText(_translatedTextFromEnglish),
                                  ),
                                ],
                              )
                            : const Text(
                                "Record to generate text from Sign Language",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF36454F),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                        if (_selectedLanguage != 'English') {
                          var translated = await _translateTexttoEnglish(
                              _text, _selectedLanguage);
                          setState(() {
                            _translatedTextFromEnglish =
                                translated.toLowerCase();
                            isLoading = false;
                          });
                        } else {
                          setState(() {
                            _translatedTextFromEnglish = _text;
                            isLoading = false;
                          });
                        }
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

  Widget _buildRecognizedTextBox() {
    final displayText = _recognizedText;

    if (displayText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        displayText,
        style: const TextStyle(fontSize: 20),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100, iconColor: Colors.black),
          onPressed: _isListening ? _stopListening : _startListening,
          label: Text(
            _isListening ? "Listening..." : "Speak",
            style: const TextStyle(color: Colors.black),
          ),
          icon: const Icon(Icons.mic),
        ),
        const SizedBox(width: 20),
        _buildLanguageButton()
      ],
    );
  }

  Widget _buildLanguageButton() {
    return ElevatedButton(
      onPressed: () {
        showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Select Language'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildLanguageOption('English'),
                  _buildLanguageOption('Tamil'),
                  _buildLanguageOption('Hindi'),
                  _buildLanguageOption('Malayalam'),
                  _buildLanguageOption('Kannada'),
                  _buildLanguageOption('Telugu'),
                ],
              ),
            );
          },
        );
      },
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        backgroundColor: Colors.grey.shade100,
      ),
      child: Text(
        _selectedLanguage,
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    return RadioListTile<String>(
      title: Text(language),
      value: language,
      groupValue: _selectedLanguage,
      onChanged: (String? value) {
        setState(() {
          _selectedLanguage = value!;
        });
        Navigator.of(context).pop();
      },
    );
  }
}
