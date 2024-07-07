import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_scanner/screens/image_edit_screen.dart';
import 'package:share_plus/share_plus.dart';

import '/models/post_model.dart';

class DetailsScreen extends StatefulWidget {
  final Post post;
  final int index;

  const DetailsScreen({
    super.key,
    required this.post,
    required this.index,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool _isGridMode = true;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.post.title;

    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      var box = Hive.box<Post>('postsBox');

      // Update the list of images in the current Post object
      widget.post.images.addAll(pickedFiles.map((x) => x.path));

      // Create a new Post object with the updated images and the same ID
      final updatedPost = Post(
        id: widget.post.id, // Use the existing ID
        title: _titleController.text.trim(),
        images: widget.post.images, time: widget.post.time,
      );

      // Replace the old Post with the updated one using its ID
      await box.put(widget.post.id, updatedPost);

      setState(() {}); // Rebuild the UI
    }
  }

  Future<void> _showEditTitleDialog(BuildContext context) async {
    String newTitle = _titleController.text;
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Title'),
          content: TextField(
            onChanged: (value) {
              newTitle = value;
            },
            controller: TextEditingController(text: newTitle),
            decoration: const InputDecoration(hintText: "Enter new title"),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.words,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                var box = Hive.box<Post>('postsBox');

                // Create a new Post object with the updated title and the same ID
                final updatedPost = Post(
                  id: widget.post.id, // Use the existing ID
                  title: newTitle,
                  images: widget.post.images,
                  time: widget.post.time,
                );

                // Replace the old Post with the updated one using its ID
                await box.put(widget.post.id, updatedPost);

                // Update the UI and close the dialog
                setState(() {
                  _titleController.text = newTitle;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<File?> _createPDF(BuildContext context) async {
    final pdf = pw.Document();
    for (var imagePath in widget.post.images) {
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        // Use await to check existence
        final imageBytes = await imageFile.readAsBytes();
        final imageWidget = pw.Image(pw.MemoryImage(imageBytes));

        //
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true, // Ignore any page margins
              child: pw.FittedBox(
                fit: pw.BoxFit.cover, // Cover the entire page
                child: imageWidget,
              ),
            );
          },
        ));
      } else {
        print("Image not found at path: $imagePath");
        // Consider displaying a Snackbar to inform the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image not found: $imagePath")),
        );
      }
    }

    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        final pdfFilePath =
            '${downloadDir.path}/${_titleController.text.trim()}.pdf';
        final pdfFile = File(pdfFilePath);
        await pdfFile.writeAsBytes(await pdf.save());
        print("PDF created at: $pdfFilePath");

        return pdfFile;
      } else {
        throw Exception("External storage directory not found");
      }
    } catch (e) {
      print("Error creating PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating PDF: ${e.toString()}")),
      );
      return null;
    }
  }

  void _deleteImage(int index) async {
    setState(() {
      widget.post.images.removeAt(index); // Remove image from the list

      // Update the Post object inHive
      final box = Hive.box<Post>('postsBox');
      final updatedPost = Post(
        id: widget.post.id,
        title: widget.post.title,
        images: widget.post.images, // Use the updated list
        time: widget.post.time,
      );
      box.put(widget.post.id, updatedPost);
      _cleanupEmptyPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            _showEditTitleDialog(context);
          },
          child: Container(
            padding: const EdgeInsets.only(bottom: 2, right: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.black38,
                ),
              ),
            ),
            child: Text(
              _titleController.text.trim(),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isGridMode
                ? GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: .8,
                    ),
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.post.images.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          GridTile(
                            footer: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 10,
                              ),
                              color: Colors.black26,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            child: Image.file(
                              File(widget.post.images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),

                          //
                          Positioned(
                            bottom: 6,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                _deleteImage(index);
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: widget.post.images.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Image.file(File(widget.post.images[index])),
                          Container(
                            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                            color: Colors.black26,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isGridMode = !_isGridMode;
                    });
                  },
                  icon: Icon(_isGridMode
                      ? Icons.photo_size_select_large_outlined
                      : Icons.list),
                ),

                //
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageEditPage(
                          imagePaths: widget.post.images,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),

                //
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.blueAccent,
                  ),
                  child: IconButton(
                    onPressed: () {
                      _pickImages();
                    },
                    icon: const Icon(
                      Icons.add_box_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final pdfFile = await _createPDF(context);
                    if (pdfFile != null) {
                      await Share.shareXFiles([XFile(pdfFile.path)]);
                    }
                  },
                  icon: const Icon(Icons.share_outlined),
                ),
                IconButton(
                  onPressed: () async {
                    final pdfFile = await _createPDF(context);
                    if (pdfFile != null) {
                      OpenFile.open(pdfFile.path);
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
