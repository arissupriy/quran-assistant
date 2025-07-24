 String removeArabicNumbers(String text) {
    final arabicNumberRegex = RegExp(r'[٠-٩۰-۹]');
    return text.replaceAll(arabicNumberRegex, '');
  }