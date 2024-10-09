import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '/models/post_model.dart';
import 'details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _cleanupEmptyPosts();
    setState(() {});
  }

  Future<void> _cleanupEmptyPosts() async {
    var box = await Hive.openBox<Post>('postsBox');
    final postsToDelete = box.keys.where((key) {
      final post = box.get(key);
      return post != null && post.images.isEmpty;
    }).toList();

    // Delete the identified posts
    for (var key in postsToDelete) {
      await box.delete(key);
    }
  }

  Future<void> _loadPosts() async {
    final posts = await getPosts();
    setState(() {
      _posts = posts;
    });
  }

  Future<void> savePost(Post post) async {
    var box = await Hive.openBox<Post>('postsBox');
    await box.put(post.id, post); // Save with ID as key
  }

  Future<List<Post>> getPosts() async {
    var box = await Hive.openBox<Post>('postsBox');
    return box.values.toList();
  }

  void _deletePost(String postId) async {
    try {
      final box = await Hive.openBox<Post>('postsBox');
      final post = box.get(postId);

      // Check if the post and images exist
      if (post != null && post.images.isNotEmpty) {
        for (var imagePath in post.images) {
          final file = File(imagePath);

          // Check if the file exists before attempting to delete
          if (await file.exists()) {
            try {
              await file.delete();
              print('File deleted: $imagePath');
            } catch (e) {
              print('Failed to delete file $imagePath: $e');
              // Optionally show an error message to the user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete file: $e')),
              );
            }
          } else {
            print('File does not exist: $imagePath');
          }
        }
      }

      // Attempt to delete the post using its ID
      await box.delete(postId);

      // Update the in-memory list and rebuild the UI
      setState(() {
        _posts.removeWhere((post) => post.id == postId);
      });
    } catch (e) {
      // Catch any error and print it or display it in the UI
      print('Error deleting post: $e');

      // Optionally show a dialog or a Snackbar with the error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _deletePost(postId); // Pass the post ID
                Navigator.of(context).pop();
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImagesAndSave() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      final now = DateTime.now();
      final newTitle = 'PS ${DateFormat('yyyy-MM-dd HH:mm').format(now)}';
      final newPost = Post(
        title: newTitle,
        images: pickedFiles.map((x) => x.path).toList(),
        time: now,
      ); // A unique ID will be automatically generated
      await savePost(newPost);
      _loadPosts();

      // Navigate to the DetailsScreen after saving the post
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsScreen(
            post: newPost,
            index: _posts.length, // Use the last index for the new post
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadPosts();
    _cleanupEmptyPosts();

    //
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pdf Scanner',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),

      //
      body: _posts.isNotEmpty
          ? ValueListenableBuilder<Box<Post>>(
              valueListenable: Hive.box<Post>('postsBox').listenable(),
              builder: (context, box, _) {
                _posts = box.values.toList();
                return ListView.separated(
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _posts.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final post = _posts[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsScreen(
                              post: post,
                              index: index,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey.shade100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (post.images.isNotEmpty &&
                                post.images[0].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    File(post.images[0]),
                                    height: 80,
                                    width: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.image_outlined,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post.images.length} image${post.images.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd-MM-yy hh:mm a')
                                            .format(post.time),
                                        style: const TextStyle(
                                            fontSize: 14, height: 1),
                                      ),
                                      Container(
                                        margin:
                                            const EdgeInsets.only(right: 12),
                                        child: GestureDetector(
                                          onTap: () {
                                            _showDeleteConfirmationDialog(
                                                context, post.id);
                                          },
                                          child: const Icon(
                                              Icons.delete_outline_outlined),
                                        ),
                                      ),
                                    ],
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
            )
          : const Center(
              child: Text('No Files found'),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          //
          _pickImagesAndSave();
        },
        label: const Text('Import from Gallery'),
      ),
    );
  }
}
