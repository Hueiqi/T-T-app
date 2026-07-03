class FoodDBItem {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;
  final String category;

  const FoodDBItem({
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.servingSize = '1 serving',
    this.category = 'general',
  });
}

final List<FoodDBItem> commonFoods = [
  // Breakfast
  FoodDBItem(name: 'Oatmeal', calories: 154, protein: 5, carbs: 27, fat: 3, servingSize: '1 cup', category: 'breakfast'),
  FoodDBItem(name: 'Scrambled Eggs', calories: 182, protein: 12, carbs: 2, fat: 14, servingSize: '2 eggs', category: 'breakfast'),
  FoodDBItem(name: 'Bacon (2 slices)', calories: 86, protein: 6, carbs: 0, fat: 7, servingSize: '2 slices', category: 'breakfast'),
  FoodDBItem(name: 'Toast with Butter', calories: 150, protein: 4, carbs: 18, fat: 7, servingSize: '1 slice', category: 'breakfast'),
  FoodDBItem(name: 'Pancakes (2)', calories: 180, protein: 5, carbs: 30, fat: 5, servingSize: '2 pieces', category: 'breakfast'),
  FoodDBItem(name: 'French Toast', calories: 250, protein: 8, carbs: 30, fat: 11, servingSize: '2 slices', category: 'breakfast'),
  FoodDBItem(name: 'Cereal with Milk', calories: 200, protein: 6, carbs: 35, fat: 4, servingSize: '1 bowl', category: 'breakfast'),
  FoodDBItem(name: 'Yogurt (Greek)', calories: 100, protein: 17, carbs: 6, fat: 0, servingSize: '1 cup', category: 'breakfast'),
  FoodDBItem(name: 'Banana', calories: 105, protein: 1, carbs: 27, fat: 0, servingSize: '1 medium', category: 'breakfast'),
  FoodDBItem(name: 'Smoothie', calories: 220, protein: 8, carbs: 35, fat: 6, servingSize: '1 glass', category: 'breakfast'),
  FoodDBItem(name: 'Granola', calories: 290, protein: 7, carbs: 45, fat: 10, servingSize: '1 cup', category: 'breakfast'),
  FoodDBItem(name: 'Bagel with Cream Cheese', calories: 320, protein: 11, carbs: 48, fat: 10, servingSize: '1 bagel', category: 'breakfast'),

  // Lunch
  FoodDBItem(name: 'Chicken Salad', calories: 350, protein: 30, carbs: 10, fat: 22, servingSize: '1 bowl', category: 'lunch'),
  FoodDBItem(name: 'Turkey Sandwich', calories: 320, protein: 24, carbs: 35, fat: 10, servingSize: '1 sandwich', category: 'lunch'),
  FoodDBItem(name: 'Caesar Salad', calories: 280, protein: 18, carbs: 12, fat: 20, servingSize: '1 bowl', category: 'lunch'),
  FoodDBItem(name: 'Grilled Chicken Wrap', calories: 350, protein: 32, carbs: 28, fat: 12, servingSize: '1 wrap', category: 'lunch'),
  FoodDBItem(name: 'Tuna Salad', calories: 250, protein: 22, carbs: 8, fat: 15, servingSize: '1 bowl', category: 'lunch'),
  FoodDBItem(name: 'Vegetable Stir Fry', calories: 200, protein: 8, carbs: 25, fat: 8, servingSize: '1 plate', category: 'lunch'),
  FoodDBItem(name: 'Beef Burger', calories: 500, protein: 28, carbs: 40, fat: 25, servingSize: '1 burger', category: 'lunch'),
  FoodDBItem(name: 'Pizza Slice', calories: 285, protein: 12, carbs: 36, fat: 10, servingSize: '1 slice', category: 'lunch'),
  FoodDBItem(name: 'Club Sandwich', calories: 450, protein: 28, carbs: 38, fat: 20, servingSize: '1 sandwich', category: 'lunch'),
  FoodDBItem(name: 'Soup (Tomato)', calories: 120, protein: 3, carbs: 22, fat: 3, servingSize: '1 bowl', category: 'lunch'),

  // Dinner
  FoodDBItem(name: 'Grilled Chicken Breast', calories: 284, protein: 44, carbs: 0, fat: 11, servingSize: '1 breast', category: 'dinner'),
  FoodDBItem(name: 'Salmon Fillet', calories: 367, protein: 38, carbs: 0, fat: 22, servingSize: '1 fillet', category: 'dinner'),
  FoodDBItem(name: 'Steak (6oz)', calories: 430, protein: 38, carbs: 0, fat: 30, servingSize: '6 oz', category: 'dinner'),
  FoodDBItem(name: 'Pasta with Marinara', calories: 320, protein: 10, carbs: 55, fat: 7, servingSize: '1 plate', category: 'dinner'),
  FoodDBItem(name: 'Rice & Beans', calories: 350, protein: 12, carbs: 60, fat: 5, servingSize: '1 bowl', category: 'dinner'),
  FoodDBItem(name: 'Baked Potato with Sour Cream', calories: 230, protein: 5, carbs: 45, fat: 4, servingSize: '1 potato', category: 'dinner'),
  FoodDBItem(name: 'Roasted Vegetables', calories: 150, protein: 4, carbs: 25, fat: 5, servingSize: '1 cup', category: 'dinner'),
  FoodDBItem(name: 'Chicken Curry', calories: 380, protein: 30, carbs: 15, fat: 22, servingSize: '1 bowl', category: 'dinner'),
  FoodDBItem(name: 'Fish & Chips', calories: 550, protein: 25, carbs: 50, fat: 28, servingSize: '1 plate', category: 'dinner'),
  FoodDBItem(name: 'Spaghetti Bolognese', calories: 420, protein: 22, carbs: 50, fat: 14, servingSize: '1 plate', category: 'dinner'),

  // Snacks
  FoodDBItem(name: 'Apple', calories: 80, protein: 0, carbs: 22, fat: 0, servingSize: '1 medium', category: 'snack'),
  FoodDBItem(name: 'Orange', calories: 70, protein: 1, carbs: 16, fat: 0, servingSize: '1 medium', category: 'snack'),
  FoodDBItem(name: 'Grapes', calories: 90, protein: 1, carbs: 24, fat: 0, servingSize: '1 cup', category: 'snack'),
  FoodDBItem(name: 'Almonds (handful)', calories: 160, protein: 6, carbs: 6, fat: 14, servingSize: '1 oz', category: 'snack'),
  FoodDBItem(name: 'Mixed Nuts', calories: 170, protein: 5, carbs: 6, fat: 15, servingSize: '1 oz', category: 'snack'),
  FoodDBItem(name: 'Protein Bar', calories: 200, protein: 20, carbs: 24, fat: 5, servingSize: '1 bar', category: 'snack'),
  FoodDBItem(name: 'Hummus & Carrots', calories: 150, protein: 5, carbs: 15, fat: 8, servingSize: '1 serving', category: 'snack'),
  FoodDBItem(name: 'Trail Mix', calories: 180, protein: 5, carbs: 20, fat: 10, servingSize: '1/4 cup', category: 'snack'),
  FoodDBItem(name: 'Rice Cakes (2)', calories: 70, protein: 1, carbs: 15, fat: 1, servingSize: '2 cakes', category: 'snack'),
  FoodDBItem(name: 'Dark Chocolate (2 squares)', calories: 90, protein: 1, carbs: 8, fat: 6, servingSize: '2 squares', category: 'snack'),

  // Drinks
  FoodDBItem(name: 'Coffee (black)', calories: 5, protein: 0, carbs: 0, fat: 0, servingSize: '1 cup', category: 'drinks'),
  FoodDBItem(name: 'Latte', calories: 120, protein: 8, carbs: 12, fat: 5, servingSize: '1 cup', category: 'drinks'),
  FoodDBItem(name: 'Orange Juice', calories: 110, protein: 2, carbs: 26, fat: 0, servingSize: '1 cup', category: 'drinks'),
  FoodDBItem(name: 'Green Tea', calories: 2, protein: 0, carbs: 0, fat: 0, servingSize: '1 cup', category: 'drinks'),
  FoodDBItem(name: 'Protein Shake', calories: 180, protein: 30, carbs: 10, fat: 3, servingSize: '1 shake', category: 'drinks'),
  FoodDBItem(name: 'Soda', calories: 140, protein: 0, carbs: 39, fat: 0, servingSize: '1 can', category: 'drinks'),
  FoodDBItem(name: 'Milk (whole)', calories: 150, protein: 8, carbs: 12, fat: 8, servingSize: '1 cup', category: 'drinks'),
  FoodDBItem(name: 'Coconut Water', calories: 45, protein: 1, carbs: 9, fat: 0, servingSize: '1 cup', category: 'drinks'),
];

/// Predefined meal combos (for Meals tab)
class MealCombo {
  final String name;
  final int calories;
  final List<String> items;

  const MealCombo({
    required this.name,
    required this.calories,
    required this.items,
  });
}

final List<MealCombo> mealCombos = [
  MealCombo(name: 'Classic Breakfast', calories: 420, items: ['Scrambled Eggs', 'Toast with Butter', 'Orange Juice']),
  MealCombo(name: 'Healthy Breakfast', calories: 350, items: ['Oatmeal', 'Banana', 'Green Tea']),
  MealCombo(name: 'Protein Breakfast', calories: 380, items: ['Greek Yogurt', 'Granola', 'Protein Shake']),
  MealCombo(name: 'Light Lunch', calories: 350, items: ['Chicken Salad', 'Apple', 'Water']),
  MealCombo(name: 'Hearty Lunch', calories: 550, items: ['Beef Burger', 'Fries', 'Soda']),
  MealCombo(name: 'Healthy Dinner', calories: 450, items: ['Grilled Chicken Breast', 'Roasted Vegetables', 'Water']),
  MealCombo(name: 'Seafood Dinner', calories: 500, items: ['Salmon Fillet', 'Rice & Beans', 'Green Tea']),
  MealCombo(name: 'Quick Snack Plate', calories: 250, items: ['Apple', 'Almonds', 'Protein Bar']),
];

/// User-created recipes (for Recipes tab)
class Recipe {
  final String name;
  final int calories;
  final List<String> ingredients;

  const Recipe({
    required this.name,
    required this.calories,
    required this.ingredients,
  });
}

final List<Recipe> sampleRecipes = [
  Recipe(name: 'Protein Pancakes', calories: 350, ingredients: ['Oats', 'Protein Powder', 'Eggs', 'Banana']),
  Recipe(name: 'Chicken & Rice Bowl', calories: 500, ingredients: ['Chicken Breast', 'Brown Rice', 'Broccoli', 'Soy Sauce']),
  Recipe(name: 'Veggie Omelette', calories: 280, ingredients: ['Eggs', 'Spinach', 'Tomatoes', 'Mushrooms']),
  Recipe(name: 'Post-Workout Smoothie', calories: 300, ingredients: ['Protein Powder', 'Banana', 'Almond Milk', 'Peanut Butter']),
];
