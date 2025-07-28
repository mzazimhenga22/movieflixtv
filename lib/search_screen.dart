import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/components/movie_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      setState(() => _searchResults = null);
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
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: InputBorder.none,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _searchResults = null);
                        },
                      )
                    : null,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              onChanged: (val) {
                if (val.trim().isEmpty && _searchResults != null) {
                  setState(() => _searchResults = null);
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.search, color: accentColor),
            onPressed: () => _performSearch(_controller.text),
          )
        ],
      ),
    );
  }

  Widget _buildPreviousSearches(Color accentColor) {
    if (_previousSearches.isEmpty) {
      return const Center(
        child: Text(
          'Search something above...',
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _previousSearches.length,
      itemBuilder: (_, index) {
        final query = _previousSearches[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.black.withOpacity(0.4),
          child: ListTile(
            leading: Icon(Icons.history, color: accentColor),
            title: Text(query, style: const TextStyle(color: Colors.white)),
            onTap: () {
              _controller.text = query;
              _performSearch(query);
            },
          ),
        );
      },
    );
  }

  Widget _buildCategorySection(String title, List items, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.7,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: item)),
                );
              },
              child: MovieCard.fromJson(item),
            );
          },
        )
      ],
    );
  }

  Widget _buildSearchResults(List results, Color accentColor) {
    final movies = results.where((e) => e['media_type'] == 'movie').toList();
    final tv = results.where((e) => e['media_type'] == 'tv').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (movies.isNotEmpty) _buildCategorySection("Movies", movies, accentColor),
          if (tv.isNotEmpty) _buildCategorySection("TV Shows", tv, accentColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, Color>(
      selector: (_, s) => s.accentColor,
      builder: (_, accentColor, __) {
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
                    center: const Alignment(0.2, -0.3),
                    radius: 1.0,
                    colors: [accentColor.withOpacity(0.3), Colors.black],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
              Positioned.fill(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _searchResults == null
                            ? _buildPreviousSearches(accentColor)
                            : FutureBuilder<List>(
                                future: _searchResults,
                                builder: (_, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(color: accentColor),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'Something went wrong.\n${snapshot.error}',
                                        style: const TextStyle(color: Colors.white70),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }

                                  final results = snapshot.data ?? [];
                                  if (results.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No results found.',
                                        style: TextStyle(color: Colors.white70, fontSize: 18),
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
            ],
          ),
        );
      },
    );
  }
}
