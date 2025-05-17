import 'package:flutter/material.dart';
import 'package:t_archive/t_archive.dart';
import 'package:t_archive/t_archive_file.dart';

void main() async {
  final tArchive = TArchive.createFiles([
    TArchiveFile.fromFile('/home/thancoder/Videos/【GMV】- BOSS B_TCH.mp4'),
  ]);
  // TArchive.createFiles([TArchiveFile('name', Uint8List(0))], config: {});

  // save
  tArchive.writeToFile(
    'savepath.bin',
    // coverImage: File('cover.png').readAsBytesSync(),
    onProgress: (name, progress) {
      print('$name - ${(progress * 100).toStringAsFixed(1)}%');
    },
  );

  //read
  final archive = await TArchive.readHeader('savepath.bin');
  print(archive.config);
  print(archive.mime);
  print(archive.version);
  print(archive.coverImage);
  print(archive.files);
  await TArchive.deleteFile('savepath.bin', filename: archive.files.first.name);
  print('deleted');
  archive.files.first.writeFile(
    'out.mp4',
    onProgress: (progress) {
      print('${(progress * 100).toStringAsFixed(1)}%');
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: Placeholder()));
  }
}
