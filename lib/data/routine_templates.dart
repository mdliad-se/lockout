/// A warm-up or finisher line: a name plus an amount ("3-4 min", "15 reps").
class TemplateItem {
  final String name;
  final String amt;

  const TemplateItem(this.name, this.amt);
}

/// One scaffolded training day inside a [RoutineTemplate].
class TemplateDay {
  final String tag;
  final String name;

  /// Muscle groups, shown as the day's subtitle.
  final String focus;

  final List<String> exercises;
  final List<TemplateItem> warmups;
  final List<TemplateItem> finishers;

  const TemplateDay({
    required this.tag,
    required this.name,
    required this.focus,
    required this.exercises,
    this.warmups = const [],
    this.finishers = const [],
  });
}

/// Standard warm-up blocks, reused across days so a template stays readable.
class _Warmups {
  static const push = [
    TemplateItem('Light cardio (jog / treadmill)', '3-4 min'),
    TemplateItem('Arm circles, each direction', '15 reps'),
    TemplateItem('Band pull-aparts', '15 reps'),
    TemplateItem('Empty-bar bench ramp-up set', '1-2 sets'),
  ];

  static const pull = [
    TemplateItem('Light cardio (jog / treadmill)', '3-4 min'),
    TemplateItem('Arm circles, each direction', '15 reps'),
    TemplateItem('Band pull-aparts or light rows', '15 reps'),
    TemplateItem('Light lat pulldown ramp-up set', '1-2 sets'),
  ];

  static const legs = [
    TemplateItem('Easy bike or brisk walk', '4-5 min'),
    TemplateItem('Ankle circles, both directions', '10 each'),
    TemplateItem('Bodyweight squats, easy range', '15 reps'),
    TemplateItem('Empty-bar squat ramp-up set', '1-2 sets'),
  ];

  static const general = [
    TemplateItem('Light cardio (jog / treadmill)', '4-5 min'),
    TemplateItem('Arm circles + leg swings', '15 each'),
    TemplateItem('Bodyweight squats', '15 reps'),
  ];
}

/// Standard conditioning finishers.
class _Finishers {
  static const upper = [
    TemplateItem('Shadow boxing', '30s'),
    TemplateItem('Push-ups', '12-15 reps'),
    TemplateItem('Plank', '30s'),
    TemplateItem('Rest between rounds', '30s'),
  ];

  static const core = [
    TemplateItem('Seated torso twists', '20 reps'),
    TemplateItem('Russian twists', '20 reps'),
    TemplateItem('Plank', '30s'),
    TemplateItem('Rest between rounds', '30s'),
  ];

  static const lower = [
    TemplateItem('Bodyweight squats', '20 reps'),
    TemplateItem('Glute bridges', '20 reps'),
    TemplateItem('Wall sit', '30s'),
    TemplateItem('Rest between rounds', '30s'),
  ];
}

/// Starter splits offered in the "New Routine" flow so a user can get a full
/// week of programming without adding every exercise by hand.
///
/// Exercise names are catalog names — they resolve through
/// `ExerciseLibrary.findByName` for sets/reps defaults and muscle group.
class RoutineTemplate {
  final String key;
  final String name;
  final String blurb;
  final List<TemplateDay> days;

  const RoutineTemplate({
    required this.key,
    required this.name,
    required this.blurb,
    required this.days,
  });

  static const List<RoutineTemplate> all = [
    RoutineTemplate(
      key: 'blank',
      name: 'Blank Routine',
      blurb: 'Start empty and add your own training days.',
      days: [],
    ),
    RoutineTemplate(
      key: 'ppl',
      name: 'Push / Pull / Legs',
      blurb: '3 days - Sat, Sun, Mon. Classic hypertrophy split.',
      days: [
        TemplateDay(
          tag: 'SAT',
          name: 'Push',
          focus: 'Chest - Shoulders - Triceps',
          warmups: _Warmups.push,
          exercises: [
            'Barbell Bench Press',
            'Seated Dumbbell Shoulder Press',
            'Incline Dumbbell Press',
            'Lateral Raise',
            'Triceps Pushdown',
          ],
          finishers: _Finishers.upper,
        ),
        TemplateDay(
          tag: 'SUN',
          name: 'Pull',
          focus: 'Back - Biceps',
          warmups: _Warmups.pull,
          exercises: [
            'Lat Pulldown',
            'Barbell Row',
            'Seated Cable Row',
            'Face Pull',
            'Dumbbell Curl',
          ],
          finishers: _Finishers.core,
        ),
        TemplateDay(
          tag: 'MON',
          name: 'Legs',
          focus: 'Quads - Hamstrings - Calves',
          warmups: _Warmups.legs,
          exercises: [
            'Back Squat',
            'Romanian Deadlift',
            'Leg Press',
            'Lying Leg Curl',
            'Standing Calf Raise',
          ],
          finishers: _Finishers.lower,
        ),
      ],
    ),
    RoutineTemplate(
      key: 'upper_lower',
      name: 'Upper / Lower',
      blurb: '4 days - Sat, Sun, Tue, Wed. Balanced strength split.',
      days: [
        TemplateDay(
          tag: 'SAT',
          name: 'Upper A',
          focus: 'Chest - Back - Arms',
          warmups: _Warmups.push,
          exercises: [
            'Barbell Bench Press',
            'Barbell Row',
            'Overhead Press',
            'Lat Pulldown',
            'Dumbbell Curl',
            'Triceps Pushdown',
          ],
          finishers: _Finishers.upper,
        ),
        TemplateDay(
          tag: 'SUN',
          name: 'Lower A',
          focus: 'Quads - Glutes',
          warmups: _Warmups.legs,
          exercises: [
            'Back Squat',
            'Romanian Deadlift',
            'Walking Lunge',
            'Leg Extension',
            'Standing Calf Raise',
          ],
          finishers: _Finishers.lower,
        ),
        TemplateDay(
          tag: 'TUE',
          name: 'Upper B',
          focus: 'Shoulders - Back Width',
          warmups: _Warmups.pull,
          exercises: [
            'Incline Dumbbell Press',
            'Pull-Up',
            'Seated Dumbbell Shoulder Press',
            'Seated Cable Row',
            'Hammer Curl',
            'Skull Crusher',
          ],
          finishers: _Finishers.core,
        ),
        TemplateDay(
          tag: 'WED',
          name: 'Lower B',
          focus: 'Hamstrings - Posterior Chain',
          warmups: _Warmups.legs,
          exercises: [
            'Deadlift',
            'Front Squat',
            'Lying Leg Curl',
            'Hip Thrust',
            'Seated Calf Raise',
          ],
          finishers: _Finishers.lower,
        ),
      ],
    ),
    RoutineTemplate(
      key: 'full_body',
      name: 'Full Body 3x',
      blurb: '3 days - Sat, Mon, Wed. Best for beginners and busy weeks.',
      days: [
        TemplateDay(
          tag: 'SAT',
          name: 'Full Body A',
          focus: 'Squat - Press - Pull',
          warmups: _Warmups.general,
          exercises: [
            'Back Squat',
            'Barbell Bench Press',
            'Barbell Row',
            'Plank',
          ],
          finishers: _Finishers.core,
        ),
        TemplateDay(
          tag: 'MON',
          name: 'Full Body B',
          focus: 'Hinge - Press - Pull',
          warmups: _Warmups.general,
          exercises: [
            'Romanian Deadlift',
            'Overhead Press',
            'Lat Pulldown',
            'Hanging Leg Raise',
          ],
          finishers: _Finishers.upper,
        ),
        TemplateDay(
          tag: 'WED',
          name: 'Full Body C',
          focus: 'Lunge - Press - Row',
          warmups: _Warmups.general,
          exercises: [
            'Bulgarian Split Squat',
            'Incline Dumbbell Press',
            'Seated Cable Row',
            'Russian Twist',
          ],
          finishers: _Finishers.lower,
        ),
      ],
    ),
    RoutineTemplate(
      key: 'bro_split',
      name: '5-Day Body Part Split',
      blurb: '5 days - Sat to Wed. One muscle group per session.',
      days: [
        TemplateDay(
          tag: 'SAT',
          name: 'Chest',
          focus: 'Chest',
          warmups: _Warmups.push,
          exercises: [
            'Barbell Bench Press',
            'Incline Dumbbell Press',
            'Cable Crossover',
            'Chest Dip',
          ],
          finishers: _Finishers.upper,
        ),
        TemplateDay(
          tag: 'SUN',
          name: 'Back',
          focus: 'Back - Lats - Traps',
          warmups: _Warmups.pull,
          exercises: [
            'Deadlift',
            'Lat Pulldown',
            'Barbell Row',
            'Straight-Arm Pulldown',
          ],
          finishers: _Finishers.core,
        ),
        TemplateDay(
          tag: 'MON',
          name: 'Shoulders',
          focus: 'Delts - Traps',
          warmups: _Warmups.push,
          exercises: [
            'Overhead Press',
            'Lateral Raise',
            'Rear Delt Fly',
            'Barbell Shrug',
          ],
          finishers: _Finishers.core,
        ),
        TemplateDay(
          tag: 'TUE',
          name: 'Legs',
          focus: 'Quads - Hams - Calves',
          warmups: _Warmups.legs,
          exercises: [
            'Back Squat',
            'Leg Press',
            'Lying Leg Curl',
            'Standing Calf Raise',
          ],
          finishers: _Finishers.lower,
        ),
        TemplateDay(
          tag: 'WED',
          name: 'Arms',
          focus: 'Biceps - Triceps',
          warmups: _Warmups.general,
          exercises: [
            'Barbell Curl',
            'Close-Grip Bench Press',
            'Hammer Curl',
            'Rope Triceps Pushdown',
          ],
          finishers: _Finishers.upper,
        ),
      ],
    ),
  ];
}
