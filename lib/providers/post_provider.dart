import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../core/constants/pagination.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// SNS 投稿フィード管理プロバイダー
///
/// 設計思想:
/// - フィードは時系列降順（最新優先）
/// - カテゴリフィルタでユーザーが興味分野を絞れる
/// - いいね状態はローカルで即時反映し、後でFirestoreと同期
class PostProvider with ChangeNotifier {
  final PostService _postService;

  PostProvider({required PostService postService})
      : _postService = postService;

  // ── フィード状態 ──────────────────────────────────────────────────────────
  List<Post> _feedPosts = [];
  PostCategory? _selectedCategory;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  AppError? _error;

  // ── 投稿作成状態 ──────────────────────────────────────────────────────────
  bool _isSubmitting = false;
  AppError? _submitError;

  // ── いいね状態（ローカルキャッシュ）──────────────────────────────────────
  final Set<String> _likedPostIds = {};
  // 処理中のいいねリクエスト（連続タップによるレースコンディション防止）
  final Set<String> _pendingLikes = {};

  // ── Getters ───────────────────────────────────────────────────────────────
  List<Post> get feedPosts => _feedPosts;
  PostCategory? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  AppError? get error => _error;
  String? get errorMessage => _error?.userMessage;
  bool get isSubmitting => _isSubmitting;
  AppError? get submitError => _submitError;
  String? get submitErrorMessage => _submitError?.userMessage;

  bool isLiked(String postId) => _likedPostIds.contains(postId);

  // ── フィード読み込み ───────────────────────────────────────────────────────

  Future<void> loadFeed({PostCategory? category}) async {
    _isLoading = true;
    _error = null;
    _selectedCategory = category;
    _feedPosts = [];
    _hasMore = true;
    notifyListeners();

    final result = await _postService.getFeed(
      limit: Pagination.defaultPageSize,
      category: category,
    );

    result.when(
      success: (posts) {
        _feedPosts = posts;
        _hasMore = posts.length >= Pagination.defaultPageSize;
      },
      failure: (err) {
        _error = err;
        _feedPosts = [];
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreFeed() async {
    if (_isLoadingMore || !_hasMore || _feedPosts.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    final result = await _postService.getFeed(
      limit: Pagination.defaultPageSize,
      category: _selectedCategory,
    );

    result.when(
      success: (posts) {
        _feedPosts = [..._feedPosts, ...posts];
        _hasMore = posts.length >= Pagination.defaultPageSize;
      },
      failure: (err) {
        _error = err;
      },
    );

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> refreshFeed() => loadFeed(category: _selectedCategory);

  // ── カテゴリフィルタ ───────────────────────────────────────────────────────

  Future<void> selectCategory(PostCategory? category) async {
    if (_selectedCategory == category) return;
    await loadFeed(category: category);
  }

  // ── 投稿作成 ───────────────────────────────────────────────────────────────

  Future<bool> createPost({
    required String userId,
    required String content,
    required PostCategory category,
    PostVisibility visibility = PostVisibility.public,
    String? userDisplayName,
    String? userPhotoUrl,
    List<String> imageUrls = const [],
  }) async {
    if (content.trim().isEmpty) return false;

    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    final result = await _postService.createPost(
      userId: userId,
      content: content.trim(),
      category: category,
      visibility: visibility,
      userDisplayName: userDisplayName,
      userPhotoUrl: userPhotoUrl,
      media: imageUrls.map((url) => PostMedia(url: url, type: 'image')).toList(),
    );

    bool success = false;
    result.when(
      success: (post) {
        // 先頭に追加してフィードをすぐ更新
        _feedPosts = [post, ..._feedPosts];
        success = true;
      },
      failure: (err) {
        _submitError = err;
        success = false;
      },
    );

    _isSubmitting = false;
    notifyListeners();
    return success;
  }

  // ── いいね ────────────────────────────────────────────────────────────────

  Future<void> toggleLike(String postId, String userId) async {
    // 処理中のリクエストがある場合はスキップ（連続タップ防止）
    if (_pendingLikes.contains(postId)) return;

    final isCurrentlyLiked = _likedPostIds.contains(postId);

    // 処理中フラグを立てて楽観的更新
    _pendingLikes.add(postId);
    if (isCurrentlyLiked) {
      _likedPostIds.remove(postId);
      _updateLocalLikeCount(postId, -1);
    } else {
      _likedPostIds.add(postId);
      _updateLocalLikeCount(postId, 1);
    }
    notifyListeners();

    // Firestore 同期
    final result = isCurrentlyLiked
        ? await _postService.unlikePost(postId: postId, userId: userId)
        : await _postService.likePost(postId: postId, userId: userId);

    result.onFailure((_) {
      // 失敗時はロールバック
      if (isCurrentlyLiked) {
        _likedPostIds.add(postId);
        _updateLocalLikeCount(postId, 1);
      } else {
        _likedPostIds.remove(postId);
        _updateLocalLikeCount(postId, -1);
      }
    });

    // 完了後にフラグを解除
    _pendingLikes.remove(postId);
    notifyListeners();
  }

  void _updateLocalLikeCount(String postId, int delta) {
    final idx = _feedPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    _feedPosts[idx] = _feedPosts[idx].copyWith(
      likeCount: (_feedPosts[idx].likeCount + delta).clamp(0, double.maxFinite.toInt()),
    );
  }

  // ── いいね初期状態の読み込み ──────────────────────────────────────────────

  Future<void> loadLikeStatus(String postId, String userId) async {
    final liked = await _postService.isPostLiked(
      postId: postId,
      userId: userId,
    );
    if (liked) {
      _likedPostIds.add(postId);
    } else {
      _likedPostIds.remove(postId);
    }
    notifyListeners();
  }

  // ── 投稿削除 ───────────────────────────────────────────────────────────────

  Future<bool> deletePost(String postId, String userId) async {
    final result = await _postService.deletePost(
      postId: postId,
      userId: userId,
    );
    return result.when(
      success: (_) {
        _feedPosts.removeWhere((p) => p.id == postId);
        notifyListeners();
        return true;
      },
      failure: (err) {
        _error = err;
        notifyListeners();
        return false;
      },
    );
  }

  // ── リセット ───────────────────────────────────────────────────────────────

  void clear() {
    _feedPosts = [];
    _selectedCategory = null;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = true;
    _error = null;
    _submitError = null;
    _isSubmitting = false;
    _likedPostIds.clear();
    _pendingLikes.clear();
    notifyListeners();
  }
}
