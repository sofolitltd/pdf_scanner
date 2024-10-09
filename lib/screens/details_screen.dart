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
  bool _isSelectionMode = false; // Track selection mode
  final TextEditingController _titleController = TextEditingController();
  late List<bool> _selectedImages; // Track selected images
  late List<int> _selectedIndices; // Track selected indices

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.post.title;

    // Initialize selection state
    _selectedImages = List.generate(widget.post.images.length, (_) => false);
    _selectedIndices = [];
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
                fit: pw.BoxFit.fitWidth, // Cover the entire page
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF created at: $pdfFilePath")),
        );

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

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      var box = Hive.box<Post>('postsBox');

      // Update the list of images in the current Post object
      widget.post.images.addAll(pickedFiles.map((x) => x.path));

      // Update the selection list to match the number of images
      _selectedImages.addAll(List.generate(pickedFiles.length, (_) => false));

      // Create a new Post object with the updated images and the same ID
      final updatedPost = Post(
        id: widget.post.id, // Use the existing ID
        title: _titleController.text.trim(),
        images: widget.post.images,
        time: widget.post.time,
      );

      // Replace the old Post with the updated one using its ID
      await box.put(widget.post.id, updatedPost);

      setState(() {}); // Rebuild the UI
    }
  }

  void _deleteSelectedImages() {
    setState(() {
      _selectedIndices
          .sort((a, b) => b.compareTo(a)); // Sort in descending order
      for (var index in _selectedIndices) {
        widget.post.images.removeAt(index);
      }
      _cleanupEmptyPosts();

      // Reset the selection list to match the number of remaining images
      _selectedImages = List.generate(widget.post.images.length, (_) => false);

      _selectedIndices.clear(); // Clear selected indices
      _isSelectionMode = false; // Exit selection mode

      // If there are no images left, pop the screen
      if (widget.post.images.isEmpty) {
        Navigator.pop(context);
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      _selectedImages[index] = !_selectedImages[index];
      if (_selectedImages[index]) {
        _selectedIndices.add(index);
      } else {
        _selectedIndices.remove(index);
      }
    });
  }

  void _toggleSelectAll() {
    if (_selectedIndices.length == widget.post.images.length) {
      // Deselect all
      setState(() {
        _selectedImages =
            List.generate(widget.post.images.length, (_) => false);
        _selectedIndices.clear();
      });
    } else {
      // Select all
      setState(() {
        _selectedImages = List.generate(widget.post.images.length, (_) => true);
        _selectedIndices =
            List.generate(widget.post.images.length, (index) => index);
      });
    }
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedImages = List.generate(widget.post.images.length, (_) => false);
      _selectedIndices.clear();
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
          if (_isSelectionMode)
            OutlinedButton(
              onPressed: _cancelSelection,
              child:
                  const Text('Cancel'), // Cancel button when in selection mode
            )
          else
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _isGridMode ? 2 : 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: _isGridMode ? 10 : 16,
          childAspectRatio: .8,
        ),
        padding: const EdgeInsets.all(10),
        itemCount: widget.post.images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onLongPress: () {
              if (!_isSelectionMode) {
                // Activate selection mode on first long press
                setState(() {
                  _isSelectionMode = true;
                });
                _toggleSelection(index); // Select the long-pressed image
              }
            },
            onTap: () {
              if (_isSelectionMode) {
                // If in selection mode, toggle selection
                _toggleSelection(index);
              } else {
                // Otherwise, go to the ImageEditPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageEditPage(
                      imagePaths: widget.post.images,
                      initialIndex: index,
                    ),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                // color: _selectedImages[index]
                //     ? Colors.blue.withOpacity(0.5)
                //     : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(.05),
                    spreadRadius: 3,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedImages[index]
                        ? Colors.red
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    GridTile(
                      footer: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        color: Colors.black26,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      child: Image.file(
                        File(widget.post.images[index]),
                        fit: _isGridMode ? BoxFit.cover : BoxFit.contain,
                      ),
                    ),
                    if (_isSelectionMode) // Show selection circle if in selection mode
                      Positioned(
                        top: 8,
                        left: 8,
                        child: GestureDetector(
                          onTap: () => _toggleSelection(index),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: _selectedImages[index]
                                ? Colors.blue
                                : Colors.white,
                            child: _selectedImages[index]
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : const Icon(
                                    Icons.circle_outlined,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: () => _showReorderModal(context),
                    icon: const Icon(
                      Icons.layers,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleSelectAll, // Toggle select/deselect all
                    icon: Icon(
                      _selectedIndices.length == widget.post.images.length
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                  ),
                  IconButton(
                    onPressed: _deleteSelectedImages,
                    icon: const Icon(Icons.delete),
                  ),
                  IconButton(
                    onPressed: () async {
                      final pdfFile = await _createPDF(context);
                      if (pdfFile != null) {
                        await Share.shareXFiles([XFile(pdfFile.path)]);
                      }
                    },
                    icon: const Icon(Icons.share),
                  ),
                ],
              ),
            )
          : Container(
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
                    icon: Icon(_isGridMode ? Icons.grid_view : Icons.list),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageEditPage(
                            imagePaths: widget.post.images,
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                    ),
                    child: IconButton(
                      onPressed: () {
                        _pickImages();
                      },
                      icon: const Icon(
                        Icons.add,
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
                    icon: const Icon(Icons.share),
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
    );
  }

  //
  void _showReorderModal(BuildContext context) {
    //

    //
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ReorderableImageGrid(
            images: widget.post.images, // Pass the images list
            selectedImages: _selectedImages, // Pass the selection state
            onReorderComplete: (reorderedImages) {
              setState(() {
                widget.post.images.clear();
                widget.post.images.addAll(reorderedImages);
              });
            },
          ),
        );
      },
    );
  }
}

class ReorderableImageGrid extends StatefulWidget {
  final List<String> images;
  final List<bool> selectedImages;
  final Function(List<String>) onReorderComplete;

  const ReorderableImageGrid({
    Key? key,
    required this.images,
    required this.selectedImages,
    required this.onReorderComplete,
  }) : super(key: key);

  @override
  _ReorderableImageGridState createState() => _ReorderableImageGridState();
}

class _ReorderableImageGridState extends State<ReorderableImageGrid> {
  late List<String> _currentImages;
  late List<bool> _currentSelections;

  @override
  void initState() {
    super.initState();
    _currentImages = List.from(widget.images);
    _currentSelections = List.from(widget.selectedImages);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reorder Images'),
          actions: [
            OutlinedButton(
              onPressed: () {
                widget.onReorderComplete(_currentImages);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
        body: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .8,
          ),
          itemCount: _currentImages.length,
          itemBuilder: (context, index) {
            return LongPressDraggable<int>(
              data: index,
              feedback: Material(
                child: _buildDragFeedback(),
              ),
              childWhenDragging: Container(
                color:
                    Colors.blue.withOpacity(0.5), // Blue overlay for dragging
                height: 88,
                width: 88,
              ),
              child: DragTarget<int>(
                onAccept: (oldIndex) {
                  setState(() {
                    _reorderImages(oldIndex, index);
                  });
                  widget.onReorderComplete(_currentImages);
                },
                onWillAccept: (oldIndex) {
                  // Prevent dropping on selected items
                  return !_currentSelections[index];
                },
                builder: (context, candidateData, rejectedData) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentSelections[index] = !_currentSelections[index];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _currentSelections[index]
                              ? Colors.red
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          //
                          GridTile(
                            footer: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              color: Colors.black26,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            child: Image.file(
                              File(_currentImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),

                          //
                          Positioned(
                            top: 8,
                            left: 8,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: _currentSelections[index]
                                  ? Colors.blue
                                  : Colors.white,
                              child: _currentSelections[index]
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : const Icon(
                                      Icons.circle_outlined,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // Create a method to build the drag feedback for multiple images
  Widget _buildDragFeedback() {
    final selectedImages = _currentImages
        .asMap()
        .entries
        .where((entry) => _currentSelections[entry.key])
        .map((entry) => entry.value)
        .toList();

    return Stack(
      alignment: Alignment.center,
      children: [
        // Show stacked previews of selected images with rotation and offset
        ...selectedImages.asMap().entries.map((entry) {
          final index = entry.key;
          final imagePath = entry.value;

          // Add rotation and translation for the stacking effect
          return Transform(
            transform: Matrix4.identity()
              ..rotateZ(index * 0.1) // Rotate each image by a small angle
              ..translate(index * 10.0, index * 5.0), // Shift each image
            child: Container(
              margin: const EdgeInsets.all(4),
              child: Image.file(
                File(imagePath),
                width: 100, // Adjust the size of each image in the stack
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          );
        }).toList(),
        // Count overlay to show how many images are selected
        if (selectedImages.isNotEmpty)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${selectedImages.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _reorderImages(int oldIndex, int newIndex) {
    final selectedIndices = _currentSelections
        .asMap()
        .entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // If moving multiple images
    if (selectedIndices.isNotEmpty) {
      // Prevent dropping on selected items
      if (selectedIndices.contains(newIndex)) return;

      // Calculate the final insertion point based on the first selected index
      // First selected item should take the newIndex position
      final firstSelectedIndex = selectedIndices.first;

      // Remove the selected images from their original positions
      final imagesToMove =
          selectedIndices.map((i) => _currentImages[i]).toList();

      // If moving down, adjust newIndex by the count of selected images
      if (oldIndex < newIndex) {
        newIndex -=
            selectedIndices.length - 1; // Adjust newIndex if moving down
      }

      // Validate the newIndex to ensure it's within bounds
      newIndex = newIndex.clamp(0, _currentImages.length - 1);

      setState(() {
        // Remove images from their original positions (in reverse order)
        for (var index in selectedIndices.reversed) {
          _currentImages.removeAt(index);
          _currentSelections.removeAt(index); // Remove selection state as well
        }

        // Insert the first selected image at newIndex
        _currentImages.insert(newIndex, imagesToMove.first);
        _currentSelections.insert(newIndex, false); // Deselect after moving

        // Insert the rest of the selected images
        for (var i = 1; i < imagesToMove.length; i++) {
          _currentImages.insert(newIndex + i, imagesToMove[i]);
          _currentSelections.insert(
              newIndex + i, false); // Deselect after moving
        }
      });
    } else {
      // For single image moving
      if (oldIndex < newIndex) {
        newIndex--;
      }
      newIndex = newIndex.clamp(
          0, _currentImages.length - 1); // Ensure newIndex is valid
      setState(() {
        final item = _currentImages.removeAt(oldIndex);
        _currentImages.insert(newIndex, item);

        // Also move selection state for the item being moved
        final selectedItem = _currentSelections.removeAt(oldIndex);
        _currentSelections.insert(newIndex, selectedItem);
      });
    }
  }
}
