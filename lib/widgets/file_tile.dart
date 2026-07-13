import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/file_entry.dart';

class FileIcon extends StatelessWidget {
  final FileEntry wpis;
  final bool miniatury;
  const FileIcon({super.key, required this.wpis, required this.miniatury});

  @override
  Widget build(BuildContext context) {
    final schemat = Theme.of(context).colorScheme;

    if (wpis.isImage && miniatury) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(wpis.path),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, __, ___) => _ikona(schemat),
          // Zapobiega migotaniu przy przewijaniu
          gaplessPlayback: true,
        ),
      );
    }
    return _ikona(schemat);
  }

  Widget _ikona(ColorScheme schemat) {
    IconData ikona;
    Color kolor;

    if (wpis.isDir) {
      ikona = Icons.folder_rounded;
      kolor = const Color(0xFFF6AD55);
    } else if (wpis.isZip) {
      ikona = Icons.folder_zip_rounded;
      kolor = const Color(0xFF9F7AEA);
    } else if (wpis.isImage) {
      ikona = Icons.image_rounded;
      kolor = const Color(0xFF48BB78);
    } else {
      switch (wpis.ext) {
        case 'pdf':
          ikona = Icons.picture_as_pdf_rounded;
          kolor = const Color(0xFFE53E3E);
          break;
        case 'mp3':
        case 'wav':
        case 'm4a':
        case 'flac':
        case 'ogg':
          ikona = Icons.music_note_rounded;
          kolor = const Color(0xFFED64A6);
          break;
        case 'mp4':
        case 'mkv':
        case 'avi':
        case 'mov':
        case 'webm':
          ikona = Icons.movie_rounded;
          kolor = const Color(0xFF4299E1);
          break;
        case 'doc':
        case 'docx':
        case 'odt':
          ikona = Icons.description_rounded;
          kolor = const Color(0xFF2B6CB0);
          break;
        case 'xls':
        case 'xlsx':
        case 'csv':
        case 'ods':
          ikona = Icons.table_chart_rounded;
          kolor = const Color(0xFF2F855A);
          break;
        case 'txt':
        case 'md':
        case 'log':
        case 'json':
        case 'xml':
          ikona = Icons.article_rounded;
          kolor = schemat.onSurfaceVariant;
          break;
        case 'apk':
          ikona = Icons.android_rounded;
          kolor = const Color(0xFF38A169);
          break;
        default:
          ikona = Icons.insert_drive_file_rounded;
          kolor = schemat.onSurfaceVariant;
      }
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Icon(ikona, color: kolor, size: 32),
    );
  }
}

class FileTile extends StatelessWidget {
  final FileEntry wpis;
  final bool zaznaczony;
  final bool trybSelekcji;
  final bool miniatury;
  final bool wycinany;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileTile({
    super.key,
    required this.wpis,
    required this.zaznaczony,
    required this.trybSelekcji,
    required this.miniatury,
    required this.wycinany,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final schemat = Theme.of(context).colorScheme;
    final format = DateFormat('dd.MM.yyyy HH:mm');

    final podtytul = wpis.isDir
        ? format.format(wpis.modified)
        : '${wpis.sizeLabel}  ·  ${format.format(wpis.modified)}';

    return Opacity(
      opacity: wycinany ? 0.45 : 1.0,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        selected: zaznaczony,
        selectedTileColor: schemat.primaryContainer.withOpacity(0.4),
        leading: trybSelekcji
            ? SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    zaznaczony
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: zaznaczony ? schemat.primary : schemat.outline,
                  ),
                ),
              )
            : FileIcon(wpis: wpis, miniatury: miniatury),
        title: Text(
          wpis.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: wpis.isDir ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          podtytul,
          style: TextStyle(fontSize: 12, color: schemat.onSurfaceVariant),
        ),
        trailing: wpis.isDir
            ? Icon(Icons.chevron_right_rounded, color: schemat.outline)
            : null,
      ),
    );
  }
}
