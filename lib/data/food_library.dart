import 'food_search.dart';

/// A food the user can log without typing macros by hand.
///
/// Values are per the stated [serving]. They are reference figures for
/// home-cooked / typical restaurant portions and will drift from any specific
/// recipe — the log sheet keeps every field editable for that reason.
///
/// [ingredients] is what the figures assume is in the dish. It is the honest
/// caveat made visible: swap the cooking oil or the cut of meat and the macros
/// move, so the user can see what they are agreeing to before logging it.
class LibraryFood {
  final String name;
  final String category;
  final String serving;
  final int kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  /// Ethanol grams. Carries 7 kcal/g and is invisible to protein/carb/fat,
  /// so without it an alcoholic drink's calories cannot be reconciled.
  final double alcoholG;

  /// Main components assumed by the figures above.
  final String ingredients;

  const LibraryFood({
    required this.name,
    required this.category,
    required this.serving,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.ingredients,
    this.alcoholG = 0.0,
  });

  /// Calories implied by the macro breakdown (4/4/9/7 kcal per gram).
  double get kcalFromMacros =>
      proteinG * 4 + carbG * 4 + fatG * 9 + alcoholG * 7;

  bool matches(String needle) {
    if (needle.isEmpty) return true;
    final n = needle.toLowerCase();
    return name.toLowerCase().contains(n) ||
        category.toLowerCase().contains(n) ||
        ingredients.toLowerCase().contains(n);
  }
}

class FoodLibrary {
  FoodLibrary._();

  /// Ordered for browsing: everyday staples first, then cuisines, then
  /// building blocks. No single cuisine leads the list.
  static const List<String> categories = [
    'Breakfast',
    'Western',
    'Italian',
    'Chinese',
    'Japanese',
    'Korean',
    'Thai & SE Asian',
    'Mexican',
    'Middle Eastern',
    'Mediterranean',
    'South Asian',
    'Bengali',
    'Fast Food',
    'Meat & Poultry',
    'Fish & Seafood',
    'Eggs & Dairy',
    'Rice & Grains',
    'Bread & Bakery',
    'Legumes & Beans',
    'Vegetables',
    'Fruit',
    'Nuts & Seeds',
    'Soups & Salads',
    'Snacks',
    'Sweets',
    'Fats & Sauces',
    'Drinks',
    'Supplements',
  ];

  static const List<LibraryFood> all = [
    // ---------------- BREAKFAST ----------------
    LibraryFood(name: 'Full English Breakfast', category: 'Breakfast', serving: '1 plate', kcal: 810, proteinG: 38.0, carbG: 52.0, fatG: 48.0, ingredients: 'Fried eggs, bacon, sausage, baked beans, toast, grilled tomato, mushrooms'),
    LibraryFood(name: 'Scrambled Eggs on Toast', category: 'Breakfast', serving: '2 eggs + 2 slices', kcal: 380, proteinG: 19.0, carbG: 32.0, fatG: 19.0, ingredients: 'Eggs, butter, milk, white toast'),
    LibraryFood(name: 'Avocado Toast', category: 'Breakfast', serving: '2 slices', kcal: 350, proteinG: 9.0, carbG: 36.0, fatG: 19.0, ingredients: 'Sourdough, avocado, olive oil, lemon, chilli flakes'),
    LibraryFood(name: 'Porridge with Banana', category: 'Breakfast', serving: '1 bowl / 300g', kcal: 350, proteinG: 13.0, carbG: 58.0, fatG: 7.0, ingredients: 'Rolled oats, milk, banana, honey'),
    LibraryFood(name: 'Greek Yogurt Bowl', category: 'Breakfast', serving: '1 bowl / 300g', kcal: 330, proteinG: 22.0, carbG: 38.0, fatG: 10.0, ingredients: 'Greek yogurt, granola, berries, honey'),
    LibraryFood(name: 'Protein Pancakes', category: 'Breakfast', serving: '3 pancakes', kcal: 420, proteinG: 32.0, carbG: 40.0, fatG: 14.0, ingredients: 'Oat flour, whey protein, eggs, milk, baking powder'),
    LibraryFood(name: 'Breakfast Burrito', category: 'Breakfast', serving: '1 wrap', kcal: 560, proteinG: 26.0, carbG: 52.0, fatG: 27.0, ingredients: 'Flour tortilla, scrambled egg, cheese, sausage, potato, salsa'),
    LibraryFood(name: 'Bacon & Egg Sandwich', category: 'Breakfast', serving: '1 roll', kcal: 450, proteinG: 22.0, carbG: 34.0, fatG: 25.0, ingredients: 'Bread roll, bacon, fried egg, butter, ketchup'),
    LibraryFood(name: 'Cereal with Milk', category: 'Breakfast', serving: '40g + 200ml', kcal: 250, proteinG: 9.0, carbG: 42.0, fatG: 5.0, ingredients: 'Wheat/corn cereal, semi-skimmed milk'),
    LibraryFood(name: 'Smoothie Bowl', category: 'Breakfast', serving: '1 bowl / 350g', kcal: 380, proteinG: 10.0, carbG: 62.0, fatG: 11.0, ingredients: 'Frozen berries, banana, yogurt, granola, seeds'),

    // ---------------- WESTERN ----------------
    LibraryFood(name: 'Roast Chicken Dinner', category: 'Western', serving: '1 plate', kcal: 680, proteinG: 45.0, carbG: 55.0, fatG: 28.0, ingredients: 'Roast chicken, potatoes, carrots, peas, gravy'),
    LibraryFood(name: 'Steak & Chips', category: 'Western', serving: '1 plate', kcal: 850, proteinG: 48.0, carbG: 58.0, fatG: 46.0, ingredients: 'Sirloin steak, chips, peppercorn sauce, salad'),
    LibraryFood(name: 'Shepherd\'s Pie', category: 'Western', serving: '1 portion / 350g', kcal: 550, proteinG: 28.0, carbG: 45.0, fatG: 28.0, ingredients: 'Lamb mince, onion, carrot, mashed potato, cheese'),
    LibraryFood(name: 'Beef Stew', category: 'Western', serving: '1 bowl / 350g', kcal: 420, proteinG: 32.0, carbG: 30.0, fatG: 19.0, ingredients: 'Beef chuck, potato, carrot, onion, stock, herbs'),
    LibraryFood(name: 'Grilled Chicken & Veg', category: 'Western', serving: '1 plate', kcal: 400, proteinG: 42.0, carbG: 22.0, fatG: 15.0, ingredients: 'Chicken breast, broccoli, courgette, olive oil'),
    LibraryFood(name: 'Salmon, Potato & Greens', category: 'Western', serving: '1 plate', kcal: 560, proteinG: 38.0, carbG: 40.0, fatG: 26.0, ingredients: 'Salmon fillet, new potatoes, green beans, butter'),
    LibraryFood(name: 'Roast Beef Sandwich', category: 'Western', serving: '1 sandwich', kcal: 430, proteinG: 28.0, carbG: 40.0, fatG: 17.0, ingredients: 'Bread, roast beef, mustard, lettuce, tomato'),
    LibraryFood(name: 'Chicken Pot Pie', category: 'Western', serving: '1 pie / 300g', kcal: 630, proteinG: 24.0, carbG: 52.0, fatG: 36.0, ingredients: 'Puff pastry, chicken, cream sauce, peas, carrot'),
    LibraryFood(name: 'Pork Chop & Apple Sauce', category: 'Western', serving: '1 plate', kcal: 520, proteinG: 40.0, carbG: 24.0, fatG: 30.0, ingredients: 'Pork loin chop, apple sauce, potato, greens'),
    LibraryFood(name: 'Mac & Cheese', category: 'Western', serving: '1 cup / 200g', kcal: 440, proteinG: 16.0, carbG: 50.0, fatG: 19.0, ingredients: 'Macaroni, cheddar, butter, milk, flour'),
    LibraryFood(name: 'Chilli Con Carne', category: 'Western', serving: '1 bowl / 300g', kcal: 450, proteinG: 30.0, carbG: 34.0, fatG: 21.0, ingredients: 'Beef mince, kidney beans, tomato, onion, chilli, cumin'),
    LibraryFood(name: 'Beef Lasagne', category: 'Western', serving: '1 portion / 350g', kcal: 620, proteinG: 32.0, carbG: 52.0, fatG: 31.0, ingredients: 'Pasta sheets, beef ragu, bechamel, mozzarella'),

    // ---------------- ITALIAN ----------------
    LibraryFood(name: 'Spaghetti Bolognese', category: 'Italian', serving: '1 plate / 350g', kcal: 550, proteinG: 26.0, carbG: 65.0, fatG: 20.0, ingredients: 'Spaghetti, beef mince, tomato, onion, garlic, olive oil'),
    LibraryFood(name: 'Spaghetti Carbonara', category: 'Italian', serving: '1 plate / 330g', kcal: 700, proteinG: 28.0, carbG: 68.0, fatG: 34.0, ingredients: 'Spaghetti, pancetta, egg yolk, pecorino, black pepper'),
    LibraryFood(name: 'Penne Arrabbiata', category: 'Italian', serving: '1 plate / 330g', kcal: 480, proteinG: 14.0, carbG: 76.0, fatG: 13.0, ingredients: 'Penne, tomato, garlic, chilli, olive oil, parsley'),
    LibraryFood(name: 'Pasta Pesto', category: 'Italian', serving: '1 plate / 330g', kcal: 620, proteinG: 18.0, carbG: 70.0, fatG: 29.0, ingredients: 'Pasta, basil pesto, pine nuts, parmesan, olive oil'),
    LibraryFood(name: 'Margherita Pizza (whole)', category: 'Italian', serving: '1 x 11in', kcal: 850, proteinG: 36.0, carbG: 106.0, fatG: 30.0, ingredients: 'Pizza dough, tomato sauce, mozzarella, basil'),
    LibraryFood(name: 'Chicken Risotto', category: 'Italian', serving: '1 plate / 350g', kcal: 580, proteinG: 28.0, carbG: 66.0, fatG: 22.0, ingredients: 'Arborio rice, chicken, stock, parmesan, butter, white wine'),
    LibraryFood(name: 'Chicken Parmigiana', category: 'Italian', serving: '1 portion', kcal: 720, proteinG: 46.0, carbG: 44.0, fatG: 39.0, ingredients: 'Breaded chicken, tomato sauce, mozzarella, parmesan'),
    LibraryFood(name: 'Minestrone Soup', category: 'Italian', serving: '1 bowl / 300g', kcal: 180, proteinG: 8.0, carbG: 28.0, fatG: 4.0, ingredients: 'Beans, pasta, tomato, carrot, celery, courgette, stock'),
    LibraryFood(name: 'Bruschetta', category: 'Italian', serving: '2 slices', kcal: 200, proteinG: 5.0, carbG: 26.0, fatG: 8.0, ingredients: 'Toasted bread, tomato, basil, garlic, olive oil'),
    LibraryFood(name: 'Tiramisu', category: 'Italian', serving: '1 slice / 100g', kcal: 300, proteinG: 5.0, carbG: 30.0, fatG: 17.0, ingredients: 'Mascarpone, savoiardi, espresso, egg, cocoa, sugar'),

    // ---------------- CHINESE ----------------
    LibraryFood(name: 'Chicken Fried Rice', category: 'Chinese', serving: '1 plate / 300g', kcal: 520, proteinG: 24.0, carbG: 66.0, fatG: 18.0, ingredients: 'Rice, chicken, egg, peas, spring onion, soy sauce, oil'),
    LibraryFood(name: 'Chicken Chow Mein', category: 'Chinese', serving: '1 plate / 300g', kcal: 480, proteinG: 24.0, carbG: 58.0, fatG: 17.0, ingredients: 'Egg noodles, chicken, cabbage, beansprouts, soy sauce'),
    LibraryFood(name: 'Sweet & Sour Chicken', category: 'Chinese', serving: '1 cup / 220g', kcal: 400, proteinG: 22.0, carbG: 42.0, fatG: 16.0, ingredients: 'Battered chicken, pineapple, pepper, sugar, vinegar, ketchup'),
    LibraryFood(name: 'Beef & Broccoli', category: 'Chinese', serving: '1 cup / 220g', kcal: 320, proteinG: 26.0, carbG: 16.0, fatG: 17.0, ingredients: 'Beef strips, broccoli, garlic, ginger, soy sauce, cornflour'),
    LibraryFood(name: 'Kung Pao Chicken', category: 'Chinese', serving: '1 cup / 220g', kcal: 430, proteinG: 27.0, carbG: 22.0, fatG: 26.0, ingredients: 'Chicken, peanuts, dried chilli, Sichuan pepper, soy, vinegar'),
    LibraryFood(name: 'Mapo Tofu', category: 'Chinese', serving: '1 cup / 220g', kcal: 320, proteinG: 18.0, carbG: 12.0, fatG: 22.0, ingredients: 'Silken tofu, pork mince, doubanjiang, Sichuan pepper, garlic'),
    LibraryFood(name: 'Spring Roll (fried)', category: 'Chinese', serving: '2 pieces', kcal: 220, proteinG: 5.0, carbG: 24.0, fatG: 12.0, ingredients: 'Pastry wrapper, cabbage, carrot, vermicelli, oil'),
    LibraryFood(name: 'Pork Dumplings (steamed)', category: 'Chinese', serving: '5 pieces', kcal: 250, proteinG: 12.0, carbG: 30.0, fatG: 9.0, ingredients: 'Wheat wrapper, pork mince, cabbage, ginger, spring onion'),
    LibraryFood(name: 'Potsticker Dumplings (fried)', category: 'Chinese', serving: '5 pieces', kcal: 330, proteinG: 12.0, carbG: 32.0, fatG: 17.0, ingredients: 'Wheat wrapper, pork, cabbage, oil'),
    LibraryFood(name: 'Char Siu Pork', category: 'Chinese', serving: '120g', kcal: 340, proteinG: 26.0, carbG: 18.0, fatG: 18.0, ingredients: 'Pork shoulder, hoisin, honey, five spice, soy'),
    LibraryFood(name: 'Peking Duck Pancakes', category: 'Chinese', serving: '3 pancakes', kcal: 380, proteinG: 20.0, carbG: 32.0, fatG: 19.0, ingredients: 'Duck, thin pancakes, hoisin, cucumber, spring onion'),
    LibraryFood(name: 'Hot & Sour Soup', category: 'Chinese', serving: '1 bowl / 250g', kcal: 110, proteinG: 6.0, carbG: 12.0, fatG: 4.0, ingredients: 'Tofu, mushroom, bamboo shoot, egg, vinegar, white pepper'),
    LibraryFood(name: 'Wonton Soup', category: 'Chinese', serving: '1 bowl', kcal: 210, proteinG: 12.0, carbG: 24.0, fatG: 7.0, ingredients: 'Pork wontons, chicken broth, spring onion'),
    LibraryFood(name: 'Salt & Pepper Chips', category: 'Chinese', serving: '1 portion', kcal: 520, proteinG: 7.0, carbG: 60.0, fatG: 28.0, ingredients: 'Potato chips, chilli, onion, pepper, five spice, oil'),

    // ---------------- JAPANESE ----------------
    LibraryFood(name: 'Salmon Sushi Roll', category: 'Japanese', serving: '6 pieces', kcal: 300, proteinG: 14.0, carbG: 42.0, fatG: 8.0, ingredients: 'Sushi rice, salmon, nori, rice vinegar'),
    LibraryFood(name: 'Salmon Nigiri', category: 'Japanese', serving: '4 pieces', kcal: 220, proteinG: 12.0, carbG: 30.0, fatG: 5.0, ingredients: 'Sushi rice, salmon'),
    LibraryFood(name: 'California Roll', category: 'Japanese', serving: '6 pieces', kcal: 260, proteinG: 8.0, carbG: 38.0, fatG: 8.0, ingredients: 'Sushi rice, crab stick, avocado, cucumber, mayo, nori'),
    LibraryFood(name: 'Chicken Katsu Curry', category: 'Japanese', serving: '1 plate / 400g', kcal: 780, proteinG: 34.0, carbG: 92.0, fatG: 30.0, ingredients: 'Breaded chicken, curry sauce, rice, carrot, onion'),
    LibraryFood(name: 'Tonkotsu Ramen', category: 'Japanese', serving: '1 bowl', kcal: 550, proteinG: 26.0, carbG: 64.0, fatG: 21.0, ingredients: 'Ramen noodles, pork broth, chashu pork, egg, spring onion'),
    LibraryFood(name: 'Chicken Teriyaki', category: 'Japanese', serving: '150g', kcal: 300, proteinG: 28.0, carbG: 18.0, fatG: 13.0, ingredients: 'Chicken thigh, soy sauce, mirin, sake, sugar'),
    LibraryFood(name: 'Chicken Yakitori', category: 'Japanese', serving: '3 skewers', kcal: 250, proteinG: 24.0, carbG: 12.0, fatG: 12.0, ingredients: 'Chicken thigh, tare glaze, spring onion'),
    LibraryFood(name: 'Miso Soup', category: 'Japanese', serving: '1 bowl', kcal: 60, proteinG: 4.0, carbG: 6.0, fatG: 2.0, ingredients: 'Miso paste, dashi, tofu, wakame, spring onion'),
    LibraryFood(name: 'Edamame (salted)', category: 'Japanese', serving: '1 cup / 155g', kcal: 190, proteinG: 18.0, carbG: 14.0, fatG: 8.0, ingredients: 'Soybean pods, sea salt'),
    LibraryFood(name: 'Gyoza (pan fried)', category: 'Japanese', serving: '5 pieces', kcal: 290, proteinG: 11.0, carbG: 30.0, fatG: 14.0, ingredients: 'Wrapper, pork, cabbage, garlic, sesame oil'),
    LibraryFood(name: 'Tempura Prawns', category: 'Japanese', serving: '5 pieces', kcal: 320, proteinG: 16.0, carbG: 28.0, fatG: 16.0, ingredients: 'Prawns, tempura batter, frying oil'),
    LibraryFood(name: 'Poke Bowl (tuna)', category: 'Japanese', serving: '1 bowl / 400g', kcal: 520, proteinG: 32.0, carbG: 62.0, fatG: 15.0, ingredients: 'Sushi rice, raw tuna, avocado, edamame, soy, sesame'),

    // ---------------- KOREAN ----------------
    LibraryFood(name: 'Bibimbap', category: 'Korean', serving: '1 bowl / 400g', kcal: 600, proteinG: 25.0, carbG: 80.0, fatG: 20.0, ingredients: 'Rice, beef, spinach, carrot, courgette, egg, gochujang, sesame'),
    LibraryFood(name: 'Bulgogi Beef', category: 'Korean', serving: '150g', kcal: 350, proteinG: 28.0, carbG: 14.0, fatG: 20.0, ingredients: 'Beef sirloin, soy, pear, garlic, sesame oil, sugar'),
    LibraryFood(name: 'Korean Fried Chicken', category: 'Korean', serving: '5 pieces', kcal: 620, proteinG: 32.0, carbG: 42.0, fatG: 34.0, ingredients: 'Chicken, potato starch, gochujang, honey, garlic'),
    LibraryFood(name: 'Tteokbokki', category: 'Korean', serving: '1 bowl / 250g', kcal: 420, proteinG: 9.0, carbG: 78.0, fatG: 8.0, ingredients: 'Rice cakes, gochujang, fish cake, sugar, spring onion'),
    LibraryFood(name: 'Kimchi', category: 'Korean', serving: '1/2 cup / 75g', kcal: 22, proteinG: 1.5, carbG: 4.0, fatG: 0.3, ingredients: 'Napa cabbage, gochugaru, garlic, ginger, fish sauce'),
    LibraryFood(name: 'Kimchi Jjigae', category: 'Korean', serving: '1 bowl / 350g', kcal: 320, proteinG: 20.0, carbG: 18.0, fatG: 19.0, ingredients: 'Kimchi, pork belly, tofu, gochugaru, stock'),
    LibraryFood(name: 'Japchae', category: 'Korean', serving: '1 plate / 250g', kcal: 420, proteinG: 12.0, carbG: 62.0, fatG: 14.0, ingredients: 'Sweet potato noodles, beef, spinach, carrot, sesame oil, soy'),

    // ---------------- THAI & SE ASIAN ----------------
    LibraryFood(name: 'Pad Thai', category: 'Thai & SE Asian', serving: '1 plate / 300g', kcal: 620, proteinG: 22.0, carbG: 76.0, fatG: 25.0, ingredients: 'Rice noodles, egg, tofu, prawns, tamarind, peanuts, beansprouts'),
    LibraryFood(name: 'Thai Green Curry (chicken)', category: 'Thai & SE Asian', serving: '1 cup / 220g', kcal: 380, proteinG: 22.0, carbG: 14.0, fatG: 26.0, ingredients: 'Chicken, coconut milk, green curry paste, aubergine, basil'),
    LibraryFood(name: 'Thai Red Curry (beef)', category: 'Thai & SE Asian', serving: '1 cup / 220g', kcal: 420, proteinG: 24.0, carbG: 14.0, fatG: 30.0, ingredients: 'Beef, coconut milk, red curry paste, bamboo shoot, basil'),
    LibraryFood(name: 'Massaman Curry', category: 'Thai & SE Asian', serving: '1 cup / 220g', kcal: 450, proteinG: 22.0, carbG: 24.0, fatG: 30.0, ingredients: 'Beef, coconut milk, potato, peanuts, massaman paste'),
    LibraryFood(name: 'Tom Yum Soup', category: 'Thai & SE Asian', serving: '1 bowl / 300g', kcal: 130, proteinG: 14.0, carbG: 10.0, fatG: 4.0, ingredients: 'Prawns, lemongrass, galangal, lime, chilli, fish sauce'),
    LibraryFood(name: 'Thai Fried Rice', category: 'Thai & SE Asian', serving: '1 plate / 300g', kcal: 540, proteinG: 22.0, carbG: 70.0, fatG: 19.0, ingredients: 'Jasmine rice, chicken, egg, fish sauce, tomato, spring onion'),
    LibraryFood(name: 'Som Tam (Papaya Salad)', category: 'Thai & SE Asian', serving: '1 bowl / 200g', kcal: 130, proteinG: 4.0, carbG: 22.0, fatG: 4.0, ingredients: 'Green papaya, lime, fish sauce, chilli, peanuts, tomato'),
    LibraryFood(name: 'Nasi Goreng', category: 'Thai & SE Asian', serving: '1 plate / 300g', kcal: 560, proteinG: 22.0, carbG: 72.0, fatG: 20.0, ingredients: 'Rice, chicken, kecap manis, shallot, chilli, fried egg'),
    LibraryFood(name: 'Chicken Satay', category: 'Thai & SE Asian', serving: '4 skewers', kcal: 380, proteinG: 30.0, carbG: 14.0, fatG: 23.0, ingredients: 'Chicken, turmeric, coconut milk, peanut sauce'),
    LibraryFood(name: 'Pho (beef)', category: 'Thai & SE Asian', serving: '1 bowl / 500g', kcal: 420, proteinG: 28.0, carbG: 56.0, fatG: 9.0, ingredients: 'Rice noodles, beef, star anise broth, herbs, beansprouts'),
    LibraryFood(name: 'Banh Mi', category: 'Thai & SE Asian', serving: '1 sandwich', kcal: 480, proteinG: 24.0, carbG: 56.0, fatG: 18.0, ingredients: 'Baguette, pork, pate, pickled carrot, coriander, mayo'),
    LibraryFood(name: 'Vietnamese Summer Roll', category: 'Thai & SE Asian', serving: '2 rolls', kcal: 180, proteinG: 10.0, carbG: 26.0, fatG: 4.0, ingredients: 'Rice paper, prawns, vermicelli, lettuce, mint'),

    // ---------------- MEXICAN ----------------
    LibraryFood(name: 'Chicken Burrito', category: 'Mexican', serving: '1 burrito', kcal: 680, proteinG: 32.0, carbG: 78.0, fatG: 26.0, ingredients: 'Tortilla, chicken, rice, black beans, cheese, salsa, sour cream'),
    LibraryFood(name: 'Beef Taco', category: 'Mexican', serving: '1 taco', kcal: 210, proteinG: 9.0, carbG: 18.0, fatG: 11.0, ingredients: 'Corn tortilla, beef mince, cheese, lettuce, salsa'),
    LibraryFood(name: 'Chicken Quesadilla', category: 'Mexican', serving: '1 whole', kcal: 550, proteinG: 30.0, carbG: 44.0, fatG: 27.0, ingredients: 'Flour tortilla, chicken, cheese, peppers, onion'),
    LibraryFood(name: 'Nachos with Cheese', category: 'Mexican', serving: '1 portion / 200g', kcal: 620, proteinG: 18.0, carbG: 56.0, fatG: 36.0, ingredients: 'Tortilla chips, cheese, jalapeno, salsa, sour cream'),
    LibraryFood(name: 'Guacamole', category: 'Mexican', serving: '1/4 cup / 60g', kcal: 110, proteinG: 1.5, carbG: 6.0, fatG: 10.0, ingredients: 'Avocado, lime, onion, coriander, salt'),
    LibraryFood(name: 'Chicken Enchiladas', category: 'Mexican', serving: '2 pieces', kcal: 580, proteinG: 30.0, carbG: 50.0, fatG: 28.0, ingredients: 'Corn tortilla, chicken, enchilada sauce, cheese'),
    LibraryFood(name: 'Burrito Bowl', category: 'Mexican', serving: '1 bowl / 450g', kcal: 620, proteinG: 36.0, carbG: 68.0, fatG: 22.0, ingredients: 'Rice, black beans, chicken, corn, salsa, guacamole'),
    LibraryFood(name: 'Refried Beans', category: 'Mexican', serving: '1/2 cup / 120g', kcal: 130, proteinG: 7.0, carbG: 20.0, fatG: 2.5, ingredients: 'Pinto beans, onion, garlic, oil'),

    // ---------------- MIDDLE EASTERN ----------------
    LibraryFood(name: 'Chicken Shawarma Wrap', category: 'Middle Eastern', serving: '1 wrap', kcal: 520, proteinG: 30.0, carbG: 48.0, fatG: 23.0, ingredients: 'Flatbread, marinated chicken, garlic sauce, pickles, salad'),
    LibraryFood(name: 'Chicken Shawarma Plate', category: 'Middle Eastern', serving: '1 plate', kcal: 650, proteinG: 40.0, carbG: 55.0, fatG: 30.0, ingredients: 'Chicken, rice, salad, hummus, garlic sauce'),
    LibraryFood(name: 'Falafel', category: 'Middle Eastern', serving: '4 pieces', kcal: 260, proteinG: 9.0, carbG: 24.0, fatG: 14.0, ingredients: 'Chickpeas, herbs, garlic, cumin, fried'),
    LibraryFood(name: 'Falafel Wrap', category: 'Middle Eastern', serving: '1 wrap', kcal: 520, proteinG: 16.0, carbG: 62.0, fatG: 23.0, ingredients: 'Pita, falafel, hummus, tahini, salad, pickles'),
    LibraryFood(name: 'Chicken Shish Kebab', category: 'Middle Eastern', serving: '2 skewers', kcal: 300, proteinG: 34.0, carbG: 4.0, fatG: 16.0, ingredients: 'Chicken, yogurt marinade, lemon, garlic, peppers'),
    LibraryFood(name: 'Lamb Kofta', category: 'Middle Eastern', serving: '2 skewers', kcal: 380, proteinG: 26.0, carbG: 6.0, fatG: 28.0, ingredients: 'Lamb mince, onion, parsley, cumin, coriander'),
    LibraryFood(name: 'Doner Kebab', category: 'Middle Eastern', serving: '1 regular', kcal: 720, proteinG: 38.0, carbG: 60.0, fatG: 36.0, ingredients: 'Pita, doner meat, salad, chilli sauce, garlic sauce'),
    LibraryFood(name: 'Hummus', category: 'Middle Eastern', serving: '2 tbsp / 30g', kcal: 70, proteinG: 2.0, carbG: 6.0, fatG: 5.0, ingredients: 'Chickpeas, tahini, lemon, garlic, olive oil'),
    LibraryFood(name: 'Baba Ganoush', category: 'Middle Eastern', serving: '2 tbsp / 30g', kcal: 60, proteinG: 1.0, carbG: 4.0, fatG: 5.0, ingredients: 'Smoked aubergine, tahini, lemon, garlic'),
    LibraryFood(name: 'Tabbouleh', category: 'Middle Eastern', serving: '1 cup / 160g', kcal: 130, proteinG: 3.0, carbG: 16.0, fatG: 7.0, ingredients: 'Bulgur, parsley, mint, tomato, lemon, olive oil'),
    LibraryFood(name: 'Mixed Grill Platter', category: 'Middle Eastern', serving: '1 plate', kcal: 850, proteinG: 60.0, carbG: 30.0, fatG: 54.0, ingredients: 'Lamb chops, chicken shish, kofta, rice, salad'),
    LibraryFood(name: 'Baklava', category: 'Middle Eastern', serving: '1 piece', kcal: 230, proteinG: 3.0, carbG: 27.0, fatG: 13.0, ingredients: 'Filo pastry, pistachio, butter, sugar syrup'),

    // ---------------- MEDITERRANEAN ----------------
    LibraryFood(name: 'Greek Salad', category: 'Mediterranean', serving: '1 bowl', kcal: 230, proteinG: 7.0, carbG: 12.0, fatG: 17.0, ingredients: 'Tomato, cucumber, olives, feta, red onion, olive oil'),
    LibraryFood(name: 'Chicken Gyros', category: 'Mediterranean', serving: '1 wrap', kcal: 560, proteinG: 32.0, carbG: 50.0, fatG: 25.0, ingredients: 'Pita, chicken, tzatziki, tomato, onion, chips'),
    LibraryFood(name: 'Moussaka', category: 'Mediterranean', serving: '1 portion / 300g', kcal: 520, proteinG: 24.0, carbG: 28.0, fatG: 34.0, ingredients: 'Aubergine, lamb mince, tomato, bechamel, cheese'),
    LibraryFood(name: 'Tzatziki', category: 'Mediterranean', serving: '2 tbsp / 30g', kcal: 35, proteinG: 1.5, carbG: 2.0, fatG: 2.5, ingredients: 'Greek yogurt, cucumber, garlic, dill, olive oil'),
    LibraryFood(name: 'Grilled Halloumi', category: 'Mediterranean', serving: '60g', kcal: 190, proteinG: 13.0, carbG: 2.0, fatG: 15.0, ingredients: 'Halloumi cheese, olive oil'),
    LibraryFood(name: 'Paella (seafood)', category: 'Mediterranean', serving: '1 plate / 350g', kcal: 560, proteinG: 30.0, carbG: 68.0, fatG: 18.0, ingredients: 'Bomba rice, prawns, mussels, saffron, pepper, stock'),
    LibraryFood(name: 'Stuffed Vine Leaves', category: 'Mediterranean', serving: '5 pieces', kcal: 180, proteinG: 4.0, carbG: 26.0, fatG: 7.0, ingredients: 'Vine leaves, rice, herbs, lemon, olive oil'),

    // ---------------- SOUTH ASIAN ----------------
    LibraryFood(name: 'Butter Chicken', category: 'South Asian', serving: '1 cup / 220g', kcal: 440, proteinG: 28.0, carbG: 12.0, fatG: 31.0, ingredients: 'Chicken, tomato, cream, butter, garam masala, fenugreek'),
    LibraryFood(name: 'Chicken Tikka Masala', category: 'South Asian', serving: '1 cup / 220g', kcal: 400, proteinG: 29.0, carbG: 13.0, fatG: 26.0, ingredients: 'Grilled chicken, tomato, cream, onion, garam masala'),
    LibraryFood(name: 'Chicken Tikka (dry)', category: 'South Asian', serving: '4 pieces / 150g', kcal: 250, proteinG: 32.0, carbG: 4.0, fatG: 12.0, ingredients: 'Chicken, yogurt, ginger-garlic, chilli, lemon'),
    LibraryFood(name: 'Tandoori Chicken', category: 'South Asian', serving: '1/4 chicken', kcal: 280, proteinG: 34.0, carbG: 4.0, fatG: 14.0, ingredients: 'Chicken, yogurt, tandoori masala, lemon'),
    LibraryFood(name: 'Chicken Korma', category: 'South Asian', serving: '1 cup / 220g', kcal: 420, proteinG: 26.0, carbG: 12.0, fatG: 30.0, ingredients: 'Chicken, cashew paste, cream, onion, mild spices'),
    LibraryFood(name: 'Chicken Vindaloo', category: 'South Asian', serving: '1 cup / 220g', kcal: 350, proteinG: 28.0, carbG: 12.0, fatG: 21.0, ingredients: 'Chicken, vinegar, Kashmiri chilli, garlic, potato'),
    LibraryFood(name: 'Lamb Rogan Josh', category: 'South Asian', serving: '1 cup / 220g', kcal: 430, proteinG: 28.0, carbG: 9.0, fatG: 32.0, ingredients: 'Lamb, yogurt, Kashmiri chilli, fennel, ginger'),
    LibraryFood(name: 'Palak Paneer', category: 'South Asian', serving: '1 cup / 200g', kcal: 300, proteinG: 14.0, carbG: 12.0, fatG: 22.0, ingredients: 'Spinach, paneer, cream, garlic, cumin'),
    LibraryFood(name: 'Paneer Butter Masala', category: 'South Asian', serving: '1 cup / 200g', kcal: 380, proteinG: 15.0, carbG: 16.0, fatG: 29.0, ingredients: 'Paneer, tomato, butter, cream, cashew'),
    LibraryFood(name: 'Chana Masala', category: 'South Asian', serving: '1 cup / 200g', kcal: 270, proteinG: 12.0, carbG: 38.0, fatG: 8.0, ingredients: 'Chickpeas, tomato, onion, amchur, garam masala'),
    LibraryFood(name: 'Rajma (Kidney Bean Curry)', category: 'South Asian', serving: '1 cup / 200g', kcal: 250, proteinG: 13.0, carbG: 36.0, fatG: 6.0, ingredients: 'Kidney beans, tomato, onion, ginger, garam masala'),
    LibraryFood(name: 'Dal Makhani', category: 'South Asian', serving: '1 cup / 200g', kcal: 320, proteinG: 12.0, carbG: 30.0, fatG: 17.0, ingredients: 'Black lentils, kidney beans, butter, cream, tomato'),
    LibraryFood(name: 'Dal Tadka', category: 'South Asian', serving: '1 cup / 200g', kcal: 200, proteinG: 11.0, carbG: 25.0, fatG: 6.0, ingredients: 'Toor dal, cumin, garlic, ghee, tomato, turmeric'),
    LibraryFood(name: 'Aloo Gobi', category: 'South Asian', serving: '1 cup / 200g', kcal: 180, proteinG: 5.0, carbG: 24.0, fatG: 8.0, ingredients: 'Potato, cauliflower, turmeric, cumin, oil'),
    LibraryFood(name: 'Bhindi Masala (Okra)', category: 'South Asian', serving: '1 cup / 180g', kcal: 170, proteinG: 4.0, carbG: 18.0, fatG: 9.0, ingredients: 'Okra, onion, tomato, amchur, oil'),
    LibraryFood(name: 'Baingan Bharta', category: 'South Asian', serving: '1 cup / 200g', kcal: 160, proteinG: 4.0, carbG: 16.0, fatG: 9.0, ingredients: 'Roasted aubergine, onion, tomato, ginger, oil'),
    LibraryFood(name: 'Chicken Biryani (Hyderabadi)', category: 'South Asian', serving: '1 plate / 350g', kcal: 650, proteinG: 30.0, carbG: 76.0, fatG: 25.0, ingredients: 'Basmati rice, chicken, yogurt, saffron, fried onion, ghee'),
    LibraryFood(name: 'Vegetable Pulao', category: 'South Asian', serving: '1 cup / 200g', kcal: 300, proteinG: 7.0, carbG: 48.0, fatG: 9.0, ingredients: 'Basmati rice, mixed veg, whole spices, ghee'),
    LibraryFood(name: 'Masala Dosa', category: 'South Asian', serving: '1 dosa', kcal: 390, proteinG: 8.0, carbG: 55.0, fatG: 15.0, ingredients: 'Rice-lentil batter, potato masala, oil'),
    LibraryFood(name: 'Plain Dosa', category: 'South Asian', serving: '1 dosa', kcal: 170, proteinG: 4.0, carbG: 28.0, fatG: 5.0, ingredients: 'Fermented rice and urad dal batter, oil'),
    LibraryFood(name: 'Idli', category: 'South Asian', serving: '2 pieces', kcal: 116, proteinG: 4.0, carbG: 24.0, fatG: 0.4, ingredients: 'Steamed rice and urad dal batter'),
    LibraryFood(name: 'Sambar', category: 'South Asian', serving: '1 cup / 200g', kcal: 140, proteinG: 7.0, carbG: 20.0, fatG: 4.0, ingredients: 'Toor dal, tamarind, drumstick, sambar powder'),
    LibraryFood(name: 'Upma', category: 'South Asian', serving: '1 cup / 200g', kcal: 250, proteinG: 6.0, carbG: 38.0, fatG: 8.0, ingredients: 'Semolina, mustard seed, curry leaf, onion, oil'),
    LibraryFood(name: 'Poha', category: 'South Asian', serving: '1 cup / 180g', kcal: 250, proteinG: 5.0, carbG: 42.0, fatG: 7.0, ingredients: 'Flattened rice, onion, peanuts, turmeric, curry leaf'),
    LibraryFood(name: 'Pav Bhaji', category: 'South Asian', serving: '1 plate', kcal: 450, proteinG: 10.0, carbG: 58.0, fatG: 19.0, ingredients: 'Mixed veg mash, pav buns, butter, pav bhaji masala'),
    LibraryFood(name: 'Samosa (Punjabi)', category: 'South Asian', serving: '1 piece', kcal: 260, proteinG: 5.0, carbG: 30.0, fatG: 13.0, ingredients: 'Pastry, potato, peas, cumin, fried'),
    LibraryFood(name: 'Pakora (Mixed)', category: 'South Asian', serving: '5 pieces', kcal: 240, proteinG: 6.0, carbG: 24.0, fatG: 13.0, ingredients: 'Gram flour, onion, potato, spinach, fried'),
    LibraryFood(name: 'Chicken Seekh Kebab', category: 'South Asian', serving: '2 skewers', kcal: 280, proteinG: 26.0, carbG: 5.0, fatG: 17.0, ingredients: 'Chicken mince, onion, coriander, green chilli'),
    LibraryFood(name: 'Beef Seekh Kebab', category: 'South Asian', serving: '2 skewers', kcal: 330, proteinG: 25.0, carbG: 5.0, fatG: 23.0, ingredients: 'Beef mince, onion, garam masala, coriander'),
    LibraryFood(name: 'Nihari', category: 'South Asian', serving: '1 bowl / 300g', kcal: 480, proteinG: 30.0, carbG: 14.0, fatG: 34.0, ingredients: 'Beef shank, bone marrow, wheat flour, nihari masala, ghee'),
    LibraryFood(name: 'Raita', category: 'South Asian', serving: '1/2 cup / 120g', kcal: 70, proteinG: 4.0, carbG: 7.0, fatG: 3.0, ingredients: 'Yogurt, cucumber, cumin, mint'),

    // ---------------- BENGALI ----------------
    LibraryFood(name: 'Chicken Curry (Bengali)', category: 'Bengali', serving: '1 cup / 200g', kcal: 290, proteinG: 26.0, carbG: 8.0, fatG: 17.0, ingredients: 'Chicken, onion, ginger-garlic, turmeric, cumin, mustard oil'),
    LibraryFood(name: 'Chicken Roast (Bengali)', category: 'Bengali', serving: '1 leg piece', kcal: 340, proteinG: 27.0, carbG: 10.0, fatG: 21.0, ingredients: 'Chicken leg, yogurt, fried onion, cashew, ghee, garam masala'),
    LibraryFood(name: 'Chicken Rezala', category: 'Bengali', serving: '1 cup / 200g', kcal: 360, proteinG: 25.0, carbG: 9.0, fatG: 25.0, ingredients: 'Chicken, yogurt, cashew paste, ghee, white pepper, kewra'),
    LibraryFood(name: 'Beef Curry (Bengali)', category: 'Bengali', serving: '1 cup / 200g', kcal: 380, proteinG: 27.0, carbG: 7.0, fatG: 27.0, ingredients: 'Beef, onion, ginger-garlic, chilli, turmeric, mustard oil'),
    LibraryFood(name: 'Beef Bhuna', category: 'Bengali', serving: '1 cup / 200g', kcal: 400, proteinG: 28.0, carbG: 8.0, fatG: 28.0, ingredients: 'Beef, slow-fried onion, garam masala, mustard oil'),
    LibraryFood(name: 'Beef Kala Bhuna', category: 'Bengali', serving: '1 cup / 200g', kcal: 430, proteinG: 29.0, carbG: 8.0, fatG: 31.0, ingredients: 'Beef, dark-fried onion, whole spices, mustard oil, ginger'),
    LibraryFood(name: 'Mutton Curry', category: 'Bengali', serving: '1 cup / 200g', kcal: 400, proteinG: 28.0, carbG: 7.0, fatG: 29.0, ingredients: 'Mutton, onion, yogurt, ginger-garlic, garam masala'),
    LibraryFood(name: 'Mutton Rezala', category: 'Bengali', serving: '1 cup / 200g', kcal: 420, proteinG: 26.0, carbG: 9.0, fatG: 31.0, ingredients: 'Mutton, yogurt, cashew, ghee, green chilli, kewra water'),
    LibraryFood(name: 'Ilish Bhapa (Steamed Hilsa)', category: 'Bengali', serving: '1 piece / 100g', kcal: 280, proteinG: 21.0, carbG: 2.0, fatG: 21.0, ingredients: 'Hilsa, mustard paste, green chilli, mustard oil, turmeric'),
    LibraryFood(name: 'Shorshe Ilish', category: 'Bengali', serving: '1 piece / 100g', kcal: 320, proteinG: 20.0, carbG: 4.0, fatG: 25.0, ingredients: 'Hilsa, yellow-black mustard paste, mustard oil, green chilli'),
    LibraryFood(name: 'Ilish Bhaja (Fried Hilsa)', category: 'Bengali', serving: '1 piece / 100g', kcal: 300, proteinG: 20.0, carbG: 1.0, fatG: 24.0, ingredients: 'Hilsa, turmeric, salt, mustard oil'),
    LibraryFood(name: 'Rui Macher Jhol (Rohu Curry)', category: 'Bengali', serving: '1 piece + gravy', kcal: 210, proteinG: 22.0, carbG: 5.0, fatG: 11.0, ingredients: 'Rohu, potato, cumin, turmeric, mustard oil, coriander'),
    LibraryFood(name: 'Katla Macher Kalia', category: 'Bengali', serving: '1 piece + gravy', kcal: 250, proteinG: 22.0, carbG: 6.0, fatG: 15.0, ingredients: 'Katla, onion paste, yogurt, garam masala, ghee'),
    LibraryFood(name: 'Pabda Macher Jhol', category: 'Bengali', serving: '1 piece + gravy', kcal: 190, proteinG: 19.0, carbG: 4.0, fatG: 11.0, ingredients: 'Pabda fish, nigella seed, green chilli, mustard oil'),
    LibraryFood(name: 'Shutki Bhuna (Dried Fish)', category: 'Bengali', serving: '1/2 cup / 100g', kcal: 230, proteinG: 25.0, carbG: 6.0, fatG: 12.0, ingredients: 'Dried fish, onion, garlic, dried chilli, mustard oil'),
    LibraryFood(name: 'Chingri Malai Curry', category: 'Bengali', serving: '1 cup / 200g', kcal: 340, proteinG: 22.0, carbG: 9.0, fatG: 24.0, ingredients: 'Prawns, coconut milk, onion paste, ghee, garam masala'),
    LibraryFood(name: 'Chingri Bhuna (Prawn)', category: 'Bengali', serving: '1 cup / 180g', kcal: 260, proteinG: 24.0, carbG: 7.0, fatG: 15.0, ingredients: 'Prawns, onion, tomato, turmeric, mustard oil'),
    LibraryFood(name: 'Dim Bhuna (Egg Curry)', category: 'Bengali', serving: '2 eggs + gravy', kcal: 270, proteinG: 15.0, carbG: 7.0, fatG: 20.0, ingredients: 'Boiled eggs, onion, tomato, cumin, mustard oil'),
    LibraryFood(name: 'Dim Bhaji (Bengali Omelette)', category: 'Bengali', serving: '2 eggs', kcal: 220, proteinG: 13.0, carbG: 3.0, fatG: 17.0, ingredients: 'Eggs, onion, green chilli, coriander, mustard oil'),
    LibraryFood(name: 'Dal (Masoor)', category: 'Bengali', serving: '1 cup / 200g', kcal: 150, proteinG: 9.0, carbG: 20.0, fatG: 4.0, ingredients: 'Red lentils, turmeric, nigella seed, garlic, mustard oil'),
    LibraryFood(name: 'Dal (Mug / Moong)', category: 'Bengali', serving: '1 cup / 200g', kcal: 160, proteinG: 10.0, carbG: 21.0, fatG: 4.0, ingredients: 'Roasted moong dal, bay leaf, cumin, ghee'),
    LibraryFood(name: 'Chholar Dal', category: 'Bengali', serving: '1 cup / 200g', kcal: 220, proteinG: 11.0, carbG: 30.0, fatG: 7.0, ingredients: 'Bengal gram, coconut, raisin, ghee, whole spices'),
    LibraryFood(name: 'Khichuri', category: 'Bengali', serving: '1 cup / 250g', kcal: 320, proteinG: 11.0, carbG: 48.0, fatG: 9.0, ingredients: 'Rice, moong dal, turmeric, ginger, ghee, vegetables'),
    LibraryFood(name: 'Bhuna Khichuri', category: 'Bengali', serving: '1 plate / 300g', kcal: 430, proteinG: 14.0, carbG: 58.0, fatG: 16.0, ingredients: 'Rice, moong dal, whole spices, fried onion, ghee'),
    LibraryFood(name: 'Biryani (Chicken)', category: 'Bengali', serving: '1 plate / 350g', kcal: 620, proteinG: 28.0, carbG: 75.0, fatG: 23.0, ingredients: 'Basmati rice, chicken, potato, yogurt, ghee, kewra'),
    LibraryFood(name: 'Biryani (Mutton)', category: 'Bengali', serving: '1 plate / 350g', kcal: 700, proteinG: 30.0, carbG: 74.0, fatG: 31.0, ingredients: 'Basmati rice, mutton, potato, yogurt, ghee, saffron'),
    LibraryFood(name: 'Kacchi Biryani', category: 'Bengali', serving: '1 plate / 400g', kcal: 780, proteinG: 32.0, carbG: 82.0, fatG: 35.0, ingredients: 'Raw-marinated mutton, basmati rice, potato, ghee, mawa, saffron'),
    LibraryFood(name: 'Tehari (Beef)', category: 'Bengali', serving: '1 plate / 350g', kcal: 680, proteinG: 26.0, carbG: 78.0, fatG: 29.0, ingredients: 'Chinigura rice, beef, mustard oil, green chilli, turmeric'),
    LibraryFood(name: 'Morog Polao', category: 'Bengali', serving: '1 plate / 350g', kcal: 640, proteinG: 27.0, carbG: 76.0, fatG: 25.0, ingredients: 'Chinigura rice, chicken, ghee, milk, cashew, raisin'),
    LibraryFood(name: 'Plain Polao', category: 'Bengali', serving: '1 cup / 200g', kcal: 380, proteinG: 7.0, carbG: 58.0, fatG: 13.0, ingredients: 'Chinigura rice, ghee, bay leaf, cardamom, sugar'),
    LibraryFood(name: 'Panta Bhat', category: 'Bengali', serving: '1 cup / 200g', kcal: 180, proteinG: 4.0, carbG: 39.0, fatG: 0.5, ingredients: 'Fermented leftover rice, water, salt, green chilli'),
    LibraryFood(name: 'Aloo Bhorta', category: 'Bengali', serving: '1/2 cup / 100g', kcal: 140, proteinG: 2.0, carbG: 18.0, fatG: 7.0, ingredients: 'Boiled potato, mustard oil, onion, green chilli, coriander'),
    LibraryFood(name: 'Begun Bhorta', category: 'Bengali', serving: '1/2 cup / 100g', kcal: 110, proteinG: 2.0, carbG: 10.0, fatG: 7.0, ingredients: 'Roasted aubergine, mustard oil, onion, chilli, garlic'),
    LibraryFood(name: 'Shutki Bhorta', category: 'Bengali', serving: '1/4 cup / 60g', kcal: 150, proteinG: 14.0, carbG: 4.0, fatG: 9.0, ingredients: 'Dried fish, dried chilli, garlic, mustard oil, onion'),
    LibraryFood(name: 'Dal Bhorta', category: 'Bengali', serving: '1/2 cup / 100g', kcal: 130, proteinG: 7.0, carbG: 14.0, fatG: 5.0, ingredients: 'Mashed lentils, mustard oil, onion, green chilli'),
    LibraryFood(name: 'Begun Bhaja', category: 'Bengali', serving: '2 slices', kcal: 120, proteinG: 1.5, carbG: 9.0, fatG: 9.0, ingredients: 'Aubergine slices, turmeric, salt, mustard oil'),
    LibraryFood(name: 'Aloo Bhaja', category: 'Bengali', serving: '1/2 cup', kcal: 160, proteinG: 2.0, carbG: 20.0, fatG: 8.0, ingredients: 'Julienned potato, turmeric, salt, oil'),
    LibraryFood(name: 'Shukto', category: 'Bengali', serving: '1 cup / 200g', kcal: 130, proteinG: 4.0, carbG: 15.0, fatG: 6.0, ingredients: 'Bitter gourd, drumstick, milk, radhuni, ghee, mustard paste'),
    LibraryFood(name: 'Labra (Mixed Veg)', category: 'Bengali', serving: '1 cup / 200g', kcal: 150, proteinG: 4.0, carbG: 20.0, fatG: 6.0, ingredients: 'Mixed seasonal veg, panch phoron, ginger, mustard oil'),
    LibraryFood(name: 'Aloo Posto', category: 'Bengali', serving: '1/2 cup / 120g', kcal: 190, proteinG: 4.0, carbG: 20.0, fatG: 11.0, ingredients: 'Potato, poppy seed paste, green chilli, mustard oil'),
    LibraryFood(name: 'Luchi', category: 'Bengali', serving: '2 pieces', kcal: 220, proteinG: 4.0, carbG: 26.0, fatG: 11.0, ingredients: 'Refined flour, ghee, deep-fried'),
    LibraryFood(name: 'Singara', category: 'Bengali', serving: '1 piece', kcal: 180, proteinG: 4.0, carbG: 22.0, fatG: 9.0, ingredients: 'Flour pastry, potato, peanuts, cauliflower, fried'),
    LibraryFood(name: 'Beguni', category: 'Bengali', serving: '2 pieces', kcal: 150, proteinG: 3.0, carbG: 15.0, fatG: 9.0, ingredients: 'Aubergine, gram flour batter, turmeric, fried'),
    LibraryFood(name: 'Piyaju', category: 'Bengali', serving: '3 pieces', kcal: 170, proteinG: 6.0, carbG: 18.0, fatG: 8.0, ingredients: 'Split lentil paste, onion, green chilli, fried'),
    LibraryFood(name: 'Fuchka', category: 'Bengali', serving: '6 pieces', kcal: 230, proteinG: 5.0, carbG: 36.0, fatG: 8.0, ingredients: 'Crisp shells, spiced potato, chickpeas, tamarind water'),
    LibraryFood(name: 'Chotpoti', category: 'Bengali', serving: '1 bowl / 250g', kcal: 300, proteinG: 12.0, carbG: 40.0, fatG: 10.0, ingredients: 'Chickpeas, potato, egg, tamarind, onion, chilli'),
    LibraryFood(name: 'Haleem (Bengali)', category: 'Bengali', serving: '1 bowl / 300g', kcal: 380, proteinG: 22.0, carbG: 38.0, fatG: 15.0, ingredients: 'Beef, wheat, lentils, ghee, ginger, fried onion'),
    LibraryFood(name: 'Roshogolla', category: 'Bengali', serving: '1 piece', kcal: 150, proteinG: 4.0, carbG: 27.0, fatG: 3.0, ingredients: 'Chhena, sugar syrup, semolina'),
    LibraryFood(name: 'Mishti Doi', category: 'Bengali', serving: '1 cup / 150g', kcal: 200, proteinG: 6.0, carbG: 34.0, fatG: 5.0, ingredients: 'Milk, caramelised sugar, yogurt culture'),
    LibraryFood(name: 'Chomchom', category: 'Bengali', serving: '1 piece', kcal: 170, proteinG: 4.0, carbG: 30.0, fatG: 4.0, ingredients: 'Chhena, sugar syrup, mawa, cardamom'),
    LibraryFood(name: 'Sandesh', category: 'Bengali', serving: '1 piece', kcal: 130, proteinG: 4.0, carbG: 18.0, fatG: 5.0, ingredients: 'Chhena, sugar, cardamom'),
    LibraryFood(name: 'Payesh (Rice Pudding)', category: 'Bengali', serving: '1 cup / 200g', kcal: 280, proteinG: 7.0, carbG: 45.0, fatG: 8.0, ingredients: 'Gobindobhog rice, milk, sugar, cardamom, bay leaf'),

    // ---------------- FAST FOOD ----------------
    LibraryFood(name: 'Cheeseburger', category: 'Fast Food', serving: '1 burger', kcal: 500, proteinG: 25.0, carbG: 42.0, fatG: 26.0, ingredients: 'Bun, beef patty, cheese, pickle, onion, ketchup, mustard'),
    LibraryFood(name: 'Double Beef Burger', category: 'Fast Food', serving: '1 burger', kcal: 780, proteinG: 42.0, carbG: 45.0, fatG: 47.0, ingredients: 'Bun, two beef patties, cheese, sauce, lettuce'),
    LibraryFood(name: 'Crispy Chicken Burger', category: 'Fast Food', serving: '1 burger', kcal: 450, proteinG: 24.0, carbG: 44.0, fatG: 20.0, ingredients: 'Bun, breaded chicken, mayo, lettuce'),
    LibraryFood(name: 'Grilled Chicken Wrap', category: 'Fast Food', serving: '1 wrap', kcal: 380, proteinG: 26.0, carbG: 38.0, fatG: 13.0, ingredients: 'Tortilla, grilled chicken, lettuce, tomato, light mayo'),
    LibraryFood(name: 'Pizza Slice (cheese)', category: 'Fast Food', serving: '1 slice', kcal: 285, proteinG: 12.0, carbG: 36.0, fatG: 10.0, ingredients: 'Dough, tomato sauce, mozzarella'),
    LibraryFood(name: 'Pizza Slice (pepperoni)', category: 'Fast Food', serving: '1 slice', kcal: 320, proteinG: 14.0, carbG: 35.0, fatG: 14.0, ingredients: 'Dough, tomato sauce, mozzarella, pepperoni'),
    LibraryFood(name: 'French Fries (medium)', category: 'Fast Food', serving: '1 medium', kcal: 340, proteinG: 4.0, carbG: 44.0, fatG: 16.0, ingredients: 'Potato, vegetable oil, salt'),
    LibraryFood(name: 'Onion Rings', category: 'Fast Food', serving: '1 portion', kcal: 410, proteinG: 5.0, carbG: 48.0, fatG: 22.0, ingredients: 'Onion, batter, frying oil'),
    LibraryFood(name: 'Fried Chicken (2 pieces)', category: 'Fast Food', serving: '2 pieces', kcal: 540, proteinG: 34.0, carbG: 20.0, fatG: 36.0, ingredients: 'Chicken, seasoned flour, frying oil'),
    LibraryFood(name: 'Chicken Nuggets', category: 'Fast Food', serving: '6 pieces', kcal: 280, proteinG: 14.0, carbG: 18.0, fatG: 17.0, ingredients: 'Chicken, batter, frying oil'),
    LibraryFood(name: 'Hot Dog', category: 'Fast Food', serving: '1 with bun', kcal: 320, proteinG: 12.0, carbG: 26.0, fatG: 19.0, ingredients: 'Bun, frankfurter, ketchup, mustard, onion'),
    LibraryFood(name: 'Sub Sandwich (6in, turkey)', category: 'Fast Food', serving: '6 inch', kcal: 320, proteinG: 20.0, carbG: 46.0, fatG: 6.0, ingredients: 'Wheat roll, turkey, lettuce, tomato, onion, light dressing'),
    LibraryFood(name: 'Club Sandwich', category: 'Fast Food', serving: '1 sandwich', kcal: 590, proteinG: 30.0, carbG: 48.0, fatG: 31.0, ingredients: 'Toast, chicken, bacon, egg, lettuce, tomato, mayo'),
    LibraryFood(name: 'Chicken Caesar Salad', category: 'Fast Food', serving: '1 bowl', kcal: 430, proteinG: 32.0, carbG: 12.0, fatG: 28.0, ingredients: 'Romaine, grilled chicken, parmesan, croutons, caesar dressing'),

    // ---------------- MEAT & POULTRY ----------------
    LibraryFood(name: 'Chicken Breast (grilled)', category: 'Meat & Poultry', serving: '100g', kcal: 165, proteinG: 31.0, carbG: 0.0, fatG: 3.6, ingredients: 'Skinless chicken breast, salt, pepper'),
    LibraryFood(name: 'Chicken Breast (fried)', category: 'Meat & Poultry', serving: '100g', kcal: 250, proteinG: 27.0, carbG: 8.0, fatG: 12.0, ingredients: 'Chicken breast, flour coating, frying oil'),
    LibraryFood(name: 'Chicken Thigh (cooked)', category: 'Meat & Poultry', serving: '100g', kcal: 209, proteinG: 26.0, carbG: 0.0, fatG: 11.0, ingredients: 'Boneless chicken thigh, oil'),
    LibraryFood(name: 'Chicken Drumstick (roast)', category: 'Meat & Poultry', serving: '1 piece', kcal: 130, proteinG: 15.0, carbG: 0.0, fatG: 7.0, ingredients: 'Chicken drumstick, skin, seasoning'),
    LibraryFood(name: 'Chicken Wings (fried)', category: 'Meat & Poultry', serving: '4 wings', kcal: 400, proteinG: 30.0, carbG: 8.0, fatG: 28.0, ingredients: 'Chicken wings, flour, frying oil'),
    LibraryFood(name: 'Turkey Breast (cooked)', category: 'Meat & Poultry', serving: '100g', kcal: 135, proteinG: 30.0, carbG: 0.0, fatG: 1.0, ingredients: 'Skinless turkey breast'),
    LibraryFood(name: 'Beef Mince (lean, cooked)', category: 'Meat & Poultry', serving: '100g', kcal: 250, proteinG: 26.0, carbG: 0.0, fatG: 15.0, ingredients: '5% fat beef mince'),
    LibraryFood(name: 'Beef Sirloin Steak', category: 'Meat & Poultry', serving: '150g', kcal: 350, proteinG: 46.0, carbG: 0.0, fatG: 18.0, ingredients: 'Sirloin, salt, pepper, oil'),
    LibraryFood(name: 'Beef Ribeye Steak', category: 'Meat & Poultry', serving: '150g', kcal: 440, proteinG: 42.0, carbG: 0.0, fatG: 30.0, ingredients: 'Ribeye, salt, pepper, butter'),
    LibraryFood(name: 'Lamb Chop (grilled)', category: 'Meat & Poultry', serving: '100g', kcal: 290, proteinG: 25.0, carbG: 0.0, fatG: 21.0, ingredients: 'Lamb loin chop, rosemary, oil'),
    LibraryFood(name: 'Goat Meat (cooked)', category: 'Meat & Poultry', serving: '100g', kcal: 143, proteinG: 27.0, carbG: 0.0, fatG: 3.0, ingredients: 'Lean goat meat'),
    LibraryFood(name: 'Liver (cooked)', category: 'Meat & Poultry', serving: '100g', kcal: 175, proteinG: 26.0, carbG: 5.0, fatG: 5.0, ingredients: 'Beef or chicken liver, onion, oil'),
    LibraryFood(name: 'Beef Sausage', category: 'Meat & Poultry', serving: '2 links', kcal: 280, proteinG: 14.0, carbG: 3.0, fatG: 23.0, ingredients: 'Beef, rusk, seasoning, casing'),
    LibraryFood(name: 'Chicken Sausage', category: 'Meat & Poultry', serving: '2 links', kcal: 180, proteinG: 16.0, carbG: 3.0, fatG: 11.0, ingredients: 'Chicken, seasoning, casing'),
    LibraryFood(name: 'Bacon (fried)', category: 'Meat & Poultry', serving: '2 rashers', kcal: 180, proteinG: 12.0, carbG: 0.5, fatG: 14.0, ingredients: 'Cured pork belly'),
    LibraryFood(name: 'Ham (sliced)', category: 'Meat & Poultry', serving: '50g', kcal: 70, proteinG: 10.0, carbG: 1.0, fatG: 3.0, ingredients: 'Cured pork leg'),
    LibraryFood(name: 'Beef Meatballs', category: 'Meat & Poultry', serving: '4 pieces', kcal: 300, proteinG: 20.0, carbG: 8.0, fatG: 21.0, ingredients: 'Beef mince, breadcrumb, egg, onion, herbs'),

    // ---------------- FISH & SEAFOOD ----------------
    LibraryFood(name: 'Salmon (cooked)', category: 'Fish & Seafood', serving: '100g', kcal: 208, proteinG: 20.0, carbG: 0.0, fatG: 13.0, ingredients: 'Atlantic salmon fillet'),
    LibraryFood(name: 'Grilled Salmon Fillet', category: 'Fish & Seafood', serving: '150g', kcal: 310, proteinG: 31.0, carbG: 0.0, fatG: 20.0, ingredients: 'Salmon, lemon, olive oil, salt'),
    LibraryFood(name: 'Tilapia (cooked)', category: 'Fish & Seafood', serving: '100g', kcal: 128, proteinG: 26.0, carbG: 0.0, fatG: 2.7, ingredients: 'Tilapia fillet'),
    LibraryFood(name: 'Cod (cooked)', category: 'Fish & Seafood', serving: '100g', kcal: 105, proteinG: 23.0, carbG: 0.0, fatG: 1.0, ingredients: 'Cod fillet'),
    LibraryFood(name: 'Tuna (canned in water)', category: 'Fish & Seafood', serving: '1 can / 100g', kcal: 116, proteinG: 26.0, carbG: 0.0, fatG: 1.0, ingredients: 'Skipjack tuna, water, salt'),
    LibraryFood(name: 'Tuna (canned in oil)', category: 'Fish & Seafood', serving: '1 can / 100g', kcal: 190, proteinG: 25.0, carbG: 0.0, fatG: 10.0, ingredients: 'Tuna, sunflower oil, salt'),
    LibraryFood(name: 'Sardines (canned)', category: 'Fish & Seafood', serving: '1 can / 90g', kcal: 190, proteinG: 22.0, carbG: 0.0, fatG: 11.0, ingredients: 'Sardines, oil, salt'),
    LibraryFood(name: 'Mackerel (cooked)', category: 'Fish & Seafood', serving: '100g', kcal: 205, proteinG: 19.0, carbG: 0.0, fatG: 14.0, ingredients: 'Mackerel fillet'),
    LibraryFood(name: 'Prawns (cooked)', category: 'Fish & Seafood', serving: '100g', kcal: 99, proteinG: 24.0, carbG: 0.2, fatG: 0.3, ingredients: 'King prawns, salt'),
    LibraryFood(name: 'Squid (grilled)', category: 'Fish & Seafood', serving: '100g', kcal: 110, proteinG: 18.0, carbG: 3.0, fatG: 2.0, ingredients: 'Squid, olive oil, lemon'),
    LibraryFood(name: 'Crab Meat', category: 'Fish & Seafood', serving: '100g', kcal: 97, proteinG: 19.0, carbG: 0.0, fatG: 1.5, ingredients: 'White crab meat'),
    LibraryFood(name: 'Fish & Chips', category: 'Fish & Seafood', serving: '1 portion', kcal: 800, proteinG: 32.0, carbG: 80.0, fatG: 38.0, ingredients: 'Battered cod, chips, frying oil'),
    LibraryFood(name: 'Fried Fish Fillet', category: 'Fish & Seafood', serving: '1 fillet / 120g', kcal: 280, proteinG: 20.0, carbG: 14.0, fatG: 16.0, ingredients: 'White fish, breadcrumb, frying oil'),

    // ---------------- EGGS & DAIRY ----------------
    LibraryFood(name: 'Whole Egg (boiled)', category: 'Eggs & Dairy', serving: '1 large', kcal: 78, proteinG: 6.3, carbG: 0.6, fatG: 5.3, ingredients: 'Hen egg'),
    LibraryFood(name: 'Fried Egg', category: 'Eggs & Dairy', serving: '1 large', kcal: 110, proteinG: 6.3, carbG: 0.6, fatG: 9.0, ingredients: 'Hen egg, cooking oil'),
    LibraryFood(name: 'Scrambled Eggs', category: 'Eggs & Dairy', serving: '2 eggs', kcal: 200, proteinG: 13.0, carbG: 2.0, fatG: 15.0, ingredients: 'Eggs, butter, milk'),
    LibraryFood(name: 'Plain Omelette', category: 'Eggs & Dairy', serving: '2 eggs', kcal: 190, proteinG: 13.0, carbG: 1.0, fatG: 15.0, ingredients: 'Eggs, butter, salt'),
    LibraryFood(name: 'Egg White', category: 'Eggs & Dairy', serving: '1 large', kcal: 17, proteinG: 3.6, carbG: 0.2, fatG: 0.1, ingredients: 'Hen egg white'),
    LibraryFood(name: 'Duck Egg (boiled)', category: 'Eggs & Dairy', serving: '1 egg', kcal: 130, proteinG: 9.0, carbG: 1.0, fatG: 9.5, ingredients: 'Duck egg'),
    LibraryFood(name: 'Full Fat Milk', category: 'Eggs & Dairy', serving: '250ml', kcal: 150, proteinG: 8.0, carbG: 12.0, fatG: 8.0, ingredients: 'Whole cow milk'),
    LibraryFood(name: 'Semi-Skimmed Milk', category: 'Eggs & Dairy', serving: '250ml', kcal: 115, proteinG: 8.0, carbG: 12.0, fatG: 4.0, ingredients: '2% cow milk'),
    LibraryFood(name: 'Skim Milk', category: 'Eggs & Dairy', serving: '250ml', kcal: 83, proteinG: 8.0, carbG: 12.0, fatG: 0.2, ingredients: 'Fat-free cow milk'),
    LibraryFood(name: 'Almond Milk (unsweetened)', category: 'Eggs & Dairy', serving: '250ml', kcal: 40, proteinG: 1.5, carbG: 2.0, fatG: 3.0, ingredients: 'Almonds, water, calcium'),
    LibraryFood(name: 'Soy Milk', category: 'Eggs & Dairy', serving: '250ml', kcal: 105, proteinG: 7.0, carbG: 9.0, fatG: 4.0, ingredients: 'Soybeans, water, calcium'),
    LibraryFood(name: 'Greek Yogurt (plain)', category: 'Eggs & Dairy', serving: '170g', kcal: 100, proteinG: 17.0, carbG: 6.0, fatG: 0.7, ingredients: 'Strained fat-free yogurt, live cultures'),
    LibraryFood(name: 'Greek Yogurt (full fat)', category: 'Eggs & Dairy', serving: '170g', kcal: 160, proteinG: 15.0, carbG: 7.0, fatG: 8.0, ingredients: 'Strained whole-milk yogurt, live cultures'),
    LibraryFood(name: 'Plain Yogurt (Doi)', category: 'Eggs & Dairy', serving: '1 cup / 200g', kcal: 120, proteinG: 8.0, carbG: 12.0, fatG: 4.0, ingredients: 'Whole milk, yogurt culture'),
    LibraryFood(name: 'Paneer', category: 'Eggs & Dairy', serving: '100g', kcal: 265, proteinG: 18.0, carbG: 6.0, fatG: 20.0, ingredients: 'Whole milk, lemon juice or vinegar'),
    LibraryFood(name: 'Cottage Cheese', category: 'Eggs & Dairy', serving: '100g', kcal: 98, proteinG: 11.0, carbG: 3.4, fatG: 4.3, ingredients: 'Curd, cream, salt'),
    LibraryFood(name: 'Cheddar Cheese', category: 'Eggs & Dairy', serving: '30g', kcal: 120, proteinG: 7.0, carbG: 0.4, fatG: 10.0, ingredients: 'Cow milk, rennet, salt'),
    LibraryFood(name: 'Mozzarella', category: 'Eggs & Dairy', serving: '30g', kcal: 85, proteinG: 6.0, carbG: 1.0, fatG: 6.0, ingredients: 'Cow milk, rennet, salt'),
    LibraryFood(name: 'Cream Cheese', category: 'Eggs & Dairy', serving: '2 tbsp / 30g', kcal: 100, proteinG: 2.0, carbG: 1.5, fatG: 10.0, ingredients: 'Cream, milk, stabiliser'),
    LibraryFood(name: 'Butter', category: 'Eggs & Dairy', serving: '1 tbsp / 14g', kcal: 100, proteinG: 0.1, carbG: 0.0, fatG: 11.0, ingredients: 'Churned cream, salt'),
    LibraryFood(name: 'Ghee', category: 'Eggs & Dairy', serving: '1 tbsp / 14g', kcal: 123, proteinG: 0.0, carbG: 0.0, fatG: 14.0, ingredients: 'Clarified butter'),

    // ---------------- RICE & GRAINS ----------------
    LibraryFood(name: 'White Rice (cooked)', category: 'Rice & Grains', serving: '1 cup / 158g', kcal: 205, proteinG: 4.3, carbG: 45.0, fatG: 0.4, ingredients: 'Long grain white rice, water'),
    LibraryFood(name: 'Brown Rice (cooked)', category: 'Rice & Grains', serving: '1 cup / 195g', kcal: 216, proteinG: 5.0, carbG: 45.0, fatG: 1.8, ingredients: 'Wholegrain brown rice, water'),
    LibraryFood(name: 'Basmati Rice (cooked)', category: 'Rice & Grains', serving: '1 cup / 160g', kcal: 210, proteinG: 4.4, carbG: 46.0, fatG: 0.5, ingredients: 'Basmati rice, water'),
    LibraryFood(name: 'Jasmine Rice (cooked)', category: 'Rice & Grains', serving: '1 cup / 158g', kcal: 205, proteinG: 4.2, carbG: 45.0, fatG: 0.4, ingredients: 'Thai jasmine rice, water'),
    LibraryFood(name: 'Egg Fried Rice', category: 'Rice & Grains', serving: '1 cup / 200g', kcal: 340, proteinG: 10.0, carbG: 48.0, fatG: 12.0, ingredients: 'Cooked rice, egg, spring onion, soy sauce, oil'),
    LibraryFood(name: 'Oats (dry)', category: 'Rice & Grains', serving: '50g', kcal: 190, proteinG: 6.5, carbG: 33.0, fatG: 3.5, ingredients: 'Rolled oats'),
    LibraryFood(name: 'Quinoa (cooked)', category: 'Rice & Grains', serving: '1 cup / 185g', kcal: 222, proteinG: 8.0, carbG: 39.0, fatG: 3.6, ingredients: 'Quinoa, water'),
    LibraryFood(name: 'Couscous (cooked)', category: 'Rice & Grains', serving: '1 cup / 157g', kcal: 176, proteinG: 6.0, carbG: 36.0, fatG: 0.3, ingredients: 'Semolina couscous, water'),
    LibraryFood(name: 'Bulgur (cooked)', category: 'Rice & Grains', serving: '1 cup / 182g', kcal: 151, proteinG: 5.6, carbG: 34.0, fatG: 0.4, ingredients: 'Cracked wheat, water'),
    LibraryFood(name: 'Pasta (cooked)', category: 'Rice & Grains', serving: '1 cup / 140g', kcal: 220, proteinG: 8.0, carbG: 43.0, fatG: 1.3, ingredients: 'Durum wheat semolina, water'),
    LibraryFood(name: 'Wholewheat Pasta (cooked)', category: 'Rice & Grains', serving: '1 cup / 140g', kcal: 174, proteinG: 7.5, carbG: 37.0, fatG: 0.8, ingredients: 'Wholewheat durum semolina, water'),
    LibraryFood(name: 'Instant Noodles', category: 'Rice & Grains', serving: '1 pack / 85g dry', kcal: 385, proteinG: 8.0, carbG: 54.0, fatG: 15.0, ingredients: 'Fried wheat noodles, palm oil, seasoning sachet'),
    LibraryFood(name: 'Rice Cakes', category: 'Rice & Grains', serving: '2 cakes', kcal: 70, proteinG: 1.5, carbG: 15.0, fatG: 0.5, ingredients: 'Puffed brown rice, salt'),
    LibraryFood(name: 'Muesli', category: 'Rice & Grains', serving: '50g', kcal: 190, proteinG: 5.5, carbG: 32.0, fatG: 4.5, ingredients: 'Oats, dried fruit, nuts, seeds'),
    LibraryFood(name: 'Granola', category: 'Rice & Grains', serving: '50g', kcal: 220, proteinG: 5.0, carbG: 32.0, fatG: 8.0, ingredients: 'Oats, honey, oil, nuts, dried fruit'),
    LibraryFood(name: 'Chira (Flattened Rice)', category: 'Rice & Grains', serving: '50g dry', kcal: 175, proteinG: 3.5, carbG: 38.0, fatG: 0.6, ingredients: 'Flattened parboiled rice'),
    LibraryFood(name: 'Muri (Puffed Rice)', category: 'Rice & Grains', serving: '1 cup / 25g', kcal: 95, proteinG: 2.0, carbG: 21.0, fatG: 0.3, ingredients: 'Puffed rice'),
    LibraryFood(name: 'Semolina (Suji, cooked)', category: 'Rice & Grains', serving: '1 cup / 200g', kcal: 220, proteinG: 7.0, carbG: 42.0, fatG: 2.5, ingredients: 'Semolina, water, ghee'),

    // ---------------- BREAD & BAKERY ----------------
    LibraryFood(name: 'Roti / Chapati', category: 'Bread & Bakery', serving: '1 piece', kcal: 120, proteinG: 3.0, carbG: 20.0, fatG: 3.0, ingredients: 'Wholewheat flour, water, salt, oil'),
    LibraryFood(name: 'Tandoori Roti', category: 'Bread & Bakery', serving: '1 piece', kcal: 140, proteinG: 4.0, carbG: 26.0, fatG: 2.0, ingredients: 'Wholewheat flour, water, salt'),
    LibraryFood(name: 'Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 260, proteinG: 5.0, carbG: 31.0, fatG: 13.0, ingredients: 'Wheat flour, ghee or oil, water, salt'),
    LibraryFood(name: 'Aloo Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 300, proteinG: 6.0, carbG: 40.0, fatG: 13.0, ingredients: 'Wheat flour, spiced potato, ghee'),
    LibraryFood(name: 'Naan', category: 'Bread & Bakery', serving: '1 piece', kcal: 280, proteinG: 8.0, carbG: 48.0, fatG: 6.0, ingredients: 'Refined flour, yogurt, yeast, ghee'),
    LibraryFood(name: 'Garlic Naan', category: 'Bread & Bakery', serving: '1 piece', kcal: 320, proteinG: 8.0, carbG: 50.0, fatG: 9.0, ingredients: 'Refined flour, yogurt, garlic, butter, coriander'),
    LibraryFood(name: 'Puri', category: 'Bread & Bakery', serving: '2 pieces', kcal: 210, proteinG: 4.0, carbG: 24.0, fatG: 11.0, ingredients: 'Wheat flour, water, deep-fried in oil'),
    LibraryFood(name: 'White Bread', category: 'Bread & Bakery', serving: '2 slices', kcal: 160, proteinG: 5.0, carbG: 30.0, fatG: 2.0, ingredients: 'Refined wheat flour, yeast, salt'),
    LibraryFood(name: 'Brown Bread', category: 'Bread & Bakery', serving: '2 slices', kcal: 150, proteinG: 7.0, carbG: 26.0, fatG: 2.5, ingredients: 'Wholemeal flour, yeast, salt'),
    LibraryFood(name: 'Sourdough Bread', category: 'Bread & Bakery', serving: '2 slices', kcal: 180, proteinG: 7.0, carbG: 34.0, fatG: 1.5, ingredients: 'Flour, water, sourdough starter, salt'),
    LibraryFood(name: 'Bagel', category: 'Bread & Bakery', serving: '1 medium', kcal: 250, proteinG: 10.0, carbG: 48.0, fatG: 1.5, ingredients: 'Refined flour, yeast, malt, salt'),
    LibraryFood(name: 'Croissant', category: 'Bread & Bakery', serving: '1 medium', kcal: 270, proteinG: 5.5, carbG: 31.0, fatG: 14.0, ingredients: 'Laminated dough, butter, yeast'),
    LibraryFood(name: 'English Muffin', category: 'Bread & Bakery', serving: '1 piece', kcal: 130, proteinG: 5.0, carbG: 25.0, fatG: 1.0, ingredients: 'Wheat flour, yeast, cornmeal'),
    LibraryFood(name: 'Pita Bread', category: 'Bread & Bakery', serving: '1 piece', kcal: 165, proteinG: 5.5, carbG: 33.0, fatG: 0.7, ingredients: 'Wheat flour, yeast, water, salt'),
    LibraryFood(name: 'Flour Tortilla', category: 'Bread & Bakery', serving: '1 large', kcal: 200, proteinG: 5.0, carbG: 34.0, fatG: 5.0, ingredients: 'Wheat flour, fat, baking powder'),
    LibraryFood(name: 'Burger Bun', category: 'Bread & Bakery', serving: '1 bun', kcal: 150, proteinG: 5.0, carbG: 28.0, fatG: 2.0, ingredients: 'Refined flour, yeast, sugar, sesame'),
    LibraryFood(name: 'Banana Bread', category: 'Bread & Bakery', serving: '1 slice / 60g', kcal: 200, proteinG: 3.0, carbG: 33.0, fatG: 7.0, ingredients: 'Flour, banana, sugar, egg, butter'),
    LibraryFood(name: 'Pancakes', category: 'Bread & Bakery', serving: '2 medium', kcal: 250, proteinG: 7.0, carbG: 36.0, fatG: 8.0, ingredients: 'Flour, egg, milk, butter, baking powder'),
    LibraryFood(name: 'Waffle', category: 'Bread & Bakery', serving: '1 piece', kcal: 220, proteinG: 6.0, carbG: 28.0, fatG: 9.0, ingredients: 'Flour, egg, milk, butter, sugar'),
    LibraryFood(name: 'Rusk / Toast Biscuit', category: 'Bread & Bakery', serving: '2 pieces', kcal: 110, proteinG: 2.5, carbG: 20.0, fatG: 2.0, ingredients: 'Twice-baked wheat bread, sugar'),

    // ---------------- LEGUMES & BEANS ----------------
    LibraryFood(name: 'Lentils (cooked)', category: 'Legumes & Beans', serving: '1 cup / 198g', kcal: 230, proteinG: 18.0, carbG: 40.0, fatG: 0.8, ingredients: 'Brown lentils, water'),
    LibraryFood(name: 'Chickpeas (cooked)', category: 'Legumes & Beans', serving: '1 cup / 164g', kcal: 269, proteinG: 15.0, carbG: 45.0, fatG: 4.2, ingredients: 'Chickpeas, water'),
    LibraryFood(name: 'Black Beans (cooked)', category: 'Legumes & Beans', serving: '1 cup / 172g', kcal: 227, proteinG: 15.0, carbG: 41.0, fatG: 0.9, ingredients: 'Black beans, water'),
    LibraryFood(name: 'Kidney Beans (cooked)', category: 'Legumes & Beans', serving: '1 cup / 177g', kcal: 225, proteinG: 15.0, carbG: 40.0, fatG: 0.9, ingredients: 'Red kidney beans, water'),
    LibraryFood(name: 'Baked Beans (canned)', category: 'Legumes & Beans', serving: '1/2 can / 200g', kcal: 160, proteinG: 9.0, carbG: 28.0, fatG: 1.0, ingredients: 'Haricot beans, tomato sauce, sugar'),
    LibraryFood(name: 'Green Peas (cooked)', category: 'Legumes & Beans', serving: '1 cup / 160g', kcal: 134, proteinG: 9.0, carbG: 25.0, fatG: 0.4, ingredients: 'Garden peas, water'),
    LibraryFood(name: 'Soybeans (cooked)', category: 'Legumes & Beans', serving: '1 cup / 172g', kcal: 296, proteinG: 31.0, carbG: 17.0, fatG: 15.0, ingredients: 'Soybeans, water'),
    LibraryFood(name: 'Tofu (firm)', category: 'Legumes & Beans', serving: '100g', kcal: 144, proteinG: 17.0, carbG: 3.0, fatG: 9.0, ingredients: 'Soybeans, water, calcium sulphate'),
    LibraryFood(name: 'Tempeh', category: 'Legumes & Beans', serving: '100g', kcal: 195, proteinG: 20.0, carbG: 8.0, fatG: 11.0, ingredients: 'Fermented whole soybeans'),

    // ---------------- VEGETABLES ----------------
    LibraryFood(name: 'Mixed Vegetables (cooked)', category: 'Vegetables', serving: '1 cup / 150g', kcal: 80, proteinG: 4.0, carbG: 15.0, fatG: 0.5, ingredients: 'Carrot, peas, sweetcorn, green beans'),
    LibraryFood(name: 'Spinach (cooked)', category: 'Vegetables', serving: '1 cup / 180g', kcal: 41, proteinG: 5.3, carbG: 6.8, fatG: 0.5, ingredients: 'Spinach leaves, water'),
    LibraryFood(name: 'Broccoli (steamed)', category: 'Vegetables', serving: '1 cup / 156g', kcal: 55, proteinG: 3.7, carbG: 11.0, fatG: 0.6, ingredients: 'Broccoli florets'),
    LibraryFood(name: 'Cauliflower (cooked)', category: 'Vegetables', serving: '1 cup / 125g', kcal: 29, proteinG: 2.3, carbG: 5.0, fatG: 0.3, ingredients: 'Cauliflower florets'),
    LibraryFood(name: 'Carrot (raw)', category: 'Vegetables', serving: '1 medium', kcal: 25, proteinG: 0.6, carbG: 6.0, fatG: 0.1, ingredients: 'Carrot'),
    LibraryFood(name: 'Cucumber', category: 'Vegetables', serving: '1 cup sliced', kcal: 16, proteinG: 0.7, carbG: 3.8, fatG: 0.1, ingredients: 'Cucumber'),
    LibraryFood(name: 'Tomato', category: 'Vegetables', serving: '1 medium', kcal: 22, proteinG: 1.1, carbG: 4.8, fatG: 0.2, ingredients: 'Tomato'),
    LibraryFood(name: 'Onion (raw)', category: 'Vegetables', serving: '1 medium', kcal: 44, proteinG: 1.2, carbG: 10.0, fatG: 0.1, ingredients: 'Onion'),
    LibraryFood(name: 'Bell Pepper', category: 'Vegetables', serving: '1 medium', kcal: 31, proteinG: 1.0, carbG: 7.0, fatG: 0.3, ingredients: 'Sweet pepper'),
    LibraryFood(name: 'Potato (boiled)', category: 'Vegetables', serving: '150g', kcal: 130, proteinG: 3.0, carbG: 30.0, fatG: 0.2, ingredients: 'Potato, water, salt'),
    LibraryFood(name: 'Mashed Potato', category: 'Vegetables', serving: '1 cup / 210g', kcal: 240, proteinG: 4.0, carbG: 35.0, fatG: 9.0, ingredients: 'Potato, butter, milk, salt'),
    LibraryFood(name: 'Sweet Potato (baked)', category: 'Vegetables', serving: '150g', kcal: 135, proteinG: 2.4, carbG: 31.0, fatG: 0.2, ingredients: 'Sweet potato'),
    LibraryFood(name: 'Pumpkin (cooked)', category: 'Vegetables', serving: '1 cup / 245g', kcal: 49, proteinG: 1.8, carbG: 12.0, fatG: 0.2, ingredients: 'Pumpkin, water'),
    LibraryFood(name: 'Okra (cooked)', category: 'Vegetables', serving: '1 cup / 160g', kcal: 35, proteinG: 3.0, carbG: 7.0, fatG: 0.2, ingredients: 'Okra, water'),
    LibraryFood(name: 'Aubergine (cooked)', category: 'Vegetables', serving: '1 cup / 100g', kcal: 35, proteinG: 0.8, carbG: 9.0, fatG: 0.2, ingredients: 'Aubergine, water'),
    LibraryFood(name: 'Cabbage (cooked)', category: 'Vegetables', serving: '1 cup / 150g', kcal: 34, proteinG: 1.5, carbG: 8.0, fatG: 0.1, ingredients: 'Cabbage, water'),
    LibraryFood(name: 'Bitter Gourd (Korola)', category: 'Vegetables', serving: '1 cup / 120g', kcal: 24, proteinG: 1.0, carbG: 5.0, fatG: 0.2, ingredients: 'Bitter gourd, water'),
    LibraryFood(name: 'Bottle Gourd (Lau)', category: 'Vegetables', serving: '1 cup / 150g', kcal: 22, proteinG: 0.9, carbG: 5.0, fatG: 0.1, ingredients: 'Bottle gourd, water'),
    LibraryFood(name: 'Green Salad (undressed)', category: 'Vegetables', serving: '1 bowl', kcal: 35, proteinG: 2.0, carbG: 6.0, fatG: 0.3, ingredients: 'Lettuce, cucumber, tomato, onion'),
    LibraryFood(name: 'Sweetcorn (cooked)', category: 'Vegetables', serving: '1 cup / 165g', kcal: 143, proteinG: 5.0, carbG: 31.0, fatG: 2.0, ingredients: 'Sweetcorn kernels'),
    LibraryFood(name: 'Mushrooms (cooked)', category: 'Vegetables', serving: '1 cup / 150g', kcal: 44, proteinG: 3.4, carbG: 8.0, fatG: 0.7, ingredients: 'Button mushrooms, oil'),
    LibraryFood(name: 'Avocado', category: 'Vegetables', serving: '1/2 medium', kcal: 160, proteinG: 2.0, carbG: 9.0, fatG: 15.0, ingredients: 'Avocado'),

    // ---------------- FRUIT ----------------
    LibraryFood(name: 'Banana', category: 'Fruit', serving: '1 medium', kcal: 105, proteinG: 1.3, carbG: 27.0, fatG: 0.4, ingredients: 'Banana'),
    LibraryFood(name: 'Apple', category: 'Fruit', serving: '1 medium', kcal: 95, proteinG: 0.5, carbG: 25.0, fatG: 0.3, ingredients: 'Apple'),
    LibraryFood(name: 'Orange', category: 'Fruit', serving: '1 medium', kcal: 62, proteinG: 1.2, carbG: 15.0, fatG: 0.2, ingredients: 'Orange'),
    LibraryFood(name: 'Mango', category: 'Fruit', serving: '1 cup / 165g', kcal: 99, proteinG: 1.4, carbG: 25.0, fatG: 0.6, ingredients: 'Mango'),
    LibraryFood(name: 'Papaya', category: 'Fruit', serving: '1 cup / 145g', kcal: 62, proteinG: 0.7, carbG: 16.0, fatG: 0.4, ingredients: 'Papaya'),
    LibraryFood(name: 'Guava', category: 'Fruit', serving: '1 medium', kcal: 68, proteinG: 2.6, carbG: 14.0, fatG: 1.0, ingredients: 'Guava'),
    LibraryFood(name: 'Pineapple', category: 'Fruit', serving: '1 cup / 165g', kcal: 82, proteinG: 0.9, carbG: 22.0, fatG: 0.2, ingredients: 'Pineapple'),
    LibraryFood(name: 'Watermelon', category: 'Fruit', serving: '1 cup / 152g', kcal: 46, proteinG: 0.9, carbG: 12.0, fatG: 0.2, ingredients: 'Watermelon'),
    LibraryFood(name: 'Grapes', category: 'Fruit', serving: '1 cup / 151g', kcal: 104, proteinG: 1.1, carbG: 27.0, fatG: 0.2, ingredients: 'Grapes'),
    LibraryFood(name: 'Strawberries', category: 'Fruit', serving: '1 cup / 152g', kcal: 49, proteinG: 1.0, carbG: 12.0, fatG: 0.5, ingredients: 'Strawberries'),
    LibraryFood(name: 'Blueberries', category: 'Fruit', serving: '1 cup / 148g', kcal: 84, proteinG: 1.1, carbG: 21.0, fatG: 0.5, ingredients: 'Blueberries'),
    LibraryFood(name: 'Pear', category: 'Fruit', serving: '1 medium', kcal: 101, proteinG: 0.6, carbG: 27.0, fatG: 0.2, ingredients: 'Pear'),
    LibraryFood(name: 'Pomegranate', category: 'Fruit', serving: '1/2 cup arils', kcal: 72, proteinG: 1.5, carbG: 16.0, fatG: 1.0, ingredients: 'Pomegranate seeds'),
    LibraryFood(name: 'Jackfruit', category: 'Fruit', serving: '1 cup / 165g', kcal: 155, proteinG: 2.8, carbG: 38.0, fatG: 0.6, ingredients: 'Ripe jackfruit'),
    LibraryFood(name: 'Lychee', category: 'Fruit', serving: '1 cup / 190g', kcal: 125, proteinG: 1.6, carbG: 31.0, fatG: 0.8, ingredients: 'Lychee'),
    LibraryFood(name: 'Dates', category: 'Fruit', serving: '3 pieces', kcal: 200, proteinG: 1.7, carbG: 54.0, fatG: 0.2, ingredients: 'Medjool dates'),
    LibraryFood(name: 'Raisins', category: 'Fruit', serving: '30g', kcal: 90, proteinG: 1.0, carbG: 24.0, fatG: 0.1, ingredients: 'Dried grapes'),
    LibraryFood(name: 'Kiwi', category: 'Fruit', serving: '1 medium', kcal: 42, proteinG: 0.8, carbG: 10.0, fatG: 0.4, ingredients: 'Kiwifruit'),
    LibraryFood(name: 'Cantaloupe Melon', category: 'Fruit', serving: '1 cup / 160g', kcal: 54, proteinG: 1.3, carbG: 13.0, fatG: 0.3, ingredients: 'Cantaloupe'),

    // ---------------- NUTS & SEEDS ----------------
    LibraryFood(name: 'Almonds', category: 'Nuts & Seeds', serving: '28g / 23 nuts', kcal: 164, proteinG: 6.0, carbG: 6.0, fatG: 14.0, ingredients: 'Raw almonds'),
    LibraryFood(name: 'Cashews', category: 'Nuts & Seeds', serving: '28g', kcal: 157, proteinG: 5.0, carbG: 9.0, fatG: 12.0, ingredients: 'Roasted cashews'),
    LibraryFood(name: 'Walnuts', category: 'Nuts & Seeds', serving: '28g', kcal: 185, proteinG: 4.3, carbG: 4.0, fatG: 18.0, ingredients: 'Walnut halves'),
    LibraryFood(name: 'Peanuts (roasted)', category: 'Nuts & Seeds', serving: '28g', kcal: 166, proteinG: 7.0, carbG: 6.0, fatG: 14.0, ingredients: 'Roasted peanuts, salt'),
    LibraryFood(name: 'Pistachios', category: 'Nuts & Seeds', serving: '28g', kcal: 159, proteinG: 6.0, carbG: 8.0, fatG: 13.0, ingredients: 'Roasted pistachios, salt'),
    LibraryFood(name: 'Peanut Butter', category: 'Nuts & Seeds', serving: '2 tbsp / 32g', kcal: 190, proteinG: 8.0, carbG: 6.0, fatG: 16.0, ingredients: 'Ground peanuts, salt'),
    LibraryFood(name: 'Almond Butter', category: 'Nuts & Seeds', serving: '2 tbsp / 32g', kcal: 196, proteinG: 7.0, carbG: 6.0, fatG: 18.0, ingredients: 'Ground almonds'),
    LibraryFood(name: 'Chia Seeds', category: 'Nuts & Seeds', serving: '2 tbsp / 24g', kcal: 120, proteinG: 4.0, carbG: 10.0, fatG: 7.5, ingredients: 'Chia seeds'),
    LibraryFood(name: 'Flax Seeds', category: 'Nuts & Seeds', serving: '2 tbsp / 20g', kcal: 110, proteinG: 3.8, carbG: 6.0, fatG: 8.5, ingredients: 'Ground flaxseed'),
    LibraryFood(name: 'Pumpkin Seeds', category: 'Nuts & Seeds', serving: '28g', kcal: 158, proteinG: 8.5, carbG: 3.0, fatG: 13.0, ingredients: 'Hulled pumpkin seeds'),
    LibraryFood(name: 'Sunflower Seeds', category: 'Nuts & Seeds', serving: '28g', kcal: 165, proteinG: 5.5, carbG: 6.0, fatG: 14.0, ingredients: 'Hulled sunflower seeds'),
    LibraryFood(name: 'Fresh Coconut', category: 'Nuts & Seeds', serving: '30g', kcal: 106, proteinG: 1.0, carbG: 4.5, fatG: 10.0, ingredients: 'Coconut flesh'),

    // ---------------- SOUPS & SALADS ----------------
    LibraryFood(name: 'Chicken Soup', category: 'Soups & Salads', serving: '1 bowl / 250g', kcal: 120, proteinG: 10.0, carbG: 10.0, fatG: 4.0, ingredients: 'Chicken, stock, carrot, celery, noodles'),
    LibraryFood(name: 'Tomato Soup', category: 'Soups & Salads', serving: '1 bowl / 250g', kcal: 140, proteinG: 3.0, carbG: 22.0, fatG: 4.0, ingredients: 'Tomato, cream, onion, stock, basil'),
    LibraryFood(name: 'Lentil Soup', category: 'Soups & Salads', serving: '1 bowl / 250g', kcal: 190, proteinG: 12.0, carbG: 28.0, fatG: 3.0, ingredients: 'Red lentils, carrot, cumin, stock'),
    LibraryFood(name: 'Vegetable Soup', category: 'Soups & Salads', serving: '1 bowl / 250g', kcal: 100, proteinG: 4.0, carbG: 18.0, fatG: 2.0, ingredients: 'Mixed vegetables, stock, herbs'),
    LibraryFood(name: 'Coleslaw', category: 'Soups & Salads', serving: '1/2 cup', kcal: 150, proteinG: 1.0, carbG: 12.0, fatG: 11.0, ingredients: 'Cabbage, carrot, mayonnaise, vinegar'),
    LibraryFood(name: 'Tuna Salad', category: 'Soups & Salads', serving: '1 bowl', kcal: 330, proteinG: 28.0, carbG: 8.0, fatG: 21.0, ingredients: 'Tuna, mayonnaise, celery, onion, lettuce'),
    LibraryFood(name: 'Chicken & Rice Bowl', category: 'Soups & Salads', serving: '1 bowl / 400g', kcal: 550, proteinG: 40.0, carbG: 60.0, fatG: 15.0, ingredients: 'Grilled chicken, rice, vegetables, sauce'),

    // ---------------- SNACKS ----------------
    LibraryFood(name: 'Protein Bar', category: 'Snacks', serving: '1 bar / 60g', kcal: 220, proteinG: 20.0, carbG: 22.0, fatG: 7.0, ingredients: 'Whey protein, oats, nuts, sweetener'),
    LibraryFood(name: 'Granola Bar', category: 'Snacks', serving: '1 bar', kcal: 140, proteinG: 3.0, carbG: 22.0, fatG: 5.0, ingredients: 'Oats, honey, nuts, dried fruit'),
    LibraryFood(name: 'Plain Biscuits', category: 'Snacks', serving: '4 pieces', kcal: 180, proteinG: 2.5, carbG: 26.0, fatG: 7.0, ingredients: 'Flour, sugar, palm oil'),
    LibraryFood(name: 'Digestive Biscuit', category: 'Snacks', serving: '2 pieces', kcal: 140, proteinG: 2.0, carbG: 20.0, fatG: 6.0, ingredients: 'Wholemeal flour, palm oil, sugar'),
    LibraryFood(name: 'Potato Crisps', category: 'Snacks', serving: '1 small bag / 30g', kcal: 160, proteinG: 2.0, carbG: 15.0, fatG: 10.0, ingredients: 'Potato, sunflower oil, salt'),
    LibraryFood(name: 'Popcorn (air-popped)', category: 'Snacks', serving: '3 cups / 24g', kcal: 93, proteinG: 3.0, carbG: 19.0, fatG: 1.0, ingredients: 'Popcorn kernels, salt'),
    LibraryFood(name: 'Popcorn (buttered)', category: 'Snacks', serving: '3 cups', kcal: 180, proteinG: 3.0, carbG: 20.0, fatG: 10.0, ingredients: 'Popcorn, butter, salt'),
    LibraryFood(name: 'Chanachur / Bombay Mix', category: 'Snacks', serving: '30g', kcal: 150, proteinG: 4.0, carbG: 15.0, fatG: 8.0, ingredients: 'Gram flour noodles, peanuts, lentils, spices, oil'),
    LibraryFood(name: 'Jhalmuri', category: 'Snacks', serving: '1 bowl / 100g', kcal: 250, proteinG: 6.0, carbG: 38.0, fatG: 8.0, ingredients: 'Puffed rice, mustard oil, onion, chilli, chanachur'),
    LibraryFood(name: 'Beef Jerky', category: 'Snacks', serving: '30g', kcal: 116, proteinG: 13.0, carbG: 7.0, fatG: 4.0, ingredients: 'Dried beef, soy, sugar, spices'),
    LibraryFood(name: 'Trail Mix', category: 'Snacks', serving: '40g', kcal: 190, proteinG: 5.0, carbG: 18.0, fatG: 11.0, ingredients: 'Nuts, raisins, seeds, chocolate'),
    LibraryFood(name: 'Dark Chocolate (70%)', category: 'Snacks', serving: '30g', kcal: 170, proteinG: 2.0, carbG: 13.0, fatG: 12.0, ingredients: 'Cocoa mass, cocoa butter, sugar'),
    LibraryFood(name: 'Milk Chocolate Bar', category: 'Snacks', serving: '45g', kcal: 240, proteinG: 3.0, carbG: 26.0, fatG: 14.0, ingredients: 'Sugar, cocoa butter, milk solids, cocoa mass'),

    // ---------------- SWEETS ----------------
    LibraryFood(name: 'Gulab Jamun', category: 'Sweets', serving: '2 pieces', kcal: 300, proteinG: 4.0, carbG: 45.0, fatG: 12.0, ingredients: 'Milk solids, flour, sugar syrup, cardamom, ghee'),
    LibraryFood(name: 'Jalebi', category: 'Sweets', serving: '2 pieces', kcal: 250, proteinG: 2.0, carbG: 42.0, fatG: 9.0, ingredients: 'Fermented flour batter, sugar syrup, saffron, ghee'),
    LibraryFood(name: 'Suji Halwa', category: 'Sweets', serving: '1/2 cup', kcal: 300, proteinG: 4.0, carbG: 42.0, fatG: 13.0, ingredients: 'Semolina, ghee, sugar, cardamom, nuts'),
    LibraryFood(name: 'Firni', category: 'Sweets', serving: '1 cup / 150g', kcal: 230, proteinG: 6.0, carbG: 38.0, fatG: 6.0, ingredients: 'Ground rice, milk, sugar, cardamom, pistachio'),
    LibraryFood(name: 'Vanilla Ice Cream', category: 'Sweets', serving: '1 scoop / 65g', kcal: 140, proteinG: 2.5, carbG: 16.0, fatG: 7.0, ingredients: 'Cream, milk, sugar, vanilla, egg yolk'),
    LibraryFood(name: 'Chocolate Cake', category: 'Sweets', serving: '1 slice / 90g', kcal: 350, proteinG: 4.0, carbG: 48.0, fatG: 16.0, ingredients: 'Flour, cocoa, sugar, egg, butter, frosting'),
    LibraryFood(name: 'Cheesecake', category: 'Sweets', serving: '1 slice / 100g', kcal: 320, proteinG: 6.0, carbG: 26.0, fatG: 22.0, ingredients: 'Cream cheese, biscuit base, sugar, egg, cream'),
    LibraryFood(name: 'Glazed Doughnut', category: 'Sweets', serving: '1 piece', kcal: 260, proteinG: 3.0, carbG: 31.0, fatG: 14.0, ingredients: 'Enriched dough, frying oil, sugar glaze'),
    LibraryFood(name: 'Brownie', category: 'Sweets', serving: '1 piece / 60g', kcal: 250, proteinG: 3.0, carbG: 33.0, fatG: 12.0, ingredients: 'Chocolate, butter, sugar, egg, flour'),
    LibraryFood(name: 'Blueberry Muffin', category: 'Sweets', serving: '1 medium', kcal: 380, proteinG: 6.0, carbG: 54.0, fatG: 16.0, ingredients: 'Flour, sugar, oil, egg, blueberries'),
    LibraryFood(name: 'Chocolate Chip Cookie', category: 'Sweets', serving: '1 large', kcal: 200, proteinG: 2.5, carbG: 28.0, fatG: 9.0, ingredients: 'Flour, butter, brown sugar, chocolate chips, egg'),
    LibraryFood(name: 'Honey', category: 'Sweets', serving: '1 tbsp / 21g', kcal: 64, proteinG: 0.1, carbG: 17.0, fatG: 0.0, ingredients: 'Honey'),
    LibraryFood(name: 'White Sugar', category: 'Sweets', serving: '1 tsp / 4g', kcal: 16, proteinG: 0.0, carbG: 4.0, fatG: 0.0, ingredients: 'Sucrose'),

    // ---------------- FATS & SAUCES ----------------
    LibraryFood(name: 'Olive Oil', category: 'Fats & Sauces', serving: '1 tbsp / 14g', kcal: 119, proteinG: 0.0, carbG: 0.0, fatG: 14.0, ingredients: 'Extra virgin olive oil'),
    LibraryFood(name: 'Vegetable Oil', category: 'Fats & Sauces', serving: '1 tbsp / 14g', kcal: 120, proteinG: 0.0, carbG: 0.0, fatG: 14.0, ingredients: 'Sunflower or rapeseed oil'),
    LibraryFood(name: 'Mustard Oil', category: 'Fats & Sauces', serving: '1 tbsp / 14g', kcal: 124, proteinG: 0.0, carbG: 0.0, fatG: 14.0, ingredients: 'Cold-pressed mustard oil'),
    LibraryFood(name: 'Coconut Oil', category: 'Fats & Sauces', serving: '1 tbsp / 14g', kcal: 121, proteinG: 0.0, carbG: 0.0, fatG: 14.0, ingredients: 'Virgin coconut oil'),
    LibraryFood(name: 'Mayonnaise', category: 'Fats & Sauces', serving: '1 tbsp / 14g', kcal: 94, proteinG: 0.1, carbG: 0.1, fatG: 10.0, ingredients: 'Egg yolk, oil, vinegar, mustard'),
    LibraryFood(name: 'Ketchup', category: 'Fats & Sauces', serving: '1 tbsp / 17g', kcal: 19, proteinG: 0.2, carbG: 4.5, fatG: 0.0, ingredients: 'Tomato, sugar, vinegar, salt'),
    LibraryFood(name: 'Mustard', category: 'Fats & Sauces', serving: '1 tbsp / 15g', kcal: 10, proteinG: 0.6, carbG: 1.0, fatG: 0.5, ingredients: 'Mustard seed, vinegar, salt'),
    LibraryFood(name: 'Soy Sauce', category: 'Fats & Sauces', serving: '1 tbsp / 16g', kcal: 8, proteinG: 1.3, carbG: 0.8, fatG: 0.0, ingredients: 'Fermented soybean, wheat, salt'),
    LibraryFood(name: 'Ranch Dressing', category: 'Fats & Sauces', serving: '2 tbsp / 30g', kcal: 145, proteinG: 0.4, carbG: 2.0, fatG: 15.0, ingredients: 'Buttermilk, mayonnaise, herbs, garlic'),
    LibraryFood(name: 'Tahini', category: 'Fats & Sauces', serving: '1 tbsp / 15g', kcal: 89, proteinG: 2.6, carbG: 3.2, fatG: 8.0, ingredients: 'Ground sesame seeds'),

    // ---------------- DRINKS ----------------
    LibraryFood(name: 'Black Coffee', category: 'Drinks', serving: '1 cup', kcal: 2, proteinG: 0.3, carbG: 0.0, fatG: 0.0, ingredients: 'Coffee, water'),
    LibraryFood(name: 'Coffee with Milk & Sugar', category: 'Drinks', serving: '1 cup', kcal: 80, proteinG: 2.0, carbG: 12.0, fatG: 2.5, ingredients: 'Coffee, milk, sugar'),
    LibraryFood(name: 'Latte', category: 'Drinks', serving: '350ml', kcal: 190, proteinG: 12.0, carbG: 18.0, fatG: 7.0, ingredients: 'Espresso, steamed whole milk'),
    LibraryFood(name: 'Cappuccino', category: 'Drinks', serving: '250ml', kcal: 120, proteinG: 8.0, carbG: 12.0, fatG: 4.0, ingredients: 'Espresso, steamed milk, foam'),
    LibraryFood(name: 'Green Tea', category: 'Drinks', serving: '1 cup', kcal: 2, proteinG: 0.0, carbG: 0.5, fatG: 0.0, ingredients: 'Green tea leaves, water'),
    LibraryFood(name: 'Tea with Milk & Sugar', category: 'Drinks', serving: '1 cup', kcal: 90, proteinG: 2.0, carbG: 14.0, fatG: 2.5, ingredients: 'Black tea, milk, sugar'),
    LibraryFood(name: 'Masala Chai', category: 'Drinks', serving: '1 cup', kcal: 110, proteinG: 3.0, carbG: 16.0, fatG: 4.0, ingredients: 'Black tea, milk, sugar, cardamom, ginger'),
    LibraryFood(name: 'Orange Juice', category: 'Drinks', serving: '250ml', kcal: 112, proteinG: 1.7, carbG: 26.0, fatG: 0.5, ingredients: 'Orange juice'),
    LibraryFood(name: 'Apple Juice', category: 'Drinks', serving: '250ml', kcal: 114, proteinG: 0.3, carbG: 28.0, fatG: 0.3, ingredients: 'Apple juice'),
    LibraryFood(name: 'Mango Juice', category: 'Drinks', serving: '250ml', kcal: 130, proteinG: 0.5, carbG: 32.0, fatG: 0.3, ingredients: 'Mango pulp, water, sugar'),
    LibraryFood(name: 'Cola', category: 'Drinks', serving: '330ml can', kcal: 139, proteinG: 0.0, carbG: 35.0, fatG: 0.0, ingredients: 'Carbonated water, sugar, caramel, caffeine'),
    LibraryFood(name: 'Diet Cola', category: 'Drinks', serving: '330ml can', kcal: 2, proteinG: 0.0, carbG: 0.4, fatG: 0.0, ingredients: 'Carbonated water, aspartame, caramel'),
    LibraryFood(name: 'Energy Drink', category: 'Drinks', serving: '250ml can', kcal: 110, proteinG: 0.0, carbG: 28.0, fatG: 0.0, ingredients: 'Water, sugar, caffeine, taurine'),
    LibraryFood(name: 'Sports Drink', category: 'Drinks', serving: '500ml', kcal: 125, proteinG: 0.0, carbG: 32.0, fatG: 0.0, ingredients: 'Water, glucose, electrolytes'),
    LibraryFood(name: 'Sweet Lassi', category: 'Drinks', serving: '250ml', kcal: 190, proteinG: 7.0, carbG: 30.0, fatG: 4.5, ingredients: 'Yogurt, sugar, water, cardamom'),
    LibraryFood(name: 'Borhani', category: 'Drinks', serving: '250ml', kcal: 110, proteinG: 6.0, carbG: 12.0, fatG: 4.0, ingredients: 'Yogurt, mint, coriander, mustard, black salt'),
    LibraryFood(name: 'Coconut Water', category: 'Drinks', serving: '250ml', kcal: 45, proteinG: 1.7, carbG: 9.0, fatG: 0.5, ingredients: 'Young coconut water'),
    LibraryFood(name: 'Sugarcane Juice', category: 'Drinks', serving: '250ml', kcal: 180, proteinG: 0.5, carbG: 45.0, fatG: 0.2, ingredients: 'Pressed sugarcane, lemon'),
    LibraryFood(name: 'Lemonade', category: 'Drinks', serving: '250ml', kcal: 100, proteinG: 0.1, carbG: 26.0, fatG: 0.0, ingredients: 'Lemon juice, sugar, water'),
    LibraryFood(name: 'Beer', category: 'Drinks', serving: '330ml', kcal: 140, proteinG: 1.5, carbG: 11.0, fatG: 0.0, alcoholG: 13.0, ingredients: 'Malted barley, hops, yeast, water'),
    LibraryFood(name: 'Red Wine', category: 'Drinks', serving: '150ml', kcal: 125, proteinG: 0.1, carbG: 4.0, fatG: 0.0, alcoholG: 15.0, ingredients: 'Fermented red grapes'),
    LibraryFood(name: 'Spirits (40%)', category: 'Drinks', serving: '1 shot / 44ml', kcal: 97, proteinG: 0.0, carbG: 0.0, fatG: 0.0, alcoholG: 14.0, ingredients: 'Distilled spirit, water'),
    LibraryFood(name: 'Chocolate Milkshake', category: 'Drinks', serving: '400ml', kcal: 450, proteinG: 12.0, carbG: 68.0, fatG: 14.0, ingredients: 'Milk, ice cream, chocolate syrup'),
    LibraryFood(name: 'Fruit Smoothie', category: 'Drinks', serving: '350ml', kcal: 230, proteinG: 4.0, carbG: 48.0, fatG: 2.0, ingredients: 'Banana, berries, yogurt, juice'),
    LibraryFood(name: 'Water', category: 'Drinks', serving: '500ml', kcal: 0, proteinG: 0.0, carbG: 0.0, fatG: 0.0, ingredients: 'Water'),

    // ---------------- SUPPLEMENTS ----------------
    LibraryFood(name: 'Whey Protein', category: 'Supplements', serving: '1 scoop / 30g', kcal: 120, proteinG: 24.0, carbG: 3.0, fatG: 1.5, ingredients: 'Whey concentrate, flavouring, sweetener'),
    LibraryFood(name: 'Whey Isolate', category: 'Supplements', serving: '1 scoop / 30g', kcal: 110, proteinG: 26.0, carbG: 1.0, fatG: 0.5, ingredients: 'Whey isolate, flavouring, sweetener'),
    LibraryFood(name: 'Casein Protein', category: 'Supplements', serving: '1 scoop / 33g', kcal: 120, proteinG: 24.0, carbG: 4.0, fatG: 1.0, ingredients: 'Micellar casein, flavouring'),
    LibraryFood(name: 'Plant Protein Blend', category: 'Supplements', serving: '1 scoop / 33g', kcal: 130, proteinG: 22.0, carbG: 6.0, fatG: 2.5, ingredients: 'Pea protein, rice protein, flavouring'),
    LibraryFood(name: 'Mass Gainer', category: 'Supplements', serving: '1 scoop / 100g', kcal: 380, proteinG: 20.0, carbG: 70.0, fatG: 3.0, ingredients: 'Maltodextrin, whey, oat flour, vitamins'),
    LibraryFood(name: 'Protein Shake with Milk', category: 'Supplements', serving: '1 scoop + 300ml', kcal: 300, proteinG: 33.0, carbG: 18.0, fatG: 10.0, ingredients: 'Whey protein, whole milk'),
    LibraryFood(name: 'Creatine Monohydrate', category: 'Supplements', serving: '5g', kcal: 0, proteinG: 0.0, carbG: 0.0, fatG: 0.0, ingredients: 'Creatine monohydrate'),
    LibraryFood(name: 'BCAA Drink', category: 'Supplements', serving: '1 scoop', kcal: 10, proteinG: 0.0, carbG: 2.0, fatG: 0.0, ingredients: 'Leucine, isoleucine, valine, flavouring'),
    LibraryFood(name: 'Pre-Workout', category: 'Supplements', serving: '1 scoop', kcal: 15, proteinG: 0.0, carbG: 3.0, fatG: 0.0, ingredients: 'Caffeine, beta-alanine, citrulline, flavouring'),
    LibraryFood(name: 'Fish Oil Capsule', category: 'Supplements', serving: '2 capsules', kcal: 20, proteinG: 0.0, carbG: 0.0, fatG: 2.0, ingredients: 'Fish oil, gelatine, vitamin E'),
    LibraryFood(name: 'Multivitamin', category: 'Supplements', serving: '1 tablet', kcal: 0, proteinG: 0.0, carbG: 0.0, fatG: 0.0, ingredients: 'Vitamins, minerals, binder'),
    // ---------------- V2 AUDIT: EGGS ----------------
    LibraryFood(name: 'Cheese Omelette', category: 'Eggs & Dairy', serving: '2 eggs + 20g cheese', kcal: 225, proteinG: 17.0, carbG: 1.0, fatG: 17.0, ingredients: 'Eggs, cheddar, butter, salt'),
    LibraryFood(name: 'Masala Omelette', category: 'Eggs & Dairy', serving: '2 eggs', kcal: 212, proteinG: 13.0, carbG: 4.0, fatG: 16.0, ingredients: 'Eggs, onion, green chilli, coriander, oil'),
    LibraryFood(name: 'Egg Bhurji', category: 'Eggs & Dairy', serving: '2 eggs', kcal: 225, proteinG: 13.0, carbG: 5.0, fatG: 17.0, ingredients: 'Eggs, onion, tomato, chilli, oil, turmeric'),
    LibraryFood(name: 'Poached Egg', category: 'Eggs & Dairy', serving: '1 egg', kcal: 70, proteinG: 6.3, carbG: 0.4, fatG: 4.8, ingredients: 'Egg, water, vinegar'),
    LibraryFood(name: 'Omelette (3-egg)', category: 'Eggs & Dairy', serving: '3 eggs', kcal: 273, proteinG: 19.0, carbG: 2.0, fatG: 21.0, ingredients: 'Eggs, butter, salt'),
    LibraryFood(name: 'Egg Curry', category: 'Eggs & Dairy', serving: '2 eggs in gravy', kcal: 268, proteinG: 14.0, carbG: 8.0, fatG: 20.0, ingredients: 'Boiled eggs, onion, tomato, oil, spices'),
    LibraryFood(name: 'Dim Bhuna', category: 'Bengali', serving: '2 eggs', kcal: 242, proteinG: 14.0, carbG: 6.0, fatG: 18.0, ingredients: 'Eggs, onion, garlic, mustard oil, bhuna spices'),
    // ---------------- V2 AUDIT: BREADS ----------------
    LibraryFood(name: 'Cheese Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 354, proteinG: 10.0, carbG: 38.0, fatG: 18.0, ingredients: 'Atta flour, cheese, ghee or oil'),
    LibraryFood(name: 'Egg Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 345, proteinG: 12.0, carbG: 36.0, fatG: 17.0, ingredients: 'Atta flour, egg, oil'),
    LibraryFood(name: 'Paneer Paratha', category: 'Bread & Bakery', serving: '1 piece', kcal: 354, proteinG: 12.0, carbG: 36.0, fatG: 18.0, ingredients: 'Atta flour, paneer, ghee, spices'),
    LibraryFood(name: 'Roti with Ghee', category: 'Bread & Bakery', serving: '1 roti + 1 tsp ghee', kcal: 138, proteinG: 3.0, carbG: 18.0, fatG: 6.0, ingredients: 'Atta flour, water, ghee'),
    LibraryFood(name: 'Ruti (Atta, large)', category: 'Bread & Bakery', serving: '1 large piece', kcal: 140, proteinG: 4.5, carbG: 27.0, fatG: 1.5, ingredients: 'Wholewheat atta flour, water, no oil'),
    LibraryFood(name: 'Suji Ruti', category: 'Bread & Bakery', serving: '1 piece', kcal: 154, proteinG: 4.0, carbG: 30.0, fatG: 2.0, ingredients: 'Semolina, water, pinch of salt, light oil'),
    LibraryFood(name: 'Whole Wheat Bread (2 slices)', category: 'Bread & Bakery', serving: '2 slices', kcal: 154, proteinG: 7.0, carbG: 26.0, fatG: 2.5, ingredients: 'Wholewheat flour, yeast, salt'),
    LibraryFood(name: 'Cheese Toast', category: 'Breakfast', serving: '2 slices + 30g cheese', kcal: 289, proteinG: 15.0, carbG: 28.0, fatG: 13.0, ingredients: 'Bread, cheddar, butter'),
    LibraryFood(name: 'Chicken Sandwich', category: 'Western', serving: '1 sandwich', kcal: 340, proteinG: 24.0, carbG: 34.0, fatG: 12.0, ingredients: 'Bread, grilled chicken, mayonnaise, lettuce, tomato'),
    // ---------------- V2 AUDIT: GENERIC CURRIES ----------------
    LibraryFood(name: 'Chicken Curry', category: 'South Asian', serving: '150g with gravy', kcal: 250, proteinG: 25.0, carbG: 6.0, fatG: 14.0, ingredients: 'Chicken, onion, tomato, garlic, ginger, oil, spices'),
    LibraryFood(name: 'Fish Curry', category: 'South Asian', serving: '150g with gravy', kcal: 220, proteinG: 22.0, carbG: 6.0, fatG: 12.0, ingredients: 'White fish, onion, tomato, oil, turmeric, spices'),
    LibraryFood(name: 'Prawn Curry', category: 'South Asian', serving: '120g with gravy', kcal: 203, proteinG: 20.0, carbG: 6.0, fatG: 11.0, ingredients: 'Prawns, onion, coconut or tomato base, oil, spices'),
    LibraryFood(name: 'Vegetable Curry', category: 'South Asian', serving: '200g', kcal: 170, proteinG: 4.0, carbG: 16.0, fatG: 10.0, ingredients: 'Mixed vegetables, onion, tomato, oil, spices'),
    LibraryFood(name: 'Chicken Bhuna', category: 'Bengali', serving: '150g', kcal: 272, proteinG: 26.0, carbG: 6.0, fatG: 16.0, ingredients: 'Chicken, onion, mustard oil, bhuna spices, minimal gravy'),
    LibraryFood(name: 'Mutton Bhuna', category: 'Bengali', serving: '150g', kcal: 314, proteinG: 24.0, carbG: 5.0, fatG: 22.0, ingredients: 'Mutton, onion, mustard oil, bhuna spices'),
    LibraryFood(name: 'Duck Curry (Hasher Mangsho)', category: 'Bengali', serving: '150g', kcal: 342, proteinG: 22.0, carbG: 5.0, fatG: 26.0, ingredients: 'Duck, onion, coconut, mustard oil, spices'),
    LibraryFood(name: 'Chicken Jhol', category: 'Bengali', serving: '200g light curry', kcal: 201, proteinG: 24.0, carbG: 6.0, fatG: 9.0, ingredients: 'Chicken, potato, thin gravy, mustard oil, turmeric'),
    // ---------------- V2 AUDIT: BENGALI EVERYDAY ----------------
    LibraryFood(name: 'Shorshe Bata Mach', category: 'Bengali', serving: '150g', kcal: 252, proteinG: 22.0, carbG: 5.0, fatG: 16.0, ingredients: 'Fish, mustard paste, mustard oil, green chilli, turmeric'),
    LibraryFood(name: 'Shorshe Chingri', category: 'Bengali', serving: '120g', kcal: 222, proteinG: 19.0, carbG: 5.0, fatG: 14.0, ingredients: 'Prawns, mustard paste, mustard oil, green chilli'),
    LibraryFood(name: 'Chingri Bhorta', category: 'Bengali', serving: '100g', kcal: 162, proteinG: 14.0, carbG: 4.0, fatG: 10.0, ingredients: 'Prawns, onion, green chilli, mustard oil, coriander'),
    LibraryFood(name: 'Lau Chingri', category: 'Bengali', serving: '200g', kcal: 161, proteinG: 12.0, carbG: 8.0, fatG: 9.0, ingredients: 'Bottle gourd, prawns, mustard oil, panch phoron'),
    LibraryFood(name: 'Fish Fry (Bengali)', category: 'Bengali', serving: '100g coated fillet', kcal: 230, proteinG: 18.0, carbG: 8.0, fatG: 14.0, ingredients: 'Fish, semolina or breadcrumb coating, oil, spices'),
    LibraryFood(name: 'Chicken Fry (Bengali)', category: 'Bengali', serving: '1 piece', kcal: 239, proteinG: 20.0, carbG: 6.0, fatG: 15.0, ingredients: 'Chicken, marinade spices, oil, light batter'),
    LibraryFood(name: 'Aloo Bhorta with Mustard Oil', category: 'Bengali', serving: '100g', kcal: 152, proteinG: 2.0, carbG: 18.0, fatG: 8.0, ingredients: 'Boiled potato, onion, green chilli, mustard oil, salt'),
    LibraryFood(name: 'Tehari (Chicken)', category: 'Bengali', serving: '300g', kcal: 532, proteinG: 26.0, carbG: 62.0, fatG: 20.0, ingredients: 'Chinigura rice, chicken, mustard oil, tehari spices'),
    LibraryFood(name: 'Tehari (Mutton)', category: 'Bengali', serving: '300g', kcal: 574, proteinG: 25.0, carbG: 60.0, fatG: 26.0, ingredients: 'Chinigura rice, mutton, mustard oil, tehari spices'),
    LibraryFood(name: 'Chicken Khichuri', category: 'Bengali', serving: '350g', kcal: 472, proteinG: 24.0, carbG: 58.0, fatG: 16.0, ingredients: 'Rice, moong dal, chicken, ghee, spices'),
    LibraryFood(name: 'Dim Khichuri', category: 'Bengali', serving: '350g', kcal: 447, proteinG: 18.0, carbG: 60.0, fatG: 15.0, ingredients: 'Rice, moong dal, egg, ghee, spices'),
    LibraryFood(name: 'Vegetable Khichuri', category: 'Bengali', serving: '350g', kcal: 404, proteinG: 12.0, carbG: 62.0, fatG: 12.0, ingredients: 'Rice, moong dal, mixed vegetables, ghee, spices'),
    LibraryFood(name: 'Dal Bhat', category: 'Bengali', serving: '350g', kcal: 374, proteinG: 12.0, carbG: 68.0, fatG: 6.0, ingredients: 'White rice, masoor dal, oil, turmeric'),
    // ---------------- V2 AUDIT: STAPLES AND DRINKS ----------------
    LibraryFood(name: 'Chola Boot', category: 'Legumes & Beans', serving: '150g', kcal: 205, proteinG: 10.0, carbG: 30.0, fatG: 5.0, ingredients: 'Boiled chickpeas, onion, green chilli, mustard oil, lemon'),
    LibraryFood(name: 'Mixed Fruit Salad', category: 'Fruit', serving: '200g', kcal: 110, proteinG: 1.5, carbG: 25.0, fatG: 0.5, ingredients: 'Seasonal fruit, no added sugar'),
    LibraryFood(name: 'Instant Coffee (black)', category: 'Drinks', serving: '1 cup', kcal: 3, proteinG: 0.2, carbG: 0.5, fatG: 0.0, ingredients: 'Instant coffee, water'),
    LibraryFood(name: 'Sugar-free Tea with Milk', category: 'Drinks', serving: '1 cup', kcal: 28, proteinG: 1.5, carbG: 2.0, fatG: 1.5, ingredients: 'Tea, milk, sweetener'),
  ];

  static List<LibraryFood> byCategory(String category) =>
      all.where((f) => f.category == category).toList();

  /// Ranked search. Delegates to the shared pipeline in `food_search.dart`
  /// so the picker and any other caller cannot disagree about what matches.
  static List<LibraryFood> search(String needle) =>
      searchFoods(needle).map((h) => h.item).toList();

  static LibraryFood? findByName(String name) {
    final lower = name.toLowerCase().trim();
    for (final f in all) {
      if (f.name.toLowerCase() == lower) return f;
    }
    return null;
  }
}
