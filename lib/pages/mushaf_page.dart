import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_assistant/core/api/ffi.dart';
import 'package:quran_assistant/pages/quran_detail_page.dart';
import 'package:quran_assistant/utils/download_utils.dart';


class MushafPage extends StatefulWidget {
  final int pageNumber; // Halaman default
  const MushafPage({super.key, this.pageNumber = 1});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  String? selectedVariant; // width_720 / 1080 / 1440

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectAndStart());
  }

  void _detectAndStart() async {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1440) {
      selectedVariant = 'width_1440';
    } else if (width >= 1080) {
      selectedVariant = 'width_1080';
    } else {
      selectedVariant = 'width_720';
    }

    final dir = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${dir.path}/$selectedVariant');

    final firstImage = File('${outputDir.path}/page001.png');
    if (await firstImage.exists()) {
      _navigateToQuran();
    } else {
      startDownload(
        context,
        url: 'https://quran.tsaqafah.id/$selectedVariant.tar.zst',
        filename: '$selectedVariant.tar.zst',
        onSuccess: () {
          // decompress setelah selesai download
          final inputPath = '${dir.path}/$selectedVariant.tar.zst';
          final outputPath = outputDir.path;

          decompressFile(inputPath, outputPath);
          _navigateToQuran();
        },
      );
    }
  }

  void _navigateToQuran() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPerPage(resolution: selectedVariant!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
