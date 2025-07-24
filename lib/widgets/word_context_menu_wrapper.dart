// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:quran_assistant/widgets/verse_detail_bottom_sheet.dart';
// import 'package:super_context_menu/super_context_menu.dart';

// // import 'package:quran_assistant/ui/widgets/verse_detail_bottom_sheet.dart';

// class WordContextMenuWrapper extends StatelessWidget {
//   final Widget child;
//   final String verseKey;
//   final String ayahText;

//   const WordContextMenuWrapper({
//     super.key,
//     required this.child,
//     required this.verseKey,
//     required this.ayahText,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ContextMenuWidget(
//       previewBuilder: (context, child) {
//         return Material(
//           color: Colors.blue.shade50,
//           borderRadius: BorderRadius.circular(8),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Text(
//               ayahText,
//               textDirection: TextDirection.rtl,
//               style: const TextStyle(fontSize: 20),
//             ),
//           ),
//         );
//       },
//       liftBuilder: (context, child) => Container(
//         color: Colors.amber.withOpacity(0.3),
//         child: child,
//       ),
//       child: child,
//       menuProvider: (_) {
//         return Menu(
//           children: [
//             MenuAction(
//               title: '📖 Lihat Detail Ayah Ini',
//               image: MenuImage.icon(Icons.info_outline),
//               callback: () {
//                 _showVerseDetailModal(context, verseKey);
//               },
//             ),
//             MenuSeparator(),
//             MenuAction(
//               title: '📋 Salin Ayah Ini',
//               image: MenuImage.icon(Icons.copy),
//               callback: () {
//                 Clipboard.setData(ClipboardData(text: ayahText));
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Ayah disalin')),
//                 );
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showVerseDetailModal(BuildContext context, String verseKey) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => VerseDetailBottomSheet(verseKey: verseKey),
//     );
//   }
// }
