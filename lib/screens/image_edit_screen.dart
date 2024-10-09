import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_cropper/image_cropper.dart';

import '../models/post_model.dart';

class ImageEditPage extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const ImageEditPage({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialIndex;
  }

  Future<void> _cropImage(String imagePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
      ],
    );
    if (croppedFile != null) {
      // Save the cropped image to a new file
      final newFilePath = _getNewFilePath(imagePath);
      await File(croppedFile.path).copy(newFilePath);

      // Update the image path in your list
      final index = widget.imagePaths.indexOf(imagePath);
      if (index != -1) {
        setState(() {
          widget.imagePaths[index] = newFilePath;
        });
      }

      // Update the database (replace with your actual database logic)
      _updateImageInDatabase(imagePath, newFilePath);
    }
  }

  String _getNewFilePath(String originalPath) {
    final directory = Directory(originalPath).parent;
    final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return '${directory.path}/$fileName';
  }

  Future<void> _updateImageInDatabase(String oldPath, String newPath) async {
    var box = Hive.box<Post>('postsBox');

    // Find the Post that contains the old image path
    final posts = box.values.where((post) => post.images.contains(oldPath));
    if (posts.isNotEmpty) {
      final postToUpdate =
          posts.first; // Assuming only one post will contain the image

      // Update the image path in the Post
      final updatedImages = postToUpdate.images
          .map((image) => image == oldPath ? newPath : image)
          .toList();
      final updatedPost = Post(
        id: postToUpdate.id,
        title: postToUpdate.title,
        images: updatedImages,
        time: postToUpdate.time,
      );

      // Save the updated Post back to Hive
      await box.put(updatedPost.id, updatedPost);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Images'),
      ),
      bottomNavigationBar: Container(
        color: Colors.black12,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: () => _cropImage(widget.imagePaths[_currentPageIndex]),
              icon: const Icon(Icons.crop),
            ),
            // Add more buttons for filtering, zooming, etc.
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          //
          Container(
            color: Colors.white,
            child: PageView.builder(
              itemCount: widget.imagePaths.length,
              controller: PageController(
                  initialPage: _currentPageIndex), // Set initial page
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final imagePath = widget.imagePaths[index];
                return Image.file(
                  File(imagePath),
                  fit: BoxFit.fitWidth,
                );
              },
            ),
          ),

          //
          Positioned(
            top: 24,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                  '${_currentPageIndex + 1}/${widget.imagePaths.length}'), // Show current/total
            ),
          ),
        ],
      ),
    );
  }
}
