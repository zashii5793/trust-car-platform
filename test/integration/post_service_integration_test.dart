/// Post Service Integration Tests
///
/// These tests verify CRUD operations for Posts, Comments, and Likes
/// against Firebase Emulators.
///
/// Prerequisites:
/// 1. Start Firebase Emulators: `firebase emulators:start`
/// 2. Run tests: `flutter test test/integration/post_service_integration_test.dart`

@Tags(['emulator'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/models/post.dart';

import '../helpers/firebase_emulator_helper.dart';

void main() {
  late PostService postService;
  late FirebaseFirestore firestore;
  late String testUserId;
  late String testUserDisplayName;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await FirebaseEmulatorHelper.initialize();

    firestore = FirebaseFirestore.instance;
    postService = PostService();
  });

  setUp(() async {
    await FirebaseEmulatorHelper.clearFirestore();

    // Create test user
    final credential = await FirebaseEmulatorHelper.createTestUser(
      email: 'post-test@example.com',
      password: 'testpass123',
    );
    testUserId = credential.user!.uid;
    testUserDisplayName = 'Test User';

    // Create user profile
    await firestore.collection('users').doc(testUserId).set({
      ...TestDataGenerator.userProfileData(email: 'post-test@example.com'),
      'displayName': testUserDisplayName,
    });
  });

  tearDown(() async {
    await FirebaseEmulatorHelper.signOut();
  });

  group('Post CRUD Operations', () {
    test('Create: createPost creates a new post', () async {
      // Act
      final result = await postService.createPost(
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        category: PostCategory.general,
        content: 'This is my first post! #hello #test',
      );

      // Assert
      expect(result.isSuccess, true);
      // createPost returns Post object, not String
      final post = result.valueOrNull;
      expect(post, isNotNull);
      final postId = post!.id;

      // Verify in Firestore
      final doc = await firestore.collection('posts').doc(postId).get();
      expect(doc.exists, true);
      expect(doc.data()?['userId'], testUserId);
      expect(doc.data()?['content'], contains('first post'));
      expect(doc.data()?['hashtags'], containsAll(['hello', 'test']));
    });

    test('Create: createPost with vehicle tag', () async {
      // Arrange: Create a vehicle
      final vehicleRef = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(userId: testUserId),
          );

      // Act — vehicleTag: PostVehicleTag? (not vehicleId: String)
      // Since we can't easily construct PostVehicleTag without knowing its fields,
      // create a post without vehicle tag and verify the structure
      final result = await postService.createPost(
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        category: PostCategory.carLife,
        content: 'Check out my car!',
        vehicleTag: PostVehicleTag(
          vehicleId: vehicleRef.id,
          makerId: 'toyota',
          makerName: 'Toyota',
          modelName: 'Prius',
        ),
      );

      // Assert
      expect(result.isSuccess, true);
      final post = result.valueOrNull;
      expect(post, isNotNull);
      final postId = post!.id;

      final doc = await firestore.collection('posts').doc(postId).get();
      expect(doc.data()?['vehicleTag']?['vehicleId'], vehicleRef.id);
    });

    test('Read: getPost retrieves an existing post', () async {
      // Arrange
      final docRef = await firestore.collection('posts').add(
            TestDataGenerator.postData(
              userId: testUserId,
              content: 'Test post content',
            ),
          );

      // Act
      final result = await postService.getPost(docRef.id);

      // Assert
      expect(result.isSuccess, true);
      final post = result.valueOrNull;
      expect(post?.id, docRef.id);
      expect(post?.content, 'Test post content');
    });

    test('Read: getFeed retrieves posts for feed', () async {
      // Arrange: Create multiple posts
      await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'visibility': 'public',
      });
      await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'visibility': 'public',
      });

      // Act
      final result = await postService.getFeed(limit: 10);

      // Assert
      expect(result.isSuccess, true);
      final posts = result.valueOrNull;
      expect(posts, isNotNull);
      expect(posts?.length, greaterThanOrEqualTo(2));
    });

    test('Read: getUserPosts retrieves posts for a specific user', () async {
      // Arrange
      await firestore.collection('posts').add(
            TestDataGenerator.postData(userId: testUserId),
          );
      await firestore.collection('posts').add(
            TestDataGenerator.postData(userId: testUserId),
          );
      // Add post from different user
      await firestore.collection('posts').add(
            TestDataGenerator.postData(userId: 'other-user'),
          );

      // Act — requires both userId and viewerId named parameters
      final result = await postService.getUserPosts(
        userId: testUserId,
        viewerId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);
      final posts = result.valueOrNull;
      expect(posts?.length, 2);
      expect(posts?.every((p) => p.userId == testUserId), true);
    });

    test('Read: searchByHashtag finds posts with specific hashtag', () async {
      // Arrange
      await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'hashtags': ['flutter', 'dart'],
      });
      await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'hashtags': ['car', 'drive'],
      });

      // Act — uses named parameter 'hashtag:'
      final result = await postService.searchByHashtag(hashtag: 'flutter');

      // Assert
      expect(result.isSuccess, true);
      final posts = result.valueOrNull;
      expect(posts?.every((p) => p.hashtags.contains('flutter')), true);
    });

    test('Update: updatePost modifies post content', () async {
      // Arrange
      final docRef = await firestore.collection('posts').add(
            TestDataGenerator.postData(userId: testUserId),
          );

      await Future.delayed(const Duration(milliseconds: 100));

      // Act — uses named parameters: postId, userId, content (not Post object)
      final result = await postService.updatePost(
        postId: docRef.id,
        userId: testUserId,
        content: 'Updated content #updated',
      );

      // Assert
      expect(result.isSuccess, true);

      final doc = await firestore.collection('posts').doc(docRef.id).get();
      expect(doc.data()?['content'], 'Updated content #updated');
      expect(doc.data()?['isEdited'], true);
    });

    test('Delete: deletePost removes post', () async {
      // Arrange
      final docRef = await firestore.collection('posts').add(
            TestDataGenerator.postData(userId: testUserId),
          );

      // Act — uses named parameters
      final result = await postService.deletePost(
        postId: docRef.id,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      final doc = await firestore.collection('posts').doc(docRef.id).get();
      expect(doc.exists, false);
    });

    group('Edge Cases', () {
      test('createPost: empty content still creates post (no validation in service)',
          () async {
        // The service does not validate content length — this tests actual behavior
        final result = await postService.createPost(
          userId: testUserId,
          userDisplayName: testUserDisplayName,
          category: PostCategory.general,
          content: '',
        );
        // Currently no server-side validation, so it succeeds
        // This test documents the current behavior
        expect(result.isSuccess, true);
      });

      test('updatePost: wrong userId returns permission error', () async {
        final docRef = await firestore.collection('posts').add(
              TestDataGenerator.postData(userId: testUserId),
            );

        final result = await postService.updatePost(
          postId: docRef.id,
          userId: 'wrong-user-id',
          content: 'Malicious edit',
        );

        expect(result.isFailure, true);
      });

      test('deletePost: wrong userId returns permission error', () async {
        final docRef = await firestore.collection('posts').add(
              TestDataGenerator.postData(userId: testUserId),
            );

        final result = await postService.deletePost(
          postId: docRef.id,
          userId: 'wrong-user-id',
        );

        expect(result.isFailure, true);
        // Original post should still exist
        final doc = await firestore.collection('posts').doc(docRef.id).get();
        expect(doc.exists, true);
      });
    });
  });

  group('Post Like Operations', () {
    late String testPostId;

    setUp(() async {
      final docRef = await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'likeCount': 0,
      });
      testPostId = docRef.id;
    });

    test('Like: likePost adds a like', () async {
      // Act — uses named parameters
      final result = await postService.likePost(
        postId: testPostId,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify like document in 'post_likes' collection
      final likeDoc = await firestore
          .collection('post_likes')
          .doc('${testPostId}_$testUserId')
          .get();
      expect(likeDoc.exists, true);
    });

    test('Unlike: unlikePost removes a like', () async {
      // Arrange: Add like
      await firestore
          .collection('post_likes')
          .doc('${testPostId}_$testUserId')
          .set({
        'postId': testPostId,
        'userId': testUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Act — uses named parameters
      final result = await postService.unlikePost(
        postId: testPostId,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      final likeDoc = await firestore
          .collection('post_likes')
          .doc('${testPostId}_$testUserId')
          .get();
      expect(likeDoc.exists, false);
    });

    test('Check: isPostLiked correctly identifies liked status', () async {
      // Initially not liked — isPostLiked returns Future<bool>, not Result<bool>
      var isLiked = await postService.isPostLiked(
        postId: testPostId,
        userId: testUserId,
      );
      expect(isLiked, false);

      // Add like
      await firestore
          .collection('post_likes')
          .doc('${testPostId}_$testUserId')
          .set({
        'postId': testPostId,
        'userId': testUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Now should be liked
      isLiked = await postService.isPostLiked(
        postId: testPostId,
        userId: testUserId,
      );
      expect(isLiked, true);
    });

    test('Like updates likeCount on post', () async {
      // Get initial count
      var doc = await firestore.collection('posts').doc(testPostId).get();
      final initialCount = doc.data()?['likeCount'] ?? 0;

      // Like the post — uses named parameters
      await postService.likePost(postId: testPostId, userId: testUserId);

      // Verify count increased
      doc = await firestore.collection('posts').doc(testPostId).get();
      expect(doc.data()?['likeCount'], initialCount + 1);
    });
  });

  group('Comment Operations', () {
    late String testPostId;

    setUp(() async {
      final docRef = await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'commentCount': 0,
      });
      testPostId = docRef.id;
    });

    test('Create: addComment adds a comment to post', () async {
      // Act
      final result = await postService.addComment(
        postId: testPostId,
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        content: 'Great post!',
      );

      // Assert
      expect(result.isSuccess, true);
      // addComment returns Result<Comment>, get id from the Comment object
      final comment = result.valueOrNull;
      expect(comment, isNotNull);
      final commentId = comment!.id;

      // Verify comment exists in top-level 'comments' collection
      final commentDoc =
          await firestore.collection('comments').doc(commentId).get();
      expect(commentDoc.exists, true);
      expect(commentDoc.data()?['content'], 'Great post!');
    });

    test('Read: getComments retrieves comments for post', () async {
      // Arrange: Add comments directly to 'comments' collection
      await firestore.collection('comments').add({
        'postId': testPostId,
        'userId': testUserId,
        'userDisplayName': testUserDisplayName,
        'content': 'Comment 1',
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
      });
      await firestore.collection('comments').add({
        'postId': testPostId,
        'userId': testUserId,
        'userDisplayName': testUserDisplayName,
        'content': 'Comment 2',
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
      });

      // Act — uses named parameter 'postId:'
      final result = await postService.getComments(postId: testPostId);

      // Assert
      expect(result.isSuccess, true);
      final comments = result.valueOrNull;
      expect(comments?.length, 2);
    });

    test('Create: addComment with reply (parent comment)', () async {
      // Arrange: Add parent comment
      final parentResult = await postService.addComment(
        postId: testPostId,
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        content: 'Parent comment',
      );
      final parentCommentId = parentResult.valueOrNull!.id;

      // Act: Add reply
      final result = await postService.addComment(
        postId: testPostId,
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        content: 'This is a reply',
        parentCommentId: parentCommentId,
      );

      // Assert
      expect(result.isSuccess, true);
      final replyId = result.valueOrNull!.id;

      final replyDoc =
          await firestore.collection('comments').doc(replyId).get();
      expect(replyDoc.data()?['parentCommentId'], parentCommentId);
    });

    test('Read: getReplies retrieves replies for a comment', () async {
      // Arrange: Add parent and replies
      final parentResult = await postService.addComment(
        postId: testPostId,
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        content: 'Parent',
      );
      final parentCommentId = parentResult.valueOrNull!.id;

      await firestore.collection('comments').add({
        'postId': testPostId,
        'userId': testUserId,
        'content': 'Reply 1',
        'parentCommentId': parentCommentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await firestore.collection('comments').add({
        'postId': testPostId,
        'userId': testUserId,
        'content': 'Reply 2',
        'parentCommentId': parentCommentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Act — uses named parameter 'commentId:' only (no postId needed)
      final result = await postService.getReplies(commentId: parentCommentId);

      // Assert
      expect(result.isSuccess, true);
      final replies = result.valueOrNull;
      expect(replies?.length, 2);
    });

    test('Delete: deleteComment removes comment', () async {
      // Arrange
      final commentResult = await postService.addComment(
        postId: testPostId,
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        content: 'To be deleted',
      );
      final commentId = commentResult.valueOrNull!.id;

      // Act — uses named parameters: commentId and userId (no postId)
      final result = await postService.deleteComment(
        commentId: commentId,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      final doc = await firestore.collection('comments').doc(commentId).get();
      expect(doc.exists, false);
    });

    test('Comment updates commentCount on post', () async {
      // Get initial count
      var doc = await firestore.collection('posts').doc(testPostId).get();
      final initialCount = doc.data()?['commentCount'] ?? 0;

      // Add comment
      await postService.addComment(
        postId: testPostId,
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        content: 'New comment',
      );

      // Verify count increased
      doc = await firestore.collection('posts').doc(testPostId).get();
      expect(doc.data()?['commentCount'], initialCount + 1);
    });

    group('Edge Cases', () {
      test('deleteComment: wrong userId returns permission error', () async {
        final commentResult = await postService.addComment(
          postId: testPostId,
          userId: testUserId,
          userDisplayName: testUserDisplayName,
          content: 'Protected comment',
        );
        final commentId = commentResult.valueOrNull!.id;

        final result = await postService.deleteComment(
          commentId: commentId,
          userId: 'wrong-user-id',
        );

        expect(result.isFailure, true);
        // Comment should still exist
        final doc =
            await firestore.collection('comments').doc(commentId).get();
        expect(doc.exists, true);
      });
    });
  });

  group('Comment Like Operations', () {
    late String testPostId;
    late String testCommentId;

    setUp(() async {
      final postRef = await firestore.collection('posts').add(
            TestDataGenerator.postData(userId: testUserId),
          );
      testPostId = postRef.id;

      final commentResult = await postService.addComment(
        postId: testPostId,
        userId: testUserId,
        userDisplayName: testUserDisplayName,
        content: 'Test comment',
      );
      testCommentId = commentResult.valueOrNull!.id;
    });

    test('likeComment adds a like to comment', () async {
      // Act — uses named parameters: commentId and userId (no postId)
      final result = await postService.likeComment(
        commentId: testCommentId,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify like document in 'comment_likes' collection
      final likeDoc = await firestore
          .collection('comment_likes')
          .doc('${testCommentId}_$testUserId')
          .get();
      expect(likeDoc.exists, true);
    });
  });

  group('View Count Operations', () {
    late String testPostId;

    setUp(() async {
      final docRef = await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'viewCount': 0,
      });
      testPostId = docRef.id;
    });

    test('incrementViewCount increases view count', () async {
      // Get initial count
      var doc = await firestore.collection('posts').doc(testPostId).get();
      final initialCount = doc.data()?['viewCount'] ?? 0;

      // Act — incrementViewCount returns Future<void>, not Result
      await postService.incrementViewCount(testPostId);

      // Verify count increased by checking Firestore directly
      doc = await firestore.collection('posts').doc(testPostId).get();
      expect(doc.data()?['viewCount'], initialCount + 1);
    });
  });

  group('Feed Watching', () {
    test('watchFeed returns a stream of posts', () async {
      // Arrange
      await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'visibility': 'public',
      });

      // Act
      final stream = postService.watchFeed();

      // Assert
      expect(stream, isA<Stream<List<Post>>>());

      // Get first emission
      final posts = await stream.first;
      expect(posts, isA<List<Post>>());
    });
  });

  group('Post Visibility', () {
    test('Private posts are not returned in public feed', () async {
      // Arrange: Create public and private posts
      await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'visibility': 'public',
      });
      await firestore.collection('posts').add({
        ...TestDataGenerator.postData(userId: testUserId),
        'visibility': 'private',
      });

      // Act
      final result = await postService.getFeed();

      // Assert
      expect(result.isSuccess, true);
      final posts = result.valueOrNull;
      // Only public posts should be returned
      expect(posts?.every((p) => p.visibility == PostVisibility.public), true);
    });
  });

  group('Error Handling', () {
    test('Getting non-existent post returns failure', () async {
      // Act
      final result = await postService.getPost('non-existent-id');

      // Assert
      expect(result.isFailure, true);
    });

    test('Deleting post with wrong user ID fails', () async {
      // Arrange
      final docRef = await firestore.collection('posts').add(
            TestDataGenerator.postData(userId: testUserId),
          );

      // Act: Try to delete with wrong user — uses named parameters
      final result = await postService.deletePost(
        postId: docRef.id,
        userId: 'wrong-user-id',
      );

      // Assert: Should fail
      expect(result.isFailure, true);

      // Post should still exist
      final doc = await firestore.collection('posts').doc(docRef.id).get();
      expect(doc.exists, true);
    });
  });
}
