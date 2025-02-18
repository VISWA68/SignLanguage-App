import 'dart:ui';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helping_hands/realtime.dart';
import 'package:helping_hands/signbot.dart';
import 'package:helping_hands/test.dart';
import 'package:helping_hands/url.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'video_player.dart';
import 'package:lottie/lottie.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isLoading = false;
  PlatformFile? pickedFile;

  Future<void> selectFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) {
      return;
    }
    showConfirmationDialog();
    setState(() {
      pickedFile = result.files.first;
    });
  }

  Future<void> sendVideoToBackend(File videoFile) async {
    final navigator = Navigator.of(context);
    const url = '${Config.url}:3000/video_sign';

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..files.add(await http.MultipartFile.fromPath('video', videoFile.path));

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/final_combined_video.mp4';
        final file = File(filePath);

        await response.stream.pipe(file.openWrite());

        final videoUrl = await uploadVideoToFirebase(file);

        await storeVideoUrlInFirestore(videoUrl);

        navigator.push(
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              vidurl: filePath,
            ),
          ),
        );
      } else {
        print(
            'Failed to send video to backend. Status code: ${response.statusCode}');
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String> uploadVideoToFirebase(File videoFile) async {
    final storageRef = FirebaseStorage.instance.ref();
    final videoRef =
        storageRef.child('videos/${videoFile.uri.pathSegments.last}');
    final uploadTask = videoRef.putFile(videoFile);

    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> storeVideoUrlInFirestore(String videoUrl) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('videos').add({
      'final_video_url': videoUrl,
    });
  }

  Future<void> uploadFile() async {
    if (pickedFile == null) {
      return;
    }

    final file = File(pickedFile!.path!);

    setState(() {
      isLoading = true;
    });

    try {
      await sendVideoToBackend(file);
    } catch (e) {
      print('Error uploading file: $e');
    }
  }

  Future<void> showConfirmationDialog() async {
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
                uploadFile();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating Sign Language. Please wait...'),
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
    return Scaffold(
      drawer: _buildDrawer(),
      key: _scaffoldKey,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {},
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.menu,
            color: Colors.black87,
          ),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 240, 238, 238),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeader(),
                  const SizedBox(
                    height: 20,
                  ),
                  _buildContent(),
                ],
              ),
            ),
            if (isLoading)
              Stack(
                children: [
                  // Blurred Background
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Container(
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                  // Centered Loading Animation
                  Center(
                    child: Lottie.asset('asset/animations/loading.json'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 250,
      backgroundColor: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            height: 150,
            width: 250,
            decoration: BoxDecoration(color: Colors.grey.shade500),
          ),
          ListTile(
            horizontalTitleGap: 20,
            leading: const Icon(Icons.message),
            title: const Text("Sign Translate"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => RealTime()));
            },
          ),
          const SizedBox(
            height: 10,
          ),
          ListTile(
            horizontalTitleGap: 20,
            leading: const Icon(Icons.message),
            title: const Text("Sign Bot"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SignBot()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 191, 188, 188),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Welcome to',
            style: TextStyle(color: Colors.black87, fontSize: 25),
          ),
          SizedBox(height: 5),
          Text(
            'Helping Hands',
            style: TextStyle(
              color: Colors.black,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Shaping signs Building Bridges',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Our Features',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Container(
            height: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                promoCard('asset/images/four.jpg'),
                promoCard('asset/images/three.jpg'),
                promoCard('asset/images/two.jpg'),
                promoCard('asset/images/one.jpg'),
              ],
            ),
          ),
          const SizedBox(height: 35),
          const Text(
            "Generate sign language for videos",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Center(
            child: Column(
              children: [
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    selectFile();
                  },
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text("Upload Video"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget promoCard(image) {
    return AspectRatio(
      aspectRatio: 2.62 / 3,
      child: Container(
        margin: const EdgeInsets.only(right: 15.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(fit: BoxFit.cover, image: AssetImage(image)),
        ),
      ),
    );
  }
}
