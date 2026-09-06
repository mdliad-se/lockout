import 'dart:convert';

// Routine Scheduling Mode
enum SchedulingMode { weekday, rotating }

// Routine Entity
class Routine {
  final String id;
  final String name;
  final SchedulingMode schedulingMode;
  final bool isActive;
  final String createdAt;

  Routine({
    required this.id,
    required this.name,
    required this.schedulingMode,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'scheduling_mode': schedulingMode.name.toUpperCase(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'],
      name: map['name'],
      schedulingMode: map['scheduling_mode'] == 'ROTATING' ? SchedulingMode.rotating : SchedulingMode.weekday,
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
    );
  }
}

// Training Day Entity
class TrainingDay {
  final String id;
  final String routineId;
  final String name;
  final String tag;
  final int orderIndex;
  final List<WarmupItem> warmups;
  final List<ExerciseDef> exercises;
  final List<FinisherItem> finishers;

  TrainingDay({
    required this.id,
    required this.routineId,
    required this.name,
    required this.tag,
    required this.orderIndex,
    this.warmups = const [],
    this.exercises = const [],
    this.finishers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'name': name,
      'tag': tag,
      'order_index': orderIndex,
    };
  }

  factory TrainingDay.fromMap(Map<String, dynamic> map) {
    return TrainingDay(
      id: map['id'],
      routineId: map['routine_id'],
      name: map['name'],
      tag: map['tag'],
      orderIndex: map['order_index'],
    );
  }
}

// Warmup Entry
class WarmupItem {
  final String id;
  final String dayId;
  final String name;
  final String amt; // e.g. "3-4 min" or "15 reps"

  WarmupItem({
    required this.id,
    required this.dayId,
    required this.name,
    required this.amt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day_id': dayId,
      'name': name,
      'amt': amt,
    };
  }

  factory WarmupItem.fromMap(Map<String, dynamic> map) {
    return WarmupItem(
      id: map['id'],
      dayId: map['day_id'],
      name: map['name'],
      amt: map['amt'],
    );
  }
}

// Exercise Definition
class ExerciseDef {
  final String id;
  final String dayId;
  final String name;
  final int targetSets;
  final int targetRepsMin;
  final int targetRepsMax;
  final double targetWeightKg;
  final int restDefaultS;
  final String note;
  final String videoUrl;

  ExerciseDef({
    required this.id,
    required this.dayId,
    required this.name,
    required this.targetSets,
    required this.targetRepsMin,
    required this.targetRepsMax,
    this.targetWeightKg = 0.0,
    this.restDefaultS = 60,
    this.note = '',
    this.videoUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day_id': dayId,
      'name': name,
      'target_sets': targetSets,
      'target_reps_min': targetRepsMin,
      'target_reps_max': targetRepsMax,
      'target_weight_kg': targetWeightKg,
      'rest_default_s': restDefaultS,
      'note': note,
      'video_url': videoUrl,
    };
  }

  factory ExerciseDef.fromMap(Map<String, dynamic> map) {
    return ExerciseDef(
      id: map['id'],
      dayId: map['day_id'],
      name: map['name'],
      targetSets: map['target_sets'],
      targetRepsMin: map['target_reps_min'],
      targetRepsMax: map['target_reps_max'],
      targetWeightKg: (map['target_weight_kg'] as num?)?.toDouble() ?? 0.0,
      restDefaultS: map['rest_default_s'] ?? 60,
      note: map['note'] ?? '',
      videoUrl: map['video_url'] ?? '',
    );
  }
}

// Finisher Entry
class FinisherItem {
  final String id;
  final String dayId;
  final String name;
  final String amt;

  FinisherItem({
    required this.id,
    required this.dayId,
    required this.name,
    required this.amt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day_id': dayId,
      'name': name,
      'amt': amt,
    };
  }

  factory FinisherItem.fromMap(Map<String, dynamic> map) {
    return FinisherItem(
      id: map['id'],
      dayId: map['day_id'],
      name: map['name'],
      amt: map['amt'],
    );
  }
}

// Completed Set Log
class SetLog {
  final String id;
  final String sessionExerciseId;
  final int setIndex;
  final double weightKg;
  final int reps;
  final bool isCompleted;

  SetLog({
    required this.id,
    required this.sessionExerciseId,
    required this.setIndex,
    required this.weightKg,
    required this.reps,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_exercise_id': sessionExerciseId,
      'set_index': setIndex,
      'weight_kg': weightKg,
      'reps': reps,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory SetLog.fromMap(Map<String, dynamic> map) {
    return SetLog(
      id: map['id'],
      sessionExerciseId: map['session_exercise_id'],
      setIndex: map['set_index'],
      weightKg: (map['weight_kg'] as num).toDouble(),
      reps: map['reps'],
      isCompleted: map['is_completed'] == 1,
    );
  }
}

// Workout Session Log
class SessionLog {
  final String id;
  final String dayName;
  final String dateStr;
  final int durationSeconds;
  final double totalVolumeKg;
  final String status; // 'completed', 'skipped', 'rescheduled'

  SessionLog({
    required this.id,
    required this.dayName,
    required this.dateStr,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day_name': dayName,
      'date_str': dateStr,
      'duration_seconds': durationSeconds,
      'total_volume_kg': totalVolumeKg,
      'status': status,
    };
  }

  factory SessionLog.fromMap(Map<String, dynamic> map) {
    return SessionLog(
      id: map['id'],
      dayName: map['day_name'],
      dateStr: map['date_str'],
      durationSeconds: map['duration_seconds'],
      totalVolumeKg: (map['total_volume_kg'] as num).toDouble(),
      status: map['status'],
    );
  }
}

// Food & Calorie Entry
class FoodEntry {
  final String id;
  final String dateStr;
  final String mealSlot; // 'Breakfast', 'Lunch', 'Dinner', 'Snacks'
  final String name;
  final int kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  FoodEntry({
    required this.id,
    required this.dateStr,
    required this.mealSlot,
    required this.name,
    required this.kcal,
    this.proteinG = 0.0,
    this.carbG = 0.0,
    this.fatG = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date_str': dateStr,
      'meal_slot': mealSlot,
      'name': name,
      'kcal': kcal,
      'protein_g': proteinG,
      'carb_g': carbG,
      'fat_g': fatG,
    };
  }

  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    return FoodEntry(
      id: map['id'],
      dateStr: map['date_str'],
      mealSlot: map['meal_slot'],
      name: map['name'],
      kcal: map['kcal'],
      proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbG: (map['carb_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (map['fat_g'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Body Weight & Measurement Entry
class BodyEntry {
  final String id;
  final String dateStr;
  final double weightKg;
  final double waistCm;

  BodyEntry({
    required this.id,
    required this.dateStr,
    required this.weightKg,
    this.waistCm = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date_str': dateStr,
      'weight_kg': weightKg,
      'waist_cm': waistCm,
    };
  }

  factory BodyEntry.fromMap(Map<String, dynamic> map) {
    return BodyEntry(
      id: map['id'],
      dateStr: map['date_str'],
      weightKg: (map['weight_kg'] as num).toDouble(),
      waistCm: (map['waist_cm'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
