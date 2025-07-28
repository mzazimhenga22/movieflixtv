import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'feed_reel_player_screen.dart';
import '../../models/reel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:movie_app/helpers/movie_account_helper.dart';
import 'package:movie_app/components/trending_movies_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show File;
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'stories.dart';
import 'messages_screen.dart';
import 'search_screen.dart';
import 'user_profile_screen.dart';
import 'realtime_feed_service.dart';
import 'streak_section.dart';
import 'notifications_section.dart';
import 'chat_screen.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:path/path.dart' as p;
import 'PostStoryScreen.dart';
import 'chatutils.dart' as chatUtils;



class VideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final VoidCallback? onTap;

  const VideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.onTap,
  });

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late vp.VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = vp.VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      )
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                if (widget.autoPlay) {
                  _controller.play();
                  _isPlaying = true;
                }
              });
            }
          })
          .catchError((error) {
            debugPrint('Error initializing video: $error');
          });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          setState(() {
            if (_isPlaying) {
              _controller.pause();
              _isPlaying = false;
            } else {
              _controller.play();
              _isPlaying = true;
            }
          });
        }
      },
      child: RepaintBoundary(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _controller.value.isInitialized
                ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: vp.VideoPlayer(_controller),
                )
                : Container(
                  color: Colors.grey[300],
                  height: 300,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            if (!_isPlaying && _controller.value.isInitialized)
              const Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 50,
              ),
          ],
        ),
      ),
    );
  }
}

class FeedProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _feedPosts = [];
  bool _isLoading = false;
  bool _hasMorePosts = true;
  final int _postsPerPage = 10;
  DocumentSnapshot? _lastDocument;

  List<Map<String, dynamic>> get feedPosts => _feedPosts;
  bool get isLoading => _isLoading;
  bool get hasMorePosts => _hasMorePosts;

  Future<void> fetchPosts({bool isRefresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      Query query = FirebaseFirestore.instance
          .collection('feeds')
          .orderBy('timestamp', descending: true)
          .limit(_postsPerPage);

      if (!isRefresh && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      final newPosts =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'user': data['user'] as String? ?? '',
              'post': data['post'] as String? ?? '',
              'type': data['type'] as String? ?? '',
              'likedBy':
                  (data['likedBy'] as List?)
                      ?.where((item) => item != null)
                      .map((item) => item.toString())
                      .toList() ??
                  [],
              'title': data['title'] as String? ?? '',
              'season': data['season'] as String? ?? '',
              'episode': data['episode'] as String? ?? '',
              'media': data['media'] as String? ?? '',
              'mediaType': data['mediaType'] as String? ?? '',
              'timestamp': data['timestamp'] as String? ?? '',
              'userId': data['userId'] as String? ?? '',
            };
          }).toList();

      if (isRefresh) {
        _feedPosts.clear();
      }

      _feedPosts.addAll(newPosts);
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMorePosts = newPosts.length == _postsPerPage;
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addPost(Map<String, dynamic> post) {
    _feedPosts.insert(0, post);
    notifyListeners();
  }

  void removePost(String id) {
    _feedPosts.removeWhere((p) => p['id'] == id);
    notifyListeners();
  }
}

class PostCardWidget extends StatelessWidget {
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> allPosts;
  final Map<String, dynamic>? currentUser;
  final List<Map<String, dynamic>> users;
  final Color accentColor;
  final Function(String) onDelete;
  final Function(String, bool) onLike;
  final Function(Map<String, dynamic>) onComment;
  final Function(Map<String, dynamic>) onWatchParty;
  final Function(Map<String, dynamic>) onSend;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.allPosts,
    required this.currentUser,
    required this.users,
    required this.accentColor,
    required this.onDelete,
    required this.onLike,
    required this.onComment,
    required this.onWatchParty,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final id = post['id'] as String? ?? '';
    final userName = post['user'] as String? ?? 'Unknown';
    final message = post['post'] as String? ?? '';
    final likedBy =
        (post['likedBy'] as List?)
            ?.where((item) => item != null)
            .map((item) => item.toString())
            .toList() ??
        [];
    final title = post['title'] as String? ?? '';
    final season = post['season'] as String? ?? '';
    final episode = post['episode'] as String? ?? '';
    final media = post['media'] as String? ?? '';
    final mediaType = post['mediaType'] as String? ?? '';
    final userId = post['userId'] as String? ?? '';
    final userRecord = users.firstWhere(
      (u) => (u['id'] as String?) == userId,
      orElse: () => {'username': userName, 'avatar': ''},
    );
    final username = userRecord['username'] as String? ?? 'Unknown';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final avatarUrl = userRecord['avatar'] as String? ?? '';
    final isLiked = likedBy.contains((currentUser?['id'] as String?) ?? '');

    bool isValidImageUrl(String url) =>
        url.startsWith('http') &&
        (url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png'));

    return Card(
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withOpacity(0.1),
              accentColor.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage:
                    avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                child:
                    avatarUrl.isEmpty
                        ? Text(
                          initial,
                          style: const TextStyle(color: Colors.white),
                        )
                        : null,
              ),
              title: Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            if (media.isNotEmpty)
              if (mediaType == 'photo' && isValidImageUrl(media))
                CachedNetworkImage(
                  imageUrl: media,
                  height: 700,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => const SizedBox(
                        height: 700,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        height: 700,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 40),
                      ),
                )
              else if (mediaType == 'video')
                SizedBox(
                  height: 700,
                  child: VideoPlayer(
                    videoUrl: media,
                    autoPlay: true,
                    onTap: () {
                      final videoPosts =
                          allPosts
                              .where(
                                (p) =>
                                    (p['mediaType'] as String?) == 'video' &&
                                    (p['media'] as String?)?.isNotEmpty == true,
                              )
                              .map(
                                (p) => Reel(
                                  videoUrl: (p['media'] as String?) ?? '',
                                  movieTitle:
                                      (p['title'] as String?) ?? 'Video',
                                  movieDescription:
                                      (p['post'] as String?) ?? '',
                                ),
                              )
                              .toList();
                      final idx = videoPosts.indexWhere(
                        (r) => r.videoUrl == media,
                      );
                      if (idx != -1) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => FeedReelPlayerScreen(
                                  reels: videoPosts,
                                  initialIndex: idx,
                                ),
                          ),
                        );
                      }
                    },
                  ),
                )
              else
                Container(
                  height: 700,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.image, size: 40)),
                ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                  if (season.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Season: $season, Episode: ${episode.isNotEmpty ? episode : 'N/A'}",
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  if (title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Movie: $title",
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white54, height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => onLike(id, isLiked),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        likedBy.length.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.comment,
                    color: Colors.white70,
                    size: 22,
                  ),
                  onPressed: () => onComment(post),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.connected_tv,
                    color: Colors.white70,
                    size: 22,
                  ),
                  onPressed: () => onWatchParty(post),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white70, size: 22),
                  onPressed: () => onSend(post),
                ),
                if (userId == ((currentUser?['id'] as String?) ?? ''))
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                    onPressed: () => onDelete(id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SocialReactionsScreen extends StatelessWidget {
  final Color accentColor;

  const SocialReactionsScreen({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primaryColor: accentColor,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      child: MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FeedProvider())],
        child: _SocialReactionsScreen(accentColor: accentColor),
      ),
    );
  }
}

class _SocialReactionsScreen extends StatefulWidget {
  final Color accentColor;

  const _SocialReactionsScreen({required this.accentColor});

  @override
  _SocialReactionsScreenState createState() => _SocialReactionsScreenState();
}

class _SocialReactionsScreenState extends State<_SocialReactionsScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _users = [];
  final List<String> _notifications = [];
  List<Map<String, dynamic>> _stories = [];
  int _movieStreak = 0;
  Map<String, dynamic>? _currentUser;
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _showRecommendations = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent &&
          !Provider.of<FeedProvider>(context, listen: false).isLoading &&
          Provider.of<FeedProvider>(context, listen: false).hasMorePosts) {
        Provider.of<FeedProvider>(context, listen: false).fetchPosts();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pause videos when app is backgrounded
    } else if (state == AppLifecycleState.resumed) {
      // Resume video autoplay if needed
    }
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _checkMovieAccount(),
        _loadLocalData(),
        _loadUsers(),
        _loadUserData(),
      ]);
      await Provider.of<FeedProvider>(context, listen: false).fetchPosts();
    } catch (e) {
      debugPrint('Error initializing data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to initialize data: $e')));
    }
  }

  Future<void> _checkMovieAccount() async {
    try {
      if (await MovieAccountHelper.doesMovieAccountExist()) {
        await MovieAccountHelper.getMovieAccountData();
      }
    } catch (e) {
      debugPrint('Error checking movie account: $e');
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storiesString = prefs.getString('stories') ?? '[]';
      final movieStreak = prefs.getInt('movieStreak') ?? 0;
      _stories = List<Map<String, dynamic>>.from(jsonDecode(storiesString));
      _movieStreak = movieStreak;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stories', jsonEncode(_stories));
      await prefs.setInt('movieStreak', _movieStreak);
    } catch (e) {
      debugPrint('Error saving local data: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        if (doc.exists) {
          final userData = doc.data()!;
          userData['id'] = doc.id;
          if (!mounted) return;
          setState(() {
            _currentUser = _normalizeUserData(userData);
          });
        } else {
          throw Exception('No user data found for UID: ${currentUser.uid}');
        }
      } else {
        throw Exception('No current user logged in');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;
      setState(() {
        _currentUser = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final rawUsers =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
      _users =
          rawUsers
              .map((u) => _normalizeUserData(Map<String, dynamic>.from(u)))
              .toList();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Map<String, dynamic> _normalizeUserData(Map<String, dynamic> user) {
    return {
      'id': user['id']?.toString() ?? '',
      'username': user['username']?.toString() ?? 'Unknown',
      'email': user['email']?.toString() ?? '',
      'bio': user['bio']?.toString() ?? '',
      'password': user['password']?.toString() ?? '',
      'auth_provider': user['auth_provider']?.toString() ?? '',
      'token': user['token']?.toString() ?? '',
      'created_at': user['created_at']?.toString() ?? '',
      'updated_at':
          user['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'followers_count': user['followers_count']?.toString() ?? '0',
      'following_count': user['following_count']?.toString() ?? '0',
      'avatar': user['avatar']?.toString() ?? 'https://via.placeholder.com/200',
    };
  }

  Future<dynamic> pickFile(String type) async {
    if (kIsWeb) {
      final html.FileUploadInputElement input = html.FileUploadInputElement();
      input.accept = type == 'photo' ? 'image/jpeg,image/png' : 'video/mp4';
      input.click();
      await input.onChange.first;
      if (input.files!.isNotEmpty) {
        return input.files!.first;
      }
    } else {
      final picker = ImagePicker();
      if (type == 'photo') {
        return await picker.pickImage(source: ImageSource.gallery);
      } else {
        return await picker.pickVideo(source: ImageSource.gallery);
      }
    }
    return null;
  }

  Future<String> uploadMedia(
    dynamic mediaFile,
    String type,
    BuildContext context,
  ) async {
    try {
      final mediaId = const Uuid().v4();
      String filePath;
      String contentType;

      if (kIsWeb) {
        if (mediaFile is html.File) {
          final fileSizeInBytes = mediaFile.size;
          if (type == 'photo' && fileSizeInBytes > 5 * 1024 * 1024) {
            throw Exception('Image too large, max 5MB allowed');
          } else if (type == 'video' && fileSizeInBytes > 20 * 1024 * 1024) {
            throw Exception('Video too large, max 20MB allowed');
          }
          final extension = mediaFile.name.split('.').last.toLowerCase();
          filePath = 'media/$mediaId.$extension';
          contentType = mediaFile.type;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(mediaFile);
          await reader.onLoad.first;
          Uint8List bytes = reader.result as Uint8List;
          await _supabase.storage
              .from('feeds')
              .uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(contentType: contentType),
              );
        } else {
          throw Exception('Invalid file type for web platform');
        }
      } else {
        if (mediaFile is XFile) {
          final file = File(mediaFile.path);
          int fileSizeInBytes = await file.length();
          if (type == 'photo' && fileSizeInBytes > 5 * 1024 * 1024) {
            throw Exception('Image too large, max 5MB allowed');
          } else if (type == 'video' && fileSizeInBytes > 20 * 1024 * 1024) {
            throw Exception('Video too large, max 20MB allowed');
          }
          final extension = p.extension(mediaFile.path).replaceFirst('.', '');
          filePath = 'media/$mediaId.$extension';
          contentType = getMimeType(extension);
          await _supabase.storage
              .from('feeds')
              .upload(
                filePath,
                file,
                fileOptions: FileOptions(contentType: contentType),
              );
        } else {
          throw Exception('Invalid file type');
        }
      }

      final url = _supabase.storage.from('feeds').getPublicUrl(filePath);
      return url.isNotEmpty ? url : 'https://via.placeholder.com/150';
    } catch (e) {
      debugPrint('Error uploading media: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading media: $e')));
      return 'https://via.placeholder.com/150';
    }
  }

  String getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _postStory() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo, color: Colors.white),
                  title: const Text(
                    "Upload Photo",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, 'photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.white),
                  title: const Text(
                    "Upload Video",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, 'video'),
                ),
              ],
            ),
          ),
    );

    if (choice != null && mounted) {
      dynamic pickedFile = await pickFile(choice);
      if (pickedFile != null) {
        final user = _currentUser?['username'] ?? 'CurrentUser';
        final timestamp = DateTime.now().toIso8601String();
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => const AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text("Uploading..."),
                  ],
                ),
              ),
        );
        try {
          final uploadedUrl = await uploadMedia(pickedFile, choice, context);
          if (!mounted) return;
          if (uploadedUrl.isNotEmpty &&
              uploadedUrl != 'https://via.placeholder.com/150') {
            final story = {
              'user': user,
              'userId': _currentUser?['id']?.toString() ?? '',
              'media': uploadedUrl,
              'type': choice,
              'timestamp': timestamp,
            };
            final docRef = await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser?['id']?.toString())
                .collection('stories')
                .add(story);
            story['id'] = docRef.id;
            await FirebaseFirestore.instance.collection('stories').add(story);
            setState(() {
              _stories.add(story);
              final newPost = {
                'id': docRef.id,
                'user': user,
                'userId': _currentUser?['id']?.toString() ?? '',
                'post': '$user posted a story.',
                'type': 'story',
                'likedBy': [],
                'timestamp': timestamp,
              };
              Provider.of<FeedProvider>(
                context,
                listen: false,
              ).addPost(newPost);
              RealtimeFeedService.instance.addPost(newPost);
            });
            await _saveLocalData();
          } else {
            throw Exception('Failed to upload story media');
          }
        } catch (e) {
          debugPrint('Error posting story: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to post story: $e')));
        } finally {
          if (mounted) Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _postMovieReview() async {
    final movieController = TextEditingController();
    final reviewController = TextEditingController();
    final episodeController = TextEditingController();
    final seasonController = TextEditingController();
    dynamic mediaFile;
    String? mediaType;
    bool isTVShow = false;

    await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color.fromARGB(255, 17, 25, 40),
              title: const Text(
                "Write a Review",
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                !isTVShow ? widget.accentColor : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              () => setStateDialog(() => isTVShow = false),
                          child: const Text("Movie"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isTVShow ? widget.accentColor : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              () => setStateDialog(() => isTVShow = true),
                          child: const Text("TV Show"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: movieController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Movie/TV Show Name",
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    if (isTVShow) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: seasonController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Season Name",
                          hintStyle: TextStyle(color: Colors.white54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: episodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Episode Name/Number",
                          hintStyle: TextStyle(color: Colors.white54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: reviewController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Enter your review...",
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    if (mediaFile != null)
                      kIsWeb
                          ? const Text(
                            "Media selected",
                            style: TextStyle(color: Colors.white70),
                          )
                          : mediaType == 'photo'
                          ? Image.file(
                            File((mediaFile as XFile).path),
                            height: 150,
                            fit: BoxFit.cover,
                          )
                          : const Text(
                            "Video selected",
                            style: TextStyle(color: Colors.white70),
                          ),
                    TextButton.icon(
                      icon: const Icon(Icons.image, color: Colors.white70),
                      label: const Text(
                        "Pick Media",
                        style: TextStyle(color: Colors.white70),
                      ),
                      onPressed: () async {
                        final choice = await showModalBottomSheet<String>(
                          context: context,
                          builder:
                              (context) => Container(
                                color:
                                    Colors
                                        .black87, // Or any dark color you like
                                child: SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo,
                                          color: Colors.white,
                                        ),
                                        title: const Text(
                                          "Upload Photo",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        onTap:
                                            () =>
                                                Navigator.pop(context, 'photo'),
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.videocam,
                                          color: Colors.white,
                                        ),
                                        title: const Text(
                                          "Upload Video",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        onTap:
                                            () =>
                                                Navigator.pop(context, 'video'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        );
                        if (choice != null) {
                          final picked = await pickFile(choice);
                          if (picked != null) {
                            setStateDialog(() {
                              mediaFile = picked;
                              mediaType = choice;
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                  onPressed: () {
                    if (movieController.text.trim().isEmpty ||
                        reviewController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill in all fields"),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'title': movieController.text.trim(),
                      'review': reviewController.text.trim(),
                      'season': seasonController.text.trim(),
                      'episode': episodeController.text.trim(),
                      'media': mediaFile,
                      'mediaType': mediaType,
                      'isTVShow': isTVShow,
                    });
                  },
                  child: const Text("Post"),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result != null && mounted) {
        String? mediaUrl;
        try {
          if (result['media'] != null) {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (_) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text("Uploading Review...🔥"),
                      ],
                    ),
                  ),
            );
            mediaUrl = await uploadMedia(
              result['media'],
              result['mediaType']!,
              context,
            );
            if (mediaUrl == 'https://via.placeholder.com/150') {
              throw Exception('Failed to upload review media');
            }
          }
          if (!mounted) return;
          final newPost = {
            'user': _currentUser?['username'] ?? 'CurrentUser',
            'userId': _currentUser?['id']?.toString() ?? '',
            'post':
                result['isTVShow']
                    ? "Reviewed ${result['title']} S${result['season']}: E${result['episode']} - ${result['review']}"
                    : "Reviewed ${result['title']}: ${result['review']}",
            'type': 'review',
            'likedBy': [],
            'title': result['title'],
            'season': result['season'],
            'episode': result['episode'],
            'media': mediaUrl,
            'mediaType': mediaUrl != null ? result['mediaType'] ?? '' : '',
            'timestamp': DateTime.now().toIso8601String(),
          };
          final docRef = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser?['id']?.toString())
              .collection('posts')
              .add(newPost);
          newPost['id'] = docRef.id;
          await FirebaseFirestore.instance.collection('feeds').add(newPost);
          setState(() {
            Provider.of<FeedProvider>(context, listen: false).addPost(newPost);
            _notifications.add(
              "${_currentUser?['username'] ?? 'CurrentUser'} posted a review for ${result['title']}",
            );
          });
        } catch (e) {
          debugPrint('Error posting review: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to post review: $e')));
        } finally {
          if (mounted) Navigator.pop(context);
        }
      }
    });
  }

  Widget _buildFeedTab() {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _postMovieReview,
                icon: const Icon(Icons.rate_review, size: 20),
                label: const Text(
                  "Post Movie Review",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            Expanded(
              child:
                  feedProvider.isLoading && feedProvider.feedPosts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh:
                            () => feedProvider.fetchPosts(isRefresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          cacheExtent: 1000,
                          itemCount:
                              feedProvider.feedPosts.length +
                              (feedProvider.hasMorePosts ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == feedProvider.feedPosts.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            try {
                              return RepaintBoundary(
                                child: PostCardWidget(
                                  key: ValueKey(
                                    feedProvider.feedPosts[index]['id'],
                                  ),
                                  post: feedProvider.feedPosts[index],
                                  allPosts: feedProvider.feedPosts,
                                  currentUser: _currentUser,
                                  users: _users,
                                  accentColor: widget.accentColor,
                                  onDelete: (id) async {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('feeds')
                                          .doc(id)
                                          .delete();
                                      feedProvider.removePost(id);
                                    } catch (e) {
                                      debugPrint('Error deleting post: $e');
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to delete post: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onLike: (id, isLiked) async {
                                    try {
                                      final ref = FirebaseFirestore.instance
                                          .collection('feeds')
                                          .doc(id);
                                      if (isLiked) {
                                        await ref.update({
                                          'likedBy': FieldValue.arrayRemove([
                                            (_currentUser?['id'] as String?) ??
                                                '',
                                          ]),
                                        });
                                      } else {
                                        await ref.update({
                                          'likedBy': FieldValue.arrayUnion([
                                            (_currentUser?['id'] as String?) ??
                                                '',
                                          ]),
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error liking post: $e');
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to like post: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onComment: _showComments,
                                  onWatchParty: _promptCreateWatchParty,
                                  onSend: (post) {
                                    final code = _generateWatchCode();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Started Watch Party: Code $code",
                                        ),
                                      ),
                                    );
                                    _notifications.add(
                                      "${(_currentUser?['username'] as String?) ?? 'CurrentUser'} started a watch party with code $code",
                                    );
                                  },
                                ),
                              );
                            } catch (e) {
                              debugPrint(
                                'Error building post card at index $index: $e',
                              );
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recommended Movies",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _showRecommendations ? Icons.remove : Icons.add,
                          color: Colors.white,
                        ),
                        onPressed:
                            () => setState(
                              () =>
                                  _showRecommendations = !_showRecommendations,
                            ),
                      ),
                    ],
                  ),
                  Visibility(
                    visible: _showRecommendations,
                    child: const Column(
                      children: [SizedBox(height: 12), TrendingMoviesWidget()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStoriesTab() {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('stories').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Error in stories stream: ${snapshot.error}');
                return const Center(
                  child: Text(
                    'Failed to load stories.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stories =
                  snapshot.data!.docs
                      .map(
                        (doc) => {
                          ...doc.data() as Map<String, dynamic>,
                          'id': doc.id,
                        },
                      )
                      .where(
                        (story) =>
                            DateTime.now().difference(
                              DateTime.parse(story['timestamp']),
                            ) <
                            const Duration(hours: 24),
                      )
                      .toList();

              final Map<String, List<Map<String, dynamic>>> groupedStories = {};
              for (var story in stories) {
                final userId = story['userId'] as String;
                if (!groupedStories.containsKey(userId)) {
                  groupedStories[userId] = [];
                }
                groupedStories[userId]!.add(story);
              }

              if (groupedStories.isEmpty) {
                return const Center(
                  child: Text(
                    "No stories available.",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: groupedStories.length,
                itemBuilder: (context, index) {
                  final userId = groupedStories.keys.elementAt(index);
                  final userStories = groupedStories[userId]!;
                  final firstStory = userStories.first;
                  final mediaUrl = firstStory['media'] as String?;
                  final isValidPhotoUrl =
                      mediaUrl != null &&
                      mediaUrl.isNotEmpty &&
                      (mediaUrl.startsWith('http') &&
                          (mediaUrl.endsWith('.jpg') ||
                              mediaUrl.endsWith('.png') ||
                              mediaUrl.endsWith('.jpeg')));

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => StoryScreen(
                                    stories: userStories,
                                    initialIndex: 0,
                                    currentUserId:
                                        (_currentUser?['id'] ?? '').toString(),
                                  ),
                            ),
                          ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image:
                                  firstStory['type'] == 'photo' &&
                                          isValidPhotoUrl
                                      ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                          mediaUrl,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                              color:
                                  firstStory['type'] == 'video'
                                      ? Colors.black
                                      : Colors.grey,
                              border: Border.all(
                                color: Colors.yellow.withOpacity(0.8),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.yellow.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child:
                                firstStory['type'] == 'video'
                                    ? const Icon(
                                      Icons.videocam,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                    : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            firstStory['user'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () {
              if (_currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => PostStoryScreen(
                          accentColor: widget.accentColor,
                          currentUser: _currentUser!,
                        ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User data not loaded")),
                );
              }
            },
            icon: const Icon(Icons.add_a_photo, size: 20),
            label: const Text("Post Story", style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  String _generateWatchCode() => (100000 + Random().nextInt(900000)).toString();

  void _promptCreateWatchParty(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Create Watch Party"),
            content: const Text(
              "Do you want to create a watch party for this post?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("No"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  final code = _generateWatchCode();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Watch Party created with code: $code"),
                    ),
                  );
                  _notifications.add(
                    "${_currentUser?['username'] ?? 'CurrentUser'} created a watch party with code $code",
                  );
                },
                child: const Text("Yes"),
              ),
            ],
          ),
    );
  }

  void _showComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 17, 25, 40),
      builder: (context) {
        final controller = TextEditingController();
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(post['userId'])
                        .collection('posts')
                        .doc(post['id'])
                        .collection('comments')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Error in comments stream: ${snapshot.error}');
                    return const Center(
                      child: Text(
                        'Failed to load comments.',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments =
                      snapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList();
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Comments",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: comments.length,
                            itemBuilder:
                                (_, i) => ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: CachedNetworkImageProvider(
                                      comments[i]['userAvatar'] ??
                                          'https://via.placeholder.com/50',
                                    ),
                                    radius: 20,
                                  ),
                                  title: Text(
                                    comments[i]['username'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: widget.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    comments[i]['text'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Add a comment",
                            labelStyle: TextStyle(color: Colors.white54),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accentColor,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              try {
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(post['userId'])
                                    .collection('posts')
                                    .doc(post['id'])
                                    .collection('comments')
                                    .add({
                                      'text': controller.text,
                                      'userId': _currentUser?['id'],
                                      'username': _currentUser?['username'],
                                      'userAvatar': _currentUser?['avatar'],
                                      'timestamp':
                                          DateTime.now().toIso8601String(),
                                    });
                                controller.clear();
                              } catch (e) {
                                debugPrint('Error posting comment: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to post comment: $e'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            "Post",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showFabActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 17, 25, 40),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.message, color: Colors.white),
                  title: const Text(
                    "New Message",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (_currentUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => NewChatScreen(
                                currentUser: _currentUser!,
                                otherUsers:
                                    _users
                                        .where(
                                          (u) =>
                                              u['email'] !=
                                              _currentUser!['email'],
                                        )
                                        .toList(),
                                accentColor: widget.accentColor,
                              ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("User data not loaded")),
                      );
                    }
                  },
                ),
                if (!_showRecommendations)
                  ListTile(
                    leading: const Icon(Icons.expand, color: Colors.white),
                    title: const Text(
                      "Expand Recommendations",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _showRecommendations = true);
                    },
                  ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildFeedTab(),
      _buildStoriesTab(),
      NotificationsSection(notifications: _notifications),
      StreakSection(
        movieStreak: _movieStreak,
        onStreakUpdated:
            (newStreak) => setState(() => _movieStreak = newStreak),
      ),
      _currentUser != null
          ? UserProfileScreen(
            key: ValueKey(_currentUser!['id']),
            user: _currentUser!,
            showAppBar: false,
            accentColor: widget.accentColor,
          )
          : const Center(child: CircularProgressIndicator()),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Social Section",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.message, color: Colors.white, size: 22),
            onPressed: () {
              if (_currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => MessagesScreen(
                          currentUser: _currentUser!,
                          otherUsers:
                              _users
                                  .where(
                                    (u) => u['email'] != _currentUser!['email'],
                                  )
                                  .toList(),
                                   accentColor: widget.accentColor,
                        ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User data not loaded")),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 22),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
          ),
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  "Hello, ${_currentUser!['username']}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF111927)),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.1, -0.4),
                radius: 1.2,
                colors: [widget.accentColor.withOpacity(0.4), Colors.black],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
          Positioned.fill(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.6,
                    colors: [
                      widget.accentColor.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(180, 17, 19, 40),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 0.1),
                        ),
                      ),
                      child: Theme(
                        data: ThemeData.dark(),
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: tabs,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.accentColor,
        onPressed: _showFabActions,
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        backgroundColor: Colors.black87,
        selectedItemColor: const Color(0xffffeb00),
        unselectedItemColor: widget.accentColor,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 22),
            label: "Feeds",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 22),
            label: "Stories",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications, size: 22),
            label: "Notifications",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.whatshot, size: 22),
            label: "Streaks",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 22),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

class NewChatScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> otherUsers;
  final Color accentColor;

  const NewChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUsers,
    required this.accentColor,
  });

  @override
  NewChatScreenState createState() => NewChatScreenState();
}

class NewChatScreenState extends State<NewChatScreen> {
  void _startChat(Map<String, dynamic> user) {
    String chatId = chatUtils.getChatId(widget.currentUser['id'], user['id']); // ✅ Use getChatId from chatutils

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          currentUser: widget.currentUser,
          otherUser: {
            'id': user['id'],
            'username': user['username'],
            'photoUrl': user['photoUrl'],
          },
          authenticatedUser: widget.currentUser,
          storyInteractions: const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "New Chat",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF111927)),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.1, -0.4),
                radius: 1.2,
                colors: [widget.accentColor.withOpacity(0.4), Colors.black],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
          Positioned.fill(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.6,
                    colors: [
                      widget.accentColor.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(16),
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.otherUsers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white54),
                        itemBuilder: (context, index) {
                          final user = widget.otherUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: widget.accentColor,
                              child: Text(
                                user['username'] != null &&
                                        user['username'].isNotEmpty
                                    ? user['username'][0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              user['username'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () => _startChat(user),
                          );
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
  }
}