import 'package:flutter/material.dart';
import 'package:flutter_camera/flutter_camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:helping_hands/url.dart';

class Camera extends StatefulWidget {
  const Camera({
    super.key,
    required this.onProgress,
    required this.onResponse,
  });

  final Function(bool) onProgress;
  final Function(String) onResponse;

  @override
  _CameraState createState() => _CameraState();
}

class _CameraState extends State<Camera> {
  Future<void> sendVideoToBackend(String filePath) async {
    const url = '${Config.url}:5000/chat';

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        print('Video sent to backend successfully');
        final responseBody = await response.stream.bytesToString();
        print('Response from backend: $responseBody');
        final Map<String, dynamic> responseJson = json.decode(responseBody);

        var text = responseJson['message'];
        widget.onResponse(text);
      } else {
        print('Failed to send video. Status code: ${response.statusCode}');
      }
    } finally {
      widget.onProgress(false);
    }
  }

  Future<void> showConfirmationDialog(String path) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Do you want to upload the selected video?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                widget.onProgress(true);
                sendVideoToBackend(path);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Analysing. Please wait...'),
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterCamera(
      color: Colors.grey.shade300,
      onImageCaptured: (value) {
        final imagePath = value.path;
        print("Image Path: $imagePath");

      
      },
      onVideoRecorded: (value) async {
        final videoPath = value.path;
        print('Video Path: $videoPath');

        await showConfirmationDialog(videoPath);
      },
    );
  }
}
