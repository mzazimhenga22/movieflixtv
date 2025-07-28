import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/components/movie_card.dart';
import 'package:movie_app/home_screen_main.dart';
import 'package:movie_app/downloads_screen.dart';
import 'package:movie_app/interactive_features_screen.dart';
import 'package:shimmer/shimmer.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  CategoriesScreenState createState() => CategoriesScreenState();
}

class CategoriesScreenState extends State<CategoriesScreen> {
  final List<Map<String, dynamic>> categories = const [
    {'name': 'Action', 'icon': Icons.local_fire_department},
    {'name': 'Comedy', 'icon': Icons.emoji_emotions},
    {'name': 'Drama', 'icon': Icons.theater_comedy},
    {'name': 'Horror', 'icon': Icons.warning},
    {'name': 'Sci-Fi', 'icon': Icons.science},
    {'name': 'Romance', 'icon': Icons.favorite},
    {'name': 'Animation', 'icon': Icons.animation},
    {'name': 'Thriller', 'icon': Icons.flash_on},
    {'name': 'Documentary', 'icon': Icons.book},
  ];

  int selectedIndex = 1;

  void onItemTapped(int index) {
    setState(() => selectedIndex = index);
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreenMain()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DownloadsScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InteractiveFeaturesScreen(
            isDarkMode: false,
            onThemeChanged: (bool newValue) {},
          ),
        ),
      );
    }
  }

  void _onCategoryTap(BuildContext context, Map<String, dynamic> category) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(160, 17, 19, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.125), width: 2),
          ),
          title: Text(
            "Select Content Type",
            style: TextStyle(color: settings.accentColor, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Choose whether to see Movies or TV Shows.",
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryContentScreen(
                      categoryName: category['name'],
                      contentType: "Movies",
                    ),
                  ),
                );
              },
              child: Text("Movies", style: TextStyle(color: settings.accentColor, fontSize: 20)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryContentScreen(
                      categoryName: category['name'],
                      contentType: "TV Shows",
                    ),
                  ),
                );
              },
              child: Text("TV Shows", style: TextStyle(color: settings.accentColor, fontSize: 20)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: settings.accentColor.withOpacity(0.1),
        elevation: 0,
        title: Text(
          'Categories',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: settings.accentColor),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.06, -0.34),
                  radius: 1.0,
                  colors: [settings.accentColor.withOpacity(0.5), const Color.fromARGB(255, 0, 0, 0)],
                  stops: const [0.0, 0.59],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.64, 0.3),
                  radius: 1.0,
                  colors: [settings.accentColor.withOpacity(0.3), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [settings.accentColor.withOpacity(0.3), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: settings.accentColor.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(160, 17, 19, 40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.125), width: 2),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: screenHeight),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(20.0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 20.0,
                            mainAxisSpacing: 20.0,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return FocusScope(
                              child: Focus(
                                canRequestFocus: true,
                                child: InkWell(
                                  onTap: () => _onCategoryTap(context, category),
                                  borderRadius: BorderRadius.circular(20.0),
                                  child: Card(
                                    elevation: 6.0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [settings.accentColor.withOpacity(0.2), settings.accentColor.withOpacity(0.4)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20.0),
                                        border: Border.all(color: settings.accentColor.withOpacity(0.5), width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: settings.accentColor.withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(category['icon'], size: 50.0, color: settings.accentColor),
                                          const SizedBox(height: 12.0),
                                          Text(
                                            category['name'],
                                            style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black54,
        selectedItemColor: const Color(0xffffeb00),
        unselectedItemColor: settings.accentColor.withOpacity(0.6),
        currentIndex: selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, size: 30), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.category, size: 30), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.download, size: 30), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv, size: 30), label: 'Interactive'),
        ],
        onTap: onItemTapped,
      ),
    );
  }
}

class CategoryContentScreen extends StatelessWidget {
  final String categoryName;
  final String contentType;

  const CategoryContentScreen({
    super.key,
    required this.categoryName,
    required this.contentType,
  });

  Future<List<dynamic>> _fetchCategoryContent() async {
    if (contentType == "Movies") {
      return await tmdb.TMDBApi.fetchCategoryMovies(categoryName);
    } else {
      return await tmdb.TMDBApi.fetchCategoryTVShows(categoryName);
    }
  }

  Widget buildMovieCardPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Container(width: 100, height: 12, color: Colors.grey[400]),
                  const SizedBox(height: 6),
                  Container(width: 50, height: 12, color: Colors.grey[400]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: settings.accentColor.withOpacity(0.1),
        elevation: 0,
        title: Text(
          '$categoryName - $contentType',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: settings.accentColor),
        ),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.06, -0.34),
                  radius: 1.0,
                  colors: [settings.accentColor.withOpacity(0.5), const Color.fromARGB(255, 0, 0, 0)],
                  stops: const [0.0, 0.59],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.64, 0.3),
                  radius: 1.0,
                  colors: [settings.accentColor.withOpacity(0.3), Colors.transparent],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [settings.accentColor.withOpacity(0.3), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: settings.accentColor.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(160, 17, 19, 40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.125), width: 2),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: screenHeight),
                        child: FutureBuilder<List<dynamic>>(
                          future: _fetchCategoryContent(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return GridView.builder(
                                padding: const EdgeInsets.all(20.0),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 20,
                                  crossAxisSpacing: 20,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: 6,
                                itemBuilder: (context, index) => buildMovieCardPlaceholder(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white, fontSize: 24)),
                              );
                            }
                            final content = snapshot.data ?? [];
                            if (content.isEmpty) {
                              return const Center(
                                child: Text('No content available.', style: TextStyle(color: Colors.white70, fontSize: 24)),
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.all(20.0),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                mainAxisSpacing: 20,
                                crossAxisSpacing: 20,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: content.length,
                              itemBuilder: (context, index) {
                                final item = content[index];
                                return FocusScope(
                                  child: Focus(
                                    canRequestFocus: true,
                                    child: MovieCard.fromJson(
                                      item,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => MovieDetailScreen(movie: item)),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}