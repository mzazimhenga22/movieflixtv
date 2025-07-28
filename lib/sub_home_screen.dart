import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'package:movie_app/tmdb_api.dart' as tmdb;
import 'package:movie_app/movie_detail_screen.dart';
import 'package:movie_app/components/movie_card.dart';
import 'recommended_movies_screen.dart';

class SubHomeScreen extends StatefulWidget {
  const SubHomeScreen({super.key});

  @override
  State<SubHomeScreen> createState() => SubHomeScreenState();
}

class SubHomeScreenState extends State<SubHomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _trendingController = ScrollController();

  List<dynamic> trendingMovies = [];
  List<dynamic> recommendedMovies = [];

  bool isLoadingTrending = false;
  bool isLoadingRecommended = false;

  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchInitialData();
    _trendingController.addListener(_onTrendingScroll);
  }

  Future<void> fetchInitialData() async {
    await Future.wait([
      fetchTrendingMovies(),
      fetchRecommendedMovies(),
    ]);
  }

  Future<void> refreshData() async {
    setState(() {
      trendingMovies.clear();
      recommendedMovies.clear();
    });
    await fetchInitialData();
  }

  Future<void> fetchTrendingMovies() async {
    if (isLoadingTrending) return;
    setState(() => isLoadingTrending = true);

    try {
      final movies = await tmdb.TMDBApi.fetchTrendingMovies();
      setState(() => trendingMovies.addAll(movies));
    } catch (e) {
      debugPrint('Error fetching trending movies: $e');
    }

    setState(() => isLoadingTrending = false);
  }

  Future<void> fetchRecommendedMovies({int page = 1}) async {
    if (isLoadingRecommended) return;
    setState(() => isLoadingRecommended = true);

    try {
      final response = await tmdb.TMDBApi.fetchRecommendedMovies(page: page);
      setState(() => recommendedMovies = response['movies'] ?? []);
    } catch (e) {
      debugPrint('Error fetching recommended movies: $e');
    }

    setState(() => isLoadingRecommended = false);
  }

  void _onTrendingScroll() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (_trendingController.position.extentAfter < 200 && !isLoadingTrending) {
        fetchTrendingMovies();
      }
    });
  }

  Widget _buildMovieCard(dynamic movie) {
    final posterPath = movie['poster_path'];
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w342$posterPath'
        : '';

    return MovieCard(
      imageUrl: posterUrl,
      title: movie['title'] ?? movie['name'] ?? 'Untitled',
      rating: double.tryParse('${movie['vote_average'] ?? 0}'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(movie: movie),
          ),
        );
      },
    );
  }

  Widget _buildTrendingSection(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Trending', settings),
        const SizedBox(height: 10),
        SizedBox(
          height: 240,
          child: ListView.builder(
            controller: _trendingController,
            scrollDirection: Axis.horizontal,
            itemCount: trendingMovies.length + (isLoadingTrending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == trendingMovies.length) {
                return _buildLoadingPlaceholder();
              }
              return Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: _buildMovieCard(trendingMovies[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedSection(SettingsProvider settings) {
    final moviesToShow = recommendedMovies.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionTitle('Recommended', settings),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemCount: moviesToShow.length,
          itemBuilder: (context, index) {
            return _buildMovieCard(moviesToShow[index]);
          },
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecommendedMoviesScreen(),
                ),
              );
            },
            child: const Text('See All'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          color: settings.accentColor,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return RefreshIndicator(
          onRefresh: refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTrendingSection(settings),
                _buildRecommendedSection(settings),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _trendingController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
