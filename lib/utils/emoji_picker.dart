// lib/utils/emoji_picker.dart

class EmojiPicker {
  // --- FRUIT ---
  static const Map<String, String> _fruitEmojis = {
    'apple': '🍎',
    'banana': '🍌',
    'orange': '🍊',
    'lemon': '🍋',
    'lime': '🍋', // Close enough
    'grape': '🍇',
    'melon': '🍈',
    'watermelon': '🍉',
    'tangerine': '🍊',
    'mandarin': '🍊',
    'pineapple': '🍍',
    'mango': '🥭',
    'peach': '🍑',
    'cherry': '🍒',
    'strawberry': '🍓',
    'blueberry': '🫐',
    'kiwi': '🥝',
    'tomato': '🍅', // Botanically a fruit
    'coconut': '🥥',
    'avocado': '🥑',
    'pear': '🍐',
  };

  // --- VEGETABLES ---
  static const Map<String, String> _vegEmojis = {
    'potato': '🥔',
    'carrot': '🥕',
    'corn': '🌽',
    'popcorn': '🍿',
    'pepper': '🫑',
    'chili': '🌶️',
    'cucumber': '🥒',
    'lettuce': '🥬',
    'cabbage': '🥬',
    'broccoli': '🥦',
    'mushroom': '🍄',
    'onion': '🧅',
    'garlic': '🧄',
    'eggplant': '🍆',
    'bean': '🫘',
    'pea': '🫛',
    'nut': '🥜',
    'peanut': '🥜',
    'chestnut': '🌰',
    'sweet potato': '🍠',
    'yam': '🍠',
    'leafy': '🥬',
    'salad': '🥗',
  };

  // --- MEAT ---
  static const Map<String, String> _meatEmojis = {
    'chicken': '🍗',
    'turkey': '🦃',
    'poultry': '🍗',
    'beef': '🥩',
    'steak': '🥩',
    'pork': '🐖',
    'bacon': '🥓',
    'ham': '🍖',
    'sausage': '🌭',
    'hot dog': '🌭',
    'burger': '🍔',
    'meatball': '🧆',
    'kebab': '🍢',
  };

  // --- SEAFOOD ---
  static const Map<String, String> _seafoodEmojis = {
    'fish': '🐟',
    'salmon': '🐟',
    'tuna': '🐟',
    'crab': '🦀',
    'lobster': '🦞',
    'shrimp': '🦐',
    'prawn': '🦐',
    'squid': '🦑',
    'octopus': '🐙',
    'oyster': '🦪',
    'clam': '🦪',
    'mussel': '🦪',
    'scallop': '🦪',
    'sushi': '🍣',
    'puffer': '🐡',
  };

  // --- BAKERY ---
  static const Map<String, String> _bakeryEmojis = {
    'bread': '🍞',
    'toast': '🍞',
    'croissant': '🥐',
    'baguette': '🥖',
    'french bread': '🥖',
    'pretzel': '🥨',
    'bagel': '🥯',
    'pancake': '🥞',
    'waffle': '🧇',
    'donut': '🍩',
    'cookie': '🍪',
    'cake': '🍰',
    'shortcake': '🍰',
    'pie': '🥧',
    'tart': '🥧',
    'cupcake': '🧁',
    'muffin': '🧁',
    'custard': '🍮',
  };

  // --- DAIRY ---
  static const Map<String, String> _dairyEmojis = {
    'milk': '🥛',
    'cheese': '🧀',
    'butter': '🧈',
    'cream': '🍦', // Ice cream / soft serve
    'ice cream': '🍨',
    'yogurt': '🥣', // Closest visual
    'egg': '🥚',
  };

  // --- leftovers / LEFTOVERS ---
  static const Map<String, String> _leftoversEmojis = {
    'pizza': '🍕',
    'burger': '🍔',
    'sandwich': '🥪',
    'taco': '🌮',
    'burrito': '🌯',
    'wrap': '🌯',
    'pita': '🫓',
    'rice': '🍚',
    'curry': '🍛',
    'soup': '🍲',
    'stew': '🍲',
    'noodle': '🍜',
    'ramen': '🍜',
    'pasta': '🍝',
    'spaghetti': '🍝',
    'lasagna': '🍝',
    'fries': '🍟',
    'dumpling': '🥟',
    'bento': '🍱',
    'box': '🍱',
    'casserole': '🥘',
    'paella': '🥘',
    'falafel': '🧆',
  };

  // --- DRINKS ---
  static const Map<String, String> _drinkEmojis = {
    'water': '💧',
    'coffee': '☕',
    'latte': '☕',
    'tea': '🍵',
    'matcha': '🍵',
    'juice': '🧃',
    'soda': '🥤',
    'coke': '🥤',
    'beer': '🍺',
    'wine': '🍷',
    'cocktail': '🍸',
    'liquor': '🥃',
    'champagne': '🍾',
    'sake': '🍶',
    'milkshake': '🥤',
    'boba': '🧋',
    'bubble tea': '🧋',
    'mate': '🧉',
  };

  // --- CONDIMENTS ---
  static const Map<String, String> _condimentEmojis = {
    'salt': '🧂',
    'pepper': '🧂',
    'sauce': '🥫',
    'ketchup': '🥫',
    'honey': '🍯',
    'jam': '🫙',
    'jar': '🫙',
    'oil': '🫗',
    'vinegar': '🫗',
    'sugar': '🍬',
    'spice': '🌶️',
    'mayo': '🥚', // Ingredient association
  };

  // --- OTHERS ---
  static const Map<String, String> _otherEmojis = {
    'chocolate': '🍫',
    'candy': '🍬',
    'lollipop': '🍭',
    'popcorn': '🍿',
    'chip': '🥔',
    'cracker': '🍘',
    'rice cracker': '🍘',
    'dango': '🍡',
    'ice': '🧊',
  };

  // --- CATEGORY DEFAULTS ---
  static const Map<String, String> _categoryDefaults = {
    'fruit': '🍎',
    'vegetables': '🥬',
    'meat': '🥩',
    'seafood': '🐟',
    'dairy': '🥛',
    'bakery': '🍞',
    'leftovers': '🍲',
    'drinks': '🥤',
    'condiments': '🧂',
    'others': '🍽️',
  };

  // --- LOGIC ---
  static String getEmojiForItem(String itemName, String category) {
    String lowerName = itemName.toLowerCase();

    // 1. Select the correct map
    Map<String, String> emojiMap = switch (category) {
      'fruit' => _fruitEmojis,
      'vegetables' => _vegEmojis,
      'meat' => _meatEmojis,
      'seafood' => _seafoodEmojis,
      'bakery' => _bakeryEmojis,
      'dairy' => _dairyEmojis,
      'leftovers' => _leftoversEmojis,
      'drinks' => _drinkEmojis,
      'condiments' => _condimentEmojis,
      'others' => _otherEmojis,
      _ => {}, 
    };

    // 2. Search for keyword in name
    // We sort keys by length descending to match specific terms first 
    // (e.g., match "sweet potato" before "potato")
    var sortedKeys = emojiMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var key in sortedKeys) {
      if (lowerName.contains(key)) {
        return emojiMap[key]!;
      }
    }

    // 3. Fallback to Category Default
    if (_categoryDefaults.containsKey(category)) {
      return _categoryDefaults[category]!;
    }

    // 4. Ultimate Fallback
    return _categoryDefaults['others']!;
  }
}