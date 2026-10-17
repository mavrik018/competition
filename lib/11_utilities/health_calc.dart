/// Daily calorie and macro estimates, plus BMI.
///
/// Source: Cookly `features/calorie_tracker/application/calorie_calculator.dart`.
/// Kept: Mifflin-St Jeor BMR (the most widely used estimate needing only
/// weight, height, age and sex), standard activity multipliers, ±500 kcal
/// for a ~0.5 kg/week change, a 1,000 kcal floor, and goal-specific macro
/// splits. Changed: the source passed strings ('male', 'very_active',
/// 'lose'); enums make a typo a compile error. BMI is newly added.
///
/// These are estimates to pre-fill an editable field — not medical advice.
///
/// ```dart
/// final kcal = dailyCalorieTarget(weightKg: 70, heightCm: 175, age: 30,
///     sex: Sex.male, activity: ActivityLevel.moderate, goal: WeightGoal.lose);
/// final macros = macroTargets(kcal, WeightGoal.lose);
/// ```
library;

enum Sex { male, female }

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.multiplier);
  final double multiplier;
}

enum WeightGoal {
  lose(-500),
  maintain(0),
  gain(500);

  const WeightGoal(this.calorieAdjustment);
  final int calorieAdjustment;
}

/// Basal metabolic rate in kcal/day (Mifflin-St Jeor).
int basalMetabolicRate({
  required double weightKg,
  required double heightCm,
  required int age,
  required Sex sex,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return (sex == Sex.male ? base + 5 : base - 161).round();
}

/// BMR × activity, adjusted for the goal, never below 1,000 kcal.
int dailyCalorieTarget({
  required double weightKg,
  required double heightCm,
  required int age,
  required Sex sex,
  required ActivityLevel activity,
  WeightGoal goal = WeightGoal.maintain,
}) {
  final bmr = basalMetabolicRate(
    weightKg: weightKg,
    heightCm: heightCm,
    age: age,
    sex: sex,
  );
  final target = (bmr * activity.multiplier).round() + goal.calorieAdjustment;
  return target < 1000 ? 1000 : target;
}

/// Grams of protein / carbs / fat for [calories]. Protein and carbs are
/// 4 kcal/g, fat 9 kcal/g. Losing weight favours protein (35/35/30),
/// gaining favours carbs (25/50/25), maintaining is balanced (30/40/30).
({int proteinG, int carbsG, int fatG}) macroTargets(
  int calories, [
  WeightGoal goal = WeightGoal.maintain,
]) {
  final (protein, carbs, fat) = switch (goal) {
    WeightGoal.lose => (0.35, 0.35, 0.30),
    WeightGoal.gain => (0.25, 0.50, 0.25),
    WeightGoal.maintain => (0.30, 0.40, 0.30),
  };
  return (
    proteinG: (calories * protein / 4).round(),
    carbsG: (calories * carbs / 4).round(),
    fatG: (calories * fat / 9).round(),
  );
}

/// Body-mass index: kg / m².
double bmi({required double weightKg, required double heightCm}) {
  final metres = heightCm / 100;
  return weightKg / (metres * metres);
}

/// WHO adult categories.
String bmiCategory(double bmi) => switch (bmi) {
  < 18.5 => 'Underweight',
  < 25 => 'Healthy weight',
  < 30 => 'Overweight',
  _ => 'Obese',
};
