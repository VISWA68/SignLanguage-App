import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:helping_hands/my_videos.dart';
import 'video_video.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static List<Widget> widgetList = <Widget>[
    const HomePage(),
    const MyVideos(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: widgetList,
        ),
        bottomNavigationBar: Container(
          color: Colors.grey.shade500,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              child: GNav(
                  backgroundColor: Colors.grey.shade500,
                  color: Colors.white,
                  tabBackgroundColor: Colors.grey.shade500,
                  activeColor: Colors.white,
                  gap: 15,
                  padding: const EdgeInsets.all(8),
                  tabs: const [
                    GButton(
                      icon: Icons.home,
                      text: "Home",
                    ),
                    GButton(
                      icon: Icons.history,
                      text: "MyVideos",
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onTabChange: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  })),
        ));
  }
}
