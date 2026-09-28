import 'package:flutter/material.dart';

void main() {
  // No dotenv or complex initialization. Just start the app.
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  // This single string controls which screen is currently visible
  String _currentView = 'search'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentView == 'search' ? 'Search Tracks' : 'My Playlists'),
      ),
      // Conditionally render the body based on your state variable
      body: _currentView == 'search' ? _buildSearchScreen() : _buildPlaylistScreen(),
      
      // A simple navigation bar to switch the views
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentView == 'search' ? 0 : 1,
        onTap: (index) {
          setState(() {
            _currentView = index == 0 ? 'search' : 'playlists';
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'Playlists'),
        ],
      ),
    );
  }

  // --- THE SEARCH VIEW ---
  Widget _buildSearchScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 20),
          const Text('Main Menu & Search Active', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              print("Fake search executed!");
            },
            child: const Text('Simulate Search'),
          )
        ],
      ),
    );
  }

  // --- THE PLAYLIST VIEW ---
  Widget _buildPlaylistScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 80, color: Colors.greenAccent),
          SizedBox(height: 20),
          Text('Playlist Menu Active', style: TextStyle(fontSize: 22)),
        ],
      ),
    );
  }
}