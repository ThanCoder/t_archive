// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:typed_data';

import 't_archive_response_file.dart';

class TArchiveResponse {
  Map<String, dynamic> config;
  Uint8List? coverImage;
  List<dynamic> fileMetaList;
  List<TArchiveResponseFile> fileList;
  int version;
  String mime;
  TArchiveResponse({
    required this.config,
    required this.mime,
    this.coverImage,
    required this.fileMetaList,
    required this.version,
    required this.fileList,
  });
}
