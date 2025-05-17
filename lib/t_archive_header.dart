// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:typed_data';

import 'package:t_archive/t_file_entry_info.dart';

class TArchiveHeader {
  final String mime;
  final int version;
  final int flags;
  final Uint8List? coverImage;
  final Map<String, dynamic> config;
  final List<TFileEntryInfo> files;

  TArchiveHeader({
    required this.mime,
    required this.version,
    required this.flags,
    required this.coverImage,
    required this.config,
    required this.files,
  });
}

class FileEntryInfo {
  final String name;
  final int offset;
  final int length;

  FileEntryInfo(this.name, this.offset, this.length);
}
