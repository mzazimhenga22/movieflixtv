import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/components/movie_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Future<List<dynamic>>? _searchResults;
  List<String> _previousSearches = [];

  @override
  void initState() {
    super.initState();
    _loadPreviousSearches();
  }

  Future<void> _loadPreviousSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _previousSearches = prefs.getStringList('previousSearches') ?? [];
    });
  }

  Future<void> _savePreviousSearch(String query) async {
    if (!_previousSearches.contains(query)) {
      _previousSearches.insert(0, query);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('previousSearches', _previousSearches);
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
      });
      return;
    }
    _savePreviousSearch(query);
    setState(() {
      _searchResults = tmdb.TMDBApi.fetchSearchMulti(query);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSearchField(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              decoration: InputDecoration(
                hintText: 'Search movies & TV shows...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 20),
                border: InputBorder.none,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.5), size: 30),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _searchResults = null;
                          });
                        },
                      )
                    : null,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              onChanged: (value) {
                if (value.trim().isEmpty && _searchResults != null) {
                  setState(() {
                    _searchResults = null;
                  });
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.search, color: accentColor, size: 30),
            onPressed: () => _performSearch(_controller.text),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousSearches(Color accentColor) {
    if (_previousSearches.isEmpty) {
      return Center(
        child: Text(
          'Enter a movie or TV show title above to search',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 24),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _previousSearches.length,
      itemBuilder: (context, index) {
        final searchQuery = _previousSearches[index];
        return FocusScope(
          child: Focus(
            canRequestFocus: true,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.1), accentColor.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
                ),
                child: ListTile(
                  leading: Icon(Icons.history, color: accentColor, size: 30),
                  title: Text(searchQuery, style: const TextStyle(color: Colors.white, fontSize: 20)),
                  onTap: () {
                    _controller.text = searchQuery;
                    _performSearch(searchQuery);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySection(String categoryTitle, List<dynamic> items, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Text(
            categoryTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 6, color: Colors.black54, offset: Offset(3, 3))],
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.8,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return FocusScope(
              child: Focus(
                canRequestFocus: true,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailScreen(movie: item),
                      ),
                    );
                  },
                  child: MovieCard.fromJson(
                    item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MovieDetailScreen(movie: item),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults(List<dynamic> results, Color accentColor) {
    final moviesOnly = results.where((item) => item['media_type'] == 'movie').toList();
    final tvShows = results.where((item) => item['media_type'] == 'tv').toList();

    List<Widget> sections = [];
    if (moviesOnly.isNotEmpty) {
      sections.add(_buildCategorySection("Movies", moviesOnly, accentColor));
    }
    if (tvShows.isNotEmpty) {
      sections.add(_buildCategorySection("TV Shows", tvShows, accentColor));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, Color>(
      selector: (_, settings) => settings.accentColor,
      builder: (context, accentColor, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: _buildSearchField(accentColor),
            automaticallyImplyLeading: false,
          ),
          body: Stack(
            children: [
              Container(color: const Color(0xFF111927)),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.06, -0.34),
                    radius: 1.0,
                    colors: [accentColor.withOpacity(0.5), const Color.fromARGB(255, 0, 0, 0)],
                    stops: const [0.0, 0.59],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.64, 0.3),
                    radius: 1.0,
                    colors: [accentColor.withOpacity(0.3), Colors.transparent],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
              Positioned.fill(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [accentColor.withOpacity(0.3), Colors.transparent],
                        stops: const [0.0, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
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
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(160, 17, 19, 40),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            border: Border(
                              top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.125), width: 2),
                              bottom: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.125), width: 2),
                              left: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.125), width: 2),
                              right: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.125), width: 2),
                            ),
                          ),
                          child: _searchResults == null
                              ? _buildPreviousSearches(accentColor)
                              : FutureBuilder<List<dynamic>>(
                                  future: _searchResults,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return Center(
                                        child: CircularProgressIndicator(color: accentColor, strokeWidth: 4),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Error: ${snapshot.error}',
                                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 20),
                                        ),
                                      );
                                    }
                                    final results = snapshot.data!;
                                    if (results.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'No results found',
                                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 20),
                                        ),
                                      );
                                    }
                                    return _buildSearchResults(results, accentColor);
                                  },
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
      },
    );
  }
}