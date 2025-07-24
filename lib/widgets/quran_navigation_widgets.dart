import 'package:flutter/material.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';

// Widget kustom untuk Bottom Navigation Bar
// Widget kustom untuk Bottom Navigation Bar
// Widget kustom untuk Bottom Navigation Bar
// Widget kustom untuk Bottom Navigation Bar
class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex; // Indeks item yang saat ini dipilih
  final Function(int) onItemSelected; // Callback saat item dipilih
  final bool showMenuTitles; // Parameter untuk mengontrol tampilan judul menu
  final List<CustomBottomNavigationItem> items; // Daftar item navigasi kustom

  const CustomBottomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.showMenuTitles = true, // Defaultnya true (judul ditampilkan)
    required this.items, // Items wajib disediakan
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Menggunakan Card untuk memberikan efek elevasi dan sudut membulat
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Margin dari tepi layar
      decoration: BoxDecoration(
        color: AppTheme.cardColor, // Warna latar belakang
        borderRadius: BorderRadius.circular(24), // Sudut membulat
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withOpacity(0.1), // Warna bayangan dengan opasitas
            blurRadius: 10, // Radius blur bayangan
            offset: const Offset(0, 5), // Posisi bayangan
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24), // Memastikan konten juga membulat
        child: BottomNavigationBar(
          currentIndex: selectedIndex, // Indeks item yang dipilih
          onTap: onItemSelected, // Callback saat item ditekan
          backgroundColor: Colors.transparent, // Latar belakang transparan karena sudah ada Container
          elevation: 0, // Menghilangkan elevasi default BottomNavigationBar
          selectedItemColor: Theme.of(context).colorScheme.primary, // Menggunakan primary color dari theme
          unselectedItemColor: Colors.black54, // Menggunakan Colors.black54
          showSelectedLabels: showMenuTitles, // Menggunakan parameter showMenuTitles
          showUnselectedLabels: showMenuTitles, // Menggunakan parameter showMenuTitles
          type: BottomNavigationBarType.fixed, // Memastikan semua item terlihat
          items: items.asMap().entries.map((entry) { // Iterasi melalui item kustom
            int idx = entry.key;
            CustomBottomNavigationItem item = entry.value;

            Widget iconWidget;
            if (item.isProminent) {
              // Logika untuk item yang menonjol (seperti tombol Quran)
              iconWidget = Container(
                padding: const EdgeInsets.all(12), // Padding di sekitar ikon
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor, // Warna latar belakang tombol Quran
                  shape: BoxShape.circle, // Bentuk lingkaran
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4), // Bayangan untuk efek menonjol
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: item.iconData != null
                    ? Icon(
                        item.iconData, // Ikon dari IconData
                        color: Colors.white, // Warna ikon putih agar kontras
                        size: 30, // Ukuran ikon yang lebih besar
                      )
                    : item.imagePath != null
                        ? Image.asset(
                            item.imagePath!, // Ikon dari gambar PNG
                            color: Colors.white, // Warna ikon putih agar kontras
                            width: 30, // Ukuran gambar yang lebih besar
                            height: 30,
                          )
                        : const SizedBox.shrink(), // Fallback jika tidak ada ikon
              );
            } else {
              // Logika untuk item standar
              iconWidget = item.iconData != null
                  ? Icon(item.iconData) // Ikon dari IconData
                  : item.imagePath != null
                      ? Image.asset(
                          item.imagePath!, // Ikon dari gambar PNG
                          width: 24, // Ukuran standar untuk gambar
                          height: 24,
                        )
                      : const SizedBox.shrink(); // Fallback jika tidak ada ikon
            }

            return BottomNavigationBarItem(
              icon: iconWidget,
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

// Model untuk item navigasi bawah kustom
class CustomBottomNavigationItem {
  final String label; // Label teks untuk item navigasi
  final IconData? iconData; // IconData jika ikon adalah ikon bawaan Flutter
  final String? imagePath; // Path ke aset gambar jika ikon adalah gambar PNG
  final bool isProminent; // Menandakan apakah item ini harus menonjol (seperti tombol Quran)

  // Konstruktor untuk item navigasi.
  // Memerlukan setidaknya satu dari iconData atau imagePath.
  CustomBottomNavigationItem({
    required this.label,
    this.iconData,
    this.imagePath,
    this.isProminent = false, // Default tidak menonjol
  }) : assert(iconData != null || imagePath != null,
            'Either iconData or imagePath must be provided.'); // Memastikan ada ikon
}


// Widget kustom untuk App Bar
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; // Judul AppBar
  final bool showSearch; // Menampilkan ikon pencarian
  final bool showMenu; // Menampilkan ikon menu

  const CustomAppBar({
    Key? key,
    required this.title,
    this.showSearch = false,
    this.showMenu = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.backgroundColor, // Latar belakang AppBar
      elevation: 0, // Menghilangkan bayangan
      centerTitle: true, // Judul di tengah
      title: Text(
        title,
        style: TextStyle(
          color: AppTheme.textColor, // Warna teks judul
          fontWeight: FontWeight.bold, // Tebal
          fontSize: 24, // Ukuran font
        ),
      ),
      leading: showMenu
          ? IconButton(
              icon: Icon(Icons.menu_rounded, color: AppTheme.iconColor), // Ikon menu
              onPressed: () {
                // TODO: Implementasi aksi menu
              },
            )
          : null, // Tidak ada leading jika showMenu false
      actions: [
        if (showSearch)
          IconButton(
            icon: Icon(Icons.search_rounded, color: AppTheme.iconColor), // Ikon pencarian
            onPressed: () {
              // TODO: Implementasi aksi pencarian
            },
          ),
        const SizedBox(width: 16), // Jarak di kanan
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight); // Tinggi AppBar standar
}
