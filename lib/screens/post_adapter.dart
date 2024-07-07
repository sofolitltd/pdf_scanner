// post_adapter.dart
import 'package:hive/hive.dart';

import '/models/post_model.dart';

class PostAdapter extends TypeAdapter<Post> {
  @override
  final int typeId = 0; // Assign a unique ID

  @override
  Post read(BinaryReader reader) {
    final title = reader.readString();
    final images = (reader.readList() as List).cast<String>();
    final timeInt =
        reader.readInt(); // Store time as int (milliseconds since epoch)
    final time = DateTime.fromMillisecondsSinceEpoch(timeInt);
    return Post(title: title, images: images, time: time);
  }

  @override
  void write(BinaryWriter writer, Post obj) {
    writer.writeString(obj.title);
    writer.writeList(obj.images);
    writer.writeInt(obj.time.millisecondsSinceEpoch); // Store time as int
  }
}
