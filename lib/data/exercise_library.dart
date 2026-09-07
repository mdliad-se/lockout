// LOCKOUT exercise catalog.
// Entries resolve to a YouTube search query biased toward 3D / animated form
// demonstrations. Queries are used instead of hardcoded video IDs so the links
// never rot; a user-pinned video URL on ExerciseDef overrides the search.

class LibraryExercise {
  final String name;
  final String muscleGroup;
  final String equipment;
  final int defaultSets;
  final int defaultRepsMin;
  final int defaultRepsMax;

  const LibraryExercise({
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.defaultSets,
    required this.defaultRepsMin,
    required this.defaultRepsMax,
  });

  /// Search phrase opened by the in-app video screen.
  String get videoQuery => ExerciseLibrary.queryFor(name);

  /// Cheap fuzzy match used by the picker search field.
  bool matches(String needle) {
    if (needle.isEmpty) return true;
    final n = needle.toLowerCase();
    return name.toLowerCase().contains(n) ||
        muscleGroup.toLowerCase().contains(n) ||
        equipment.toLowerCase().contains(n);
  }
}

class ExerciseLibrary {
  ExerciseLibrary._();

  static const List<String> muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Legs',
    'Glutes',
    'Calves',
    'Core',
    'Forearms',
    'Cardio',
    'Full Body',
    'Mobility',
  ];

  static const List<LibraryExercise> all = [
    // --- CHEST ---
    LibraryExercise(name: 'Barbell Bench Press', muscleGroup: 'Chest', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 6, defaultRepsMax: 10),
    LibraryExercise(name: 'Incline Barbell Bench Press', muscleGroup: 'Chest', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Decline Barbell Bench Press', muscleGroup: 'Chest', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Dumbbell Bench Press', muscleGroup: 'Chest', equipment: 'Dumbbell', defaultSets: 4, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Incline Dumbbell Press', muscleGroup: 'Chest', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Dumbbell Fly', muscleGroup: 'Chest', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Incline Dumbbell Fly', muscleGroup: 'Chest', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Cable Crossover', muscleGroup: 'Chest', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Low Cable Fly', muscleGroup: 'Chest', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Pec Deck Machine', muscleGroup: 'Chest', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Chest Press Machine', muscleGroup: 'Chest', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Push-Up', muscleGroup: 'Chest', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 20),
    LibraryExercise(name: 'Incline Push-Up', muscleGroup: 'Chest', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 20),
    LibraryExercise(name: 'Decline Push-Up', muscleGroup: 'Chest', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Diamond Push-Up', muscleGroup: 'Chest', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Chest Dip', muscleGroup: 'Chest', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Svend Press', muscleGroup: 'Chest', equipment: 'Plate', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Landmine Press', muscleGroup: 'Chest', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),

    // --- BACK ---
    LibraryExercise(name: 'Deadlift', muscleGroup: 'Back', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 4, defaultRepsMax: 6),
    LibraryExercise(name: 'Rack Pull', muscleGroup: 'Back', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 5, defaultRepsMax: 8),
    LibraryExercise(name: 'Barbell Row', muscleGroup: 'Back', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 8, defaultRepsMax: 10),
    LibraryExercise(name: 'Pendlay Row', muscleGroup: 'Back', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 6, defaultRepsMax: 8),
    LibraryExercise(name: 'T-Bar Row', muscleGroup: 'Back', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Dumbbell Row', muscleGroup: 'Back', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Chest-Supported Dumbbell Row', muscleGroup: 'Back', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Lat Pulldown', muscleGroup: 'Back', equipment: 'Cable', defaultSets: 4, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Close-Grip Lat Pulldown', muscleGroup: 'Back', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Straight-Arm Pulldown', muscleGroup: 'Back', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Seated Cable Row', muscleGroup: 'Back', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Single-Arm Cable Row', muscleGroup: 'Back', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Pull-Up', muscleGroup: 'Back', equipment: 'Bodyweight', defaultSets: 4, defaultRepsMin: 5, defaultRepsMax: 10),
    LibraryExercise(name: 'Chin-Up', muscleGroup: 'Back', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 6, defaultRepsMax: 10),
    LibraryExercise(name: 'Neutral-Grip Pull-Up', muscleGroup: 'Back', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 6, defaultRepsMax: 10),
    LibraryExercise(name: 'Inverted Row', muscleGroup: 'Back', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Face Pull', muscleGroup: 'Back', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Back Extension', muscleGroup: 'Back', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Good Morning', muscleGroup: 'Back', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Barbell Shrug', muscleGroup: 'Back', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Dumbbell Shrug', muscleGroup: 'Back', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),

    // --- SHOULDERS ---
    LibraryExercise(name: 'Overhead Press', muscleGroup: 'Shoulders', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 6, defaultRepsMax: 10),
    LibraryExercise(name: 'Seated Dumbbell Shoulder Press', muscleGroup: 'Shoulders', equipment: 'Dumbbell', defaultSets: 4, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Arnold Press', muscleGroup: 'Shoulders', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Push Press', muscleGroup: 'Shoulders', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 5, defaultRepsMax: 8),
    LibraryExercise(name: 'Lateral Raise', muscleGroup: 'Shoulders', equipment: 'Dumbbell', defaultSets: 4, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Cable Lateral Raise', muscleGroup: 'Shoulders', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Front Raise', muscleGroup: 'Shoulders', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Rear Delt Fly', muscleGroup: 'Shoulders', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Reverse Pec Deck', muscleGroup: 'Shoulders', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Upright Row', muscleGroup: 'Shoulders', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Shoulder Press Machine', muscleGroup: 'Shoulders', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Pike Push-Up', muscleGroup: 'Shoulders', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),

    // --- BICEPS ---
    LibraryExercise(name: 'Barbell Curl', muscleGroup: 'Biceps', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'EZ-Bar Curl', muscleGroup: 'Biceps', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Dumbbell Curl', muscleGroup: 'Biceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Alternating Dumbbell Curl', muscleGroup: 'Biceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Hammer Curl', muscleGroup: 'Biceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Incline Dumbbell Curl', muscleGroup: 'Biceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Preacher Curl', muscleGroup: 'Biceps', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Concentration Curl', muscleGroup: 'Biceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Cable Curl', muscleGroup: 'Biceps', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Spider Curl', muscleGroup: 'Biceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),

    // --- TRICEPS ---
    LibraryExercise(name: 'Close-Grip Bench Press', muscleGroup: 'Triceps', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 10),
    LibraryExercise(name: 'Triceps Pushdown', muscleGroup: 'Triceps', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Rope Triceps Pushdown', muscleGroup: 'Triceps', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Overhead Cable Extension', muscleGroup: 'Triceps', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Skull Crusher', muscleGroup: 'Triceps', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Dumbbell Overhead Extension', muscleGroup: 'Triceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Triceps Kickback', muscleGroup: 'Triceps', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Triceps Dip', muscleGroup: 'Triceps', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Bench Dip', muscleGroup: 'Triceps', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),

    // --- LEGS ---
    LibraryExercise(name: 'Back Squat', muscleGroup: 'Legs', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 6, defaultRepsMax: 10),
    LibraryExercise(name: 'Front Squat', muscleGroup: 'Legs', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 6, defaultRepsMax: 10),
    LibraryExercise(name: 'Goblet Squat', muscleGroup: 'Legs', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Box Squat', muscleGroup: 'Legs', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 10),
    LibraryExercise(name: 'Leg Press', muscleGroup: 'Legs', equipment: 'Machine', defaultSets: 4, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Hack Squat', muscleGroup: 'Legs', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Bulgarian Split Squat', muscleGroup: 'Legs', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Walking Lunge', muscleGroup: 'Legs', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Reverse Lunge', muscleGroup: 'Legs', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Step-Up', muscleGroup: 'Legs', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Leg Extension', muscleGroup: 'Legs', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Lying Leg Curl', muscleGroup: 'Legs', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Seated Leg Curl', muscleGroup: 'Legs', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Romanian Deadlift', muscleGroup: 'Legs', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Dumbbell Romanian Deadlift', muscleGroup: 'Legs', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 12),
    LibraryExercise(name: 'Sumo Deadlift', muscleGroup: 'Legs', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 5, defaultRepsMax: 8),
    LibraryExercise(name: 'Wall Sit', muscleGroup: 'Legs', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 30, defaultRepsMax: 60),
    LibraryExercise(name: 'Bodyweight Squat', muscleGroup: 'Legs', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Sissy Squat', muscleGroup: 'Legs', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Terminal Knee Extension', muscleGroup: 'Legs', equipment: 'Band', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),

    // --- GLUTES ---
    LibraryExercise(name: 'Hip Thrust', muscleGroup: 'Glutes', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Glute Bridge', muscleGroup: 'Glutes', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 20),
    LibraryExercise(name: 'Single-Leg Glute Bridge', muscleGroup: 'Glutes', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Cable Kickback', muscleGroup: 'Glutes', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Hip Abduction Machine', muscleGroup: 'Glutes', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Banded Lateral Walk', muscleGroup: 'Glutes', equipment: 'Band', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Clamshell', muscleGroup: 'Glutes', equipment: 'Band', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Frog Pump', muscleGroup: 'Glutes', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 25),

    // --- CALVES ---
    LibraryExercise(name: 'Standing Calf Raise', muscleGroup: 'Calves', equipment: 'Machine', defaultSets: 4, defaultRepsMin: 12, defaultRepsMax: 20),
    LibraryExercise(name: 'Seated Calf Raise', muscleGroup: 'Calves', equipment: 'Machine', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Dumbbell Calf Raise', muscleGroup: 'Calves', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Single-Leg Calf Raise', muscleGroup: 'Calves', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 20),

    // --- CORE ---
    LibraryExercise(name: 'Plank', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 30, defaultRepsMax: 60),
    LibraryExercise(name: 'Side Plank', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 30, defaultRepsMax: 45),
    LibraryExercise(name: 'Crunch', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 25),
    LibraryExercise(name: 'Bicycle Crunch', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 20, defaultRepsMax: 30),
    LibraryExercise(name: 'Hanging Leg Raise', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Lying Leg Raise', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 20),
    LibraryExercise(name: 'Cable Crunch', muscleGroup: 'Core', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Russian Twist', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 20, defaultRepsMax: 30),
    LibraryExercise(name: 'Ab Wheel Rollout', muscleGroup: 'Core', equipment: 'Wheel', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Mountain Climber', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 20, defaultRepsMax: 30),
    LibraryExercise(name: 'Dead Bug', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Bird Dog', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Hollow Body Hold', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 20, defaultRepsMax: 40),
    LibraryExercise(name: 'Pallof Press', muscleGroup: 'Core', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Cable Woodchopper', muscleGroup: 'Core', equipment: 'Cable', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Toe Touch', muscleGroup: 'Core', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),

    // --- FOREARMS ---
    LibraryExercise(name: 'Wrist Curl', muscleGroup: 'Forearms', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Reverse Wrist Curl', muscleGroup: 'Forearms', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Reverse Curl', muscleGroup: 'Forearms', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 12, defaultRepsMax: 15),
    LibraryExercise(name: 'Farmers Walk', muscleGroup: 'Forearms', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 30, defaultRepsMax: 60),
    LibraryExercise(name: 'Plate Pinch Hold', muscleGroup: 'Forearms', equipment: 'Plate', defaultSets: 3, defaultRepsMin: 20, defaultRepsMax: 40),

    // --- CARDIO ---
    LibraryExercise(name: 'Treadmill Run', muscleGroup: 'Cardio', equipment: 'Machine', defaultSets: 1, defaultRepsMin: 10, defaultRepsMax: 30),
    LibraryExercise(name: 'Treadmill Incline Walk', muscleGroup: 'Cardio', equipment: 'Machine', defaultSets: 1, defaultRepsMin: 15, defaultRepsMax: 30),
    LibraryExercise(name: 'Stationary Bike', muscleGroup: 'Cardio', equipment: 'Machine', defaultSets: 1, defaultRepsMin: 10, defaultRepsMax: 30),
    LibraryExercise(name: 'Rowing Machine', muscleGroup: 'Cardio', equipment: 'Machine', defaultSets: 1, defaultRepsMin: 10, defaultRepsMax: 20),
    LibraryExercise(name: 'Elliptical', muscleGroup: 'Cardio', equipment: 'Machine', defaultSets: 1, defaultRepsMin: 15, defaultRepsMax: 30),
    LibraryExercise(name: 'Stair Climber', muscleGroup: 'Cardio', equipment: 'Machine', defaultSets: 1, defaultRepsMin: 10, defaultRepsMax: 20),
    LibraryExercise(name: 'Jump Rope', muscleGroup: 'Cardio', equipment: 'Rope', defaultSets: 3, defaultRepsMin: 60, defaultRepsMax: 120),
    LibraryExercise(name: 'Burpee', muscleGroup: 'Cardio', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'High Knees', muscleGroup: 'Cardio', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 30, defaultRepsMax: 45),
    LibraryExercise(name: 'Shadow Boxing', muscleGroup: 'Cardio', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 60, defaultRepsMax: 90),
    LibraryExercise(name: 'Battle Ropes', muscleGroup: 'Cardio', equipment: 'Rope', defaultSets: 3, defaultRepsMin: 20, defaultRepsMax: 30),
    LibraryExercise(name: 'Sled Push', muscleGroup: 'Cardio', equipment: 'Sled', defaultSets: 4, defaultRepsMin: 20, defaultRepsMax: 30),

    // --- FULL BODY ---
    LibraryExercise(name: 'Clean and Press', muscleGroup: 'Full Body', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 5, defaultRepsMax: 8),
    LibraryExercise(name: 'Power Clean', muscleGroup: 'Full Body', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 3, defaultRepsMax: 5),
    LibraryExercise(name: 'Barbell Snatch', muscleGroup: 'Full Body', equipment: 'Barbell', defaultSets: 4, defaultRepsMin: 3, defaultRepsMax: 5),
    LibraryExercise(name: 'Thruster', muscleGroup: 'Full Body', equipment: 'Barbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Kettlebell Swing', muscleGroup: 'Full Body', equipment: 'Kettlebell', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Turkish Get-Up', muscleGroup: 'Full Body', equipment: 'Kettlebell', defaultSets: 3, defaultRepsMin: 3, defaultRepsMax: 5),
    LibraryExercise(name: 'Dumbbell Clean', muscleGroup: 'Full Body', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 8, defaultRepsMax: 10),
    LibraryExercise(name: 'Man Maker', muscleGroup: 'Full Body', equipment: 'Dumbbell', defaultSets: 3, defaultRepsMin: 6, defaultRepsMax: 10),
    LibraryExercise(name: 'Bear Crawl', muscleGroup: 'Full Body', equipment: 'Bodyweight', defaultSets: 3, defaultRepsMin: 20, defaultRepsMax: 30),

    // --- MOBILITY ---
    LibraryExercise(name: 'Cat-Cow Stretch', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Worlds Greatest Stretch', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 5, defaultRepsMax: 8),
    LibraryExercise(name: 'Hip Flexor Stretch', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 30, defaultRepsMax: 45),
    LibraryExercise(name: 'Hamstring Stretch', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 30, defaultRepsMax: 45),
    LibraryExercise(name: 'Thoracic Rotation', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 8, defaultRepsMax: 12),
    LibraryExercise(name: 'Shoulder Dislocate', muscleGroup: 'Mobility', equipment: 'Band', defaultSets: 2, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Band Pull-Apart', muscleGroup: 'Mobility', equipment: 'Band', defaultSets: 3, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Arm Circles', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 15, defaultRepsMax: 20),
    LibraryExercise(name: 'Ankle Circles', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Leg Swings', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 10, defaultRepsMax: 15),
    LibraryExercise(name: 'Childs Pose', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 30, defaultRepsMax: 45),
    LibraryExercise(name: 'Couch Stretch', muscleGroup: 'Mobility', equipment: 'Bodyweight', defaultSets: 2, defaultRepsMin: 30, defaultRepsMax: 45),
  ];

  static List<LibraryExercise> byGroup(String group) =>
      all.where((e) => e.muscleGroup == group).toList();

  static List<LibraryExercise> search(String needle) =>
      all.where((e) => e.matches(needle)).toList();

  static LibraryExercise? findByName(String name) {
    final lower = name.toLowerCase().trim();
    for (final e in all) {
      if (e.name.toLowerCase() == lower) return e;
    }
    return null;
  }

  /// Query used for any exercise -- catalog entry or user-typed custom name.
  static String queryFor(String exerciseName) =>
      '$exerciseName exercise 3d animation proper form technique';

  /// Muscle group for a saved exercise, resolved by name; '' when unknown.
  static String groupFor(String exerciseName) =>
      findByName(exerciseName)?.muscleGroup ?? '';
}
