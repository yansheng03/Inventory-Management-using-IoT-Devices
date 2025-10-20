// lib/utils/emoji_picker.dart

class EmojiPicker {
  // --- EMOJI MAPPING ---
  // Add keywords and emojis here
  static const Map<String, String> _fruitEmojis = {
    'apple': '🍎',
    'banana': '🍌',
    'orange': '🍊',
    'strawberry': '🍓',
    'grape': '🍇',
    'lemon': '🍋',
    'peach': '🍑',
    'pear': '🍐',
  };

  static const Map<String, String> _vegEmojis = {
    'tomato': '🍅',
    'potato': '🥔',
    'broccoli': '🥦',
    'cabbage': '🥬',
    'carrot': '🥕',
    'onion': '🧅',
    'garlic': '🧄',
    'eggplant': '🍆',
  };

  static const Map<String, String> _meatEmojis = {
    'chicken': '🍗',
    'beef': '🥩',
    'pork': '🥓',
    'fish': '🐟',
    'sausage': '🌭',
  };

  // --- CATEGORY DEFAULTS ---
  // Default emoji if no keyword matches
  static const Map<String, String> _categoryDefaults = {
    'fruit': '🍓',
    'vegetables': '🥬',
    'meat': '🥩',
    'dairy': '🥛',
    'packaged': '📦',
    'drinks': '🥤',
    'condiments': '🧂',
    'others': '🍽️',
  };

  // --- PUBLIC METHOD ---
  static String getEmojiForItem(String itemName, String category) {
    String lowerName = itemName.toLowerCase();

    // 1. Get the correct map for the category
    Map<String, String> emojiMap = switch (category) {
      'fruit' => _fruitEmojis,
      'vegetables' => _vegEmojis,
      'meat' => _meatEmojis,
      _ => {}, // Default to an empty map
    };
    // Add other category maps here

    // 2. Find a matching keyword
    for (var key in emojiMap.keys) {
      if (lowerName.contains(key)) {
        return emojiMap[key]!;
      }
    }

    // 3. If no keyword match, find a category default
    if (_categoryDefaults.containsKey(category)) {
      return _categoryDefaults[category]!;
    }

    // 4. If all else fails, return 'others' default
    return _categoryDefaults['others']!;
  }
}
