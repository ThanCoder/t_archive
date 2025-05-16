import 'dart:io';
import 'dart:typed_data';

class TArchiveFile {
  final String name;
  final Uint8List data;

  TArchiveFile(this.name, this.data);

  factory TArchiveFile.fromFile(String path) {
    final file = File(path);
    return TArchiveFile(file.path.split('/').last, file.readAsBytesSync());
  }

  Map<String, dynamic> toMap() => {'name': name, 'size': data.length};

  @override
  String toString() {
    return name;
  }
}
