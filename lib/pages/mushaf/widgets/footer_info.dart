// lib/pages/mushaf/widgets/footer_info.dart
import 'package:flutter/material.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';

class FooterInfo extends StatelessWidget {
  final MushafPageInfo pageInfo;

  const FooterInfo({super.key, required this.pageInfo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pageInfo.nextPageRouteText,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textColor,
              fontFamily: 'UthmaniHafs',
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${pageInfo.pageNumber}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}