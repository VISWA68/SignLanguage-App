import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart'; 
import 'video_player.dart';

class MyVideos extends StatefulWidget {
  const MyVideos({super.key});

  @override
  State<MyVideos> createState() => _MyVideosState();
}

class _MyVideosState extends State<MyVideos> {
  late FirebaseFirestore firestore;

  @override
  void initState() {
    super.initState();
    firestore = FirebaseFirestore.instance; 
  }

  Future<String?> getVideoThumbnail(String videoUrl) async {
    final tempDir = await getTemporaryDirectory();
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoUrl,
      thumbnailPath: tempDir.path,
      imageFormat: ImageFormat.PNG,
      maxHeight: 64, 
    );
    return thumbnailPath;
  }

  Future<void> deleteVideo(String documentId, String videoUrl) async {
    try {
      await firestore.collection('videos').doc(documentId).delete();

      Reference videoRef = FirebaseStorage.instance.refFromURL(videoUrl);

      await videoRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete video: $e')),
      );
    }
  }

  Widget shimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        width: double.infinity,
        height: 100,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget video(String thumbnailPath, String videoUrl, String documentId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(vidurl: videoUrl),
          ),
        );
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Video'),
              content:
                  const Text('Are you sure you want to delete this video?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    deleteVideo(documentId, videoUrl);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.grey.shade200,
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(thumbnailPath)),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade400,
        title: const Text(
          "MY VIDEOS",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('videos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading videos'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No videos found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var videoData =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var videoUrl = videoData['final_video_url'];
              var documentId = snapshot.data!.docs[index].id;

              return FutureBuilder<String?>(
                future: getVideoThumbnail(videoUrl),
                builder: (context, thumbnailSnapshot) {
                  if (thumbnailSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return shimmerEffect(); 
                  }
                  if (thumbnailSnapshot.hasError ||
                      !thumbnailSnapshot.hasData) {
                    return const Center(child: Text('Error loading thumbnail'));
                  }

                  var thumbnailPath = thumbnailSnapshot.data!;
                  return video(thumbnailPath, videoUrl, documentId);
                },
              );
            },
          );
        },
      ),
    );
  }
}
