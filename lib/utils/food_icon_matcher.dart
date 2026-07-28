import 'package:flutter/material.dart';

class FoodCategory {
  final IconData icon;
  final Color color;
  const FoodCategory(this.icon, this.color);
}

/// Picks a representative icon/color for a food based on keywords in its
/// name. Used as a fallback wherever a meal has no photo (e.g. items added
/// from the local food library, which carries no image data).
class FoodIconMatcher {
  static const _rules = <List<String>, FoodCategory>{
    ['juice', 'smoothie', 'shake']: FoodCategory(Icons.local_bar, Color(0xFFF59E0B)),
    ['coffee', 'latte', 'espresso', 'cappuccino']: FoodCategory(Icons.coffee, Color(0xFF6F4E37)),
    ['tea']: FoodCategory(Icons.emoji_food_beverage, Color(0xFF059669)),
    ['milk', 'yogurt', 'yoghurt']: FoodCategory(Icons.icecream, Color(0xFF60A5FA)),
    ['water']: FoodCategory(Icons.water_drop, Color(0xFF3B82F6)),
    ['bread', 'toast', 'sandwich', 'bagel', 'bun']: FoodCategory(Icons.bakery_dining, Color(0xFFD97706)),
    ['rice', 'noodle', 'pasta', 'spaghetti']: FoodCategory(Icons.ramen_dining, Color(0xFFEA580C)),
    ['egg']: FoodCategory(Icons.egg, Color(0xFFFBBF24)),
    ['chicken', 'beef', 'pork', 'meat', 'steak', 'sausage', 'bacon']: FoodCategory(Icons.kebab_dining, Color(0xFFB91C1C)),
    ['fish', 'salmon', 'tuna', 'shrimp', 'seafood']: FoodCategory(Icons.set_meal, Color(0xFF0EA5E9)),
    ['salad', 'vegetable', 'veggie', 'greens']: FoodCategory(Icons.eco, Color(0xFF16A34A)),
    ['fruit', 'apple', 'banana', 'orange', 'berry', 'mango']: FoodCategory(Icons.apple, Color(0xFFDC2626)),
    ['cake', 'cookie', 'dessert', 'chocolate', 'candy', 'sweet']: FoodCategory(Icons.cake, Color(0xFFDB2777)),
    ['pizza']: FoodCategory(Icons.local_pizza, Color(0xFFEF4444)),
    ['burger']: FoodCategory(Icons.lunch_dining, Color(0xFFB45309)),
    ['soup', 'stew']: FoodCategory(Icons.soup_kitchen, Color(0xFFF97316)),
    ['nut', 'peanut', 'almond', 'cashew']: FoodCategory(Icons.grain, Color(0xFF92400E)),
  };

  static const fallback = FoodCategory(Icons.restaurant, Colors.grey);

  static FoodCategory categoryFor(String foodName) {
    final lower = foodName.toLowerCase();
    for (final entry in _rules.entries) {
      if (entry.key.any((keyword) => lower.contains(keyword))) {
        return entry.value;
      }
    }
    return fallback;
  }
}
