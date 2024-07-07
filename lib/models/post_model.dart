import 'package:uuid/uuid.dart';

class Post {
  final String id;
  final String title;
  final List<String> images;
  final DateTime time;

  Post({
    String? id,
    required this.title,
    required this.images,
    required this.time,
  }) : id = id ?? const Uuid().v4(); // Generate a UUID if no ID is provided
}
