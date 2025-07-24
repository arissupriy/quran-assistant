// lib/pages/mushaf/widgets/header_info.dart
import 'package:flutter/material.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';

class HeaderInfo extends StatelessWidget {
  final MushafPageInfo pageInfo;

  const HeaderInfo({super.key, required this.pageInfo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pageInfo.surahNameArabic,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
              fontFamily: 'UthmaniHafs',
            ),
          ),
          Text(
            'Juz ${pageInfo.juzNumber}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}