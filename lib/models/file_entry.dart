import 'dart:io';
import 'package:path/path.dart' as p;

enum SortBy { nazwa, data, rozmiar, typ }

class FileEntry {
  final FileSystemEntity entity;
  final bool isDir;
  final String name;
  final String path;
  final int size;
  final DateTime modified;

  FileEntry({
    required this.entity,
    required this.isDir,
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
  });

  static FileEntry? from(FileSystemEntity e) {
    try {
      final stat = e.statSync();
      final isDir = stat.type == FileSystemEntityType.directory;
      return FileEntry(
        entity: e,
        isDir: isDir,
        name: p.basename(e.path),
        path: e.path,
        size: isDir ? 0 : stat.size,
        modified: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }

  String get ext => isDir ? '' : p.extension(name).toLowerCase().replaceFirst('.', '');

  bool get isZip => ext == 'zip';

  bool get isApk => ext == 'apk';

  bool get isImage =>
      const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(ext);

  bool get isHidden => name.startsWith('.');

  String get sizeLabel {
    if (isDir) return '';
    const jednostki = ['B', 'KB', 'MB', 'GB', 'TB'];
    double s = size.toDouble();
    int i = 0;
    while (s >= 1024 && i < jednostki.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(i == 0 ? 0 : 1)} ${jednostki[i]}';
  }
}
