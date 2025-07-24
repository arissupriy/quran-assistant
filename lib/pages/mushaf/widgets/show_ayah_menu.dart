import 'package:flutter/material.dart';
import 'package:quran_assistant/pages/mushaf/mushaf_detail_ayah_page.dart';

Future<void> showAyahMenu({
  required BuildContext context,
  required int sura,
  required int ayah,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Lihat Detail Ayat'),
                onTap: () {
                  Navigator.pop(context); // tutup modal dulu
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MushafDetailAyahPage(
                        verseKey: '$sura:$ayah',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Lihat Terjemahan'),
                onTap: null,
              ),
              ListTile(
                leading: const Icon(Icons.compare),
                title: const Text('Ayat yang Serupa'),
                onTap: null,
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Salin Ayat'),
                onTap: null,
              ),
            ],
          ),
        ),
      );
    },
  );
}
