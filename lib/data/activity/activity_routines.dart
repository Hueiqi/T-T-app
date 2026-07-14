import 'activity_model.dart';

// ---------- 1. 10 Min Ab Workout ----------
final ActivityRoutine workoutAbs10Min = ActivityRoutine(
  id: 'abs_10min',
  title: '10 Min Ab Workout',
  duration: '10 min',
  difficulty: 'Intermediate',
  focus: 'Core',
  equipment: 'No equipment',
  colorValue: 0xFFE91E63,
  imageAsset: 'assets/images/Planning/abs.png',
  description: 'Fast-paced core burner with zero rest.',
  exercises: [
    Exercise(name: 'Crunches', reps: '30 sec', images: ['Crunches/0.jpg', 'Crunches/1.jpg']),
    Exercise(name: 'Air Bike', reps: '30 sec', images: ['Air_Bike/0.jpg', 'Air_Bike/1.jpg']),
    Exercise(name: 'Reverse Crunch', reps: '30 sec', images: ['Reverse_Crunch/0.jpg', 'Reverse_Crunch/1.jpg']),
    Exercise(name: 'Cross-Body Crunch', reps: '15 sec', images: ['Cross-Body_Crunch/0.jpg', 'Cross-Body_Crunch/1.jpg']), // used for both sides
    Exercise(name: 'Cross-Body Crunch', reps: '15 sec', images: ['Cross-Body_Crunch/0.jpg', 'Cross-Body_Crunch/1.jpg']),
    Exercise(name: 'Flat Bench Lying Leg Raise', reps: '30 sec', images: ['Flat_Bench_Lying_Leg_Raise/0.jpg', 'Flat_Bench_Lying_Leg_Raise/1.jpg']),
    Exercise(name: 'Scissor Kick', reps: '30 sec', images: ['Scissor_Kick/0.jpg', 'Scissor_Kick/1.jpg']),
    Exercise(name: 'Flutter Kicks', reps: '30 sec', images: ['Flutter_Kicks/0.jpg', 'Flutter_Kicks/1.jpg']),
    Exercise(name: 'Russian Twist', reps: '30 sec', images: ['Russian_Twist/0.jpg', 'Russian_Twist/1.jpg']),
    Exercise(name: 'Alternate Heel Touchers', reps: '30 sec', images: ['Alternate_Heel_Touchers/0.jpg', 'Alternate_Heel_Touchers/1.jpg']),
    Exercise(name: 'Toe Touchers', reps: '30 sec', images: ['Toe_Touchers/0.jpg', 'Toe_Touchers/1.jpg']),
    Exercise(name: 'Plank', reps: '30 sec', images: ['Plank/0.jpg', 'Plank/1.jpg']),
    Exercise(name: 'Mountain Climbers', reps: '30 sec', images: ['Mountain_Climbers/0.jpg', 'Mountain_Climbers/1.jpg']),
    Exercise(name: 'Spider Crawl', reps: '30 sec', images: ['Spider_Crawl/0.jpg', 'Spider_Crawl/1.jpg']),
  ],
);

// ---------- 2. Beginner Abs (10 min) ----------
final ActivityRoutine workoutBeginnerAbs10Min = ActivityRoutine(
  id: 'beginner_abs_10min',
  title: 'Beginner Abs',
  duration: '10 min',
  difficulty: 'Beginner',
  focus: 'Core',
  equipment: 'No equipment',
  colorValue: 0xFF4CAF50,
  imageAsset: 'assets/images/Planning/10min_abs.png',
  description: 'Gentle core activation for beginners.',
  exercises: [
    Exercise(name: 'Crunches', reps: '30 sec', images: ['Crunches/0.jpg', 'Crunches/1.jpg']),
    Exercise(name: 'Air Bike', reps: '30 sec', images: ['Air_Bike/0.jpg', 'Air_Bike/1.jpg']),
    Exercise(name: 'Reverse Crunch', reps: '30 sec', images: ['Reverse_Crunch/0.jpg', 'Reverse_Crunch/1.jpg']),
    Exercise(name: 'Plank', reps: '30 sec', images: ['Plank/0.jpg', 'Plank/1.jpg']),
    Exercise(name: 'Flat Bench Lying Leg Raise', reps: '30 sec', images: ['Flat_Bench_Lying_Leg_Raise/0.jpg', 'Flat_Bench_Lying_Leg_Raise/1.jpg']),
    Exercise(name: 'Russian Twist', reps: '30 sec', images: ['Russian_Twist/0.jpg', 'Russian_Twist/1.jpg']),
    Exercise(name: 'Alternate Heel Touchers', reps: '30 sec', images: ['Alternate_Heel_Touchers/0.jpg', 'Alternate_Heel_Touchers/1.jpg']),
    Exercise(name: 'Toe Touchers', reps: '30 sec', images: ['Toe_Touchers/0.jpg', 'Toe_Touchers/1.jpg']),
    Exercise(name: 'Flutter Kicks', reps: '30 sec', images: ['Flutter_Kicks/0.jpg', 'Flutter_Kicks/1.jpg']),
    Exercise(name: 'Mountain Climbers', reps: '30 sec', images: ['Mountain_Climbers/0.jpg', 'Mountain_Climbers/1.jpg']),
  ],
);

// ---------- 3. Full Body Beginner (20 min) ----------
final ActivityRoutine workoutFullBody20MinBeginner = ActivityRoutine(
  id: 'fullbody_20min_beginner',
  title: '20 Min Full Body (Beginner)',
  duration: '20 min',
  difficulty: 'Beginner',
  focus: 'Total Body',
  equipment: 'No equipment',
  colorValue: 0xFF2196F3,
  imageAsset: 'assets/images/Planning/20minFullBody.png',
  description: 'Slow-paced routine with no jumping.',
  exercises: [
    Exercise(name: 'Arm Circles', reps: '30 sec', images: ['Arm_Circles/0.jpg', 'Arm_Circles/1.jpg']),
    Exercise(name: 'Torso Rotation', reps: '30 sec', images: ['Torso_Rotation/0.jpg', 'Torso_Rotation/1.jpg']),
    Exercise(name: 'Upward Stretch', reps: '30 sec', images: ['Upward_Stretch/0.jpg', 'Upward_Stretch/1.jpg']),
    Exercise(name: 'Bodyweight Squat', reps: '45 sec', sets: 3, images: ['Bodyweight_Squat/0.jpg', 'Bodyweight_Squat/1.jpg']),
    Exercise(name: 'Dumbbell Rear Lunge', reps: '45 sec', sets: 3, images: ['Dumbbell_Rear_Lunge/0.jpg', 'Dumbbell_Rear_Lunge/1.jpg']),
    Exercise(name: 'Butt Lift (Bridge)', reps: '45 sec', sets: 3, images: ['Butt_Lift_Bridge/0.jpg', 'Butt_Lift_Bridge/1.jpg']),
    Exercise(name: 'Side Leg Raises', reps: '30 sec', sets: 2, images: ['Side_Leg_Raises/0.jpg', 'Side_Leg_Raises/1.jpg']),
    Exercise(name: 'Side Leg Raises', reps: '30 sec', sets: 2, images: ['Side_Leg_Raises/0.jpg', 'Side_Leg_Raises/1.jpg']),
    Exercise(name: 'Pushups', reps: '45 sec', sets: 3, images: ['Pushups/0.jpg', 'Pushups/1.jpg']),
    Exercise(name: 'Bench Dips', reps: '45 sec', sets: 3, images: ['Bench_Dips/0.jpg', 'Bench_Dips/1.jpg']),
    Exercise(name: 'Plank', reps: '45 sec', sets: 2, images: ['Plank/0.jpg', 'Plank/1.jpg']),
    Exercise(name: 'Superman', reps: '45 sec', sets: 2, images: ['Superman/0.jpg', 'Superman/1.jpg']),
    Exercise(name: 'All Fours Quad Stretch', reps: '45 sec', sets: 2, images: ['All_Fours_Quad_Stretch/0.jpg', 'All_Fours_Quad_Stretch/1.jpg']),
    Exercise(name: 'Mountain Climbers', reps: '45 sec', sets: 2, images: ['Mountain_Climbers/0.jpg', 'Mountain_Climbers/1.jpg']),
    Exercise(name: 'Plank', reps: '45 sec', sets: 2, images: ['Plank/0.jpg', 'Plank/1.jpg']),
    Exercise(name: 'Crunches', reps: '45 sec', sets: 2, images: ['Crunches/0.jpg', 'Crunches/1.jpg']),
    Exercise(name: "Child's Pose", reps: '30 sec', images: ['Childs_Pose/0.jpg', 'Childs_Pose/1.jpg']),
    Exercise(name: 'Cat Stretch', reps: '30 sec', images: ['Cat_Stretch/0.jpg', 'Cat_Stretch/1.jpg']),
    Exercise(name: 'Hamstring Stretch', reps: '30 sec', images: ['Hamstring_Stretch/0.jpg', 'Hamstring_Stretch/1.jpg']),
  ],
);

// ---------- 4. Six Pack (10 min) ----------
// ─── 4. Core Stability (10 min) ──────────────────────────────
final ActivityRoutine workoutCoreStability10Min = ActivityRoutine(
  id: 'core_stability_10min',
  title: 'Core Stability 10 Min',
  duration: '10 min',
  difficulty: 'Intermediate',
  focus: 'Core',
  equipment: 'No equipment',
  colorValue: 0xFFFF9800,
  imageAsset: 'assets/images/Planning/coreStability.jpg',
  description: 'Build deep core strength and control with slow, controlled moves.',
  exercises: [
    Exercise(name: 'Plank', reps: '45 sec', images: ['Plank/0.jpg', 'Plank/1.jpg']),
    Exercise(name: 'Side Bridge', reps: '30 sec', images: ['Side_Bridge/0.jpg', 'Side_Bridge/1.jpg']),
    Exercise(name: 'Side Bridge', reps: '30 sec', images: ['Side_Bridge/0.jpg', 'Side_Bridge/1.jpg']),
    Exercise(name: 'Bird-Dog (Alternating)', reps: '30 sec', images: ['All_Fours_Quad_Stretch/0.jpg', 'All_Fours_Quad_Stretch/1.jpg']),
    Exercise(name: 'Bird-Dog (Alternating)', reps: '30 sec', images: ['All_Fours_Quad_Stretch/0.jpg', 'All_Fours_Quad_Stretch/1.jpg']),
    Exercise(name: 'Dead Bug', reps: '30 sec', images: ['Dead_Bug/0.jpg', 'Dead_Bug/1.jpg']),
    Exercise(name: 'Dead Bug', reps: '30 sec', images: ['Dead_Bug/0.jpg', 'Dead_Bug/1.jpg']),
    Exercise(name: 'Superman', reps: '30 sec', images: ['Superman/0.jpg', 'Superman/1.jpg']),
    Exercise(name: 'Mountain Climbers', reps: '30 sec', images: ['Mountain_Climbers/0.jpg', 'Mountain_Climbers/1.jpg']),
    Exercise(name: 'Flutter Kicks', reps: '30 sec', images: ['Flutter_Kicks/0.jpg', 'Flutter_Kicks/1.jpg']),
    Exercise(name: 'Russian Twist', reps: '30 sec', images: ['Russian_Twist/0.jpg', 'Russian_Twist/1.jpg']),
    Exercise(name: 'Toe Touchers', reps: '30 sec', images: ['Toe_Touchers/0.jpg', 'Toe_Touchers/1.jpg']),
    Exercise(name: 'Plank', reps: '30 sec', images: ['Plank/0.jpg', 'Plank/1.jpg']),
  ],
);

// ---------- 5. Full Body Intense (20 min) ----------
final ActivityRoutine workoutFullBody20MinIntense = ActivityRoutine(
  id: 'fullbody_20min_intense',
  title: 'Full Body Intense',
  duration: '20 min',
  difficulty: 'Advanced',
  focus: 'Full Body',
  equipment: 'Dumbbells + Bodyweight',
  colorValue: 0xFF9C27B0,
  imageAsset: 'assets/images/Planning/FullBodyWorkout.png',
  description: 'High‑intensity compound movements.',
  exercises: [
    Exercise(name: 'Bodyweight Squat', reps: '45 sec', sets: 3, images: ['Bodyweight_Squat/0.jpg', 'Bodyweight_Squat/1.jpg']),
    Exercise(name: 'Dumbbell Rear Lunge', reps: '45 sec', sets: 3, images: ['Dumbbell_Rear_Lunge/0.jpg', 'Dumbbell_Rear_Lunge/1.jpg']),
    Exercise(name: 'Pushups', reps: '45 sec', sets: 3, images: ['Pushups/0.jpg', 'Pushups/1.jpg']),
    Exercise(name: 'Bench Dips', reps: '45 sec', sets: 3, images: ['Bench_Dips/0.jpg', 'Bench_Dips/1.jpg']),
    Exercise(name: 'Plank', reps: '45 sec', sets: 3, images: ['Plank/0.jpg', 'Plank/1.jpg']),
    Exercise(name: 'Superman', reps: '45 sec', sets: 2, images: ['Superman/0.jpg', 'Superman/1.jpg']),
    Exercise(name: 'Mountain Climbers', reps: '45 sec', sets: 3, images: ['Mountain_Climbers/0.jpg', 'Mountain_Climbers/1.jpg']),
    Exercise(name: 'Crunches', reps: '45 sec', sets: 3, images: ['Crunches/0.jpg', 'Crunches/1.jpg']),
    Exercise(name: 'Russian Twist', reps: '45 sec', sets: 2, images: ['Russian_Twist/0.jpg', 'Russian_Twist/1.jpg']),
    Exercise(name: 'Flutter Kicks', reps: '45 sec', sets: 2, images: ['Flutter_Kicks/0.jpg', 'Flutter_Kicks/1.jpg']),
    Exercise(name: 'Butt Lift (Bridge)', reps: '45 sec', sets: 2, images: ['Butt_Lift_Bridge/0.jpg', 'Butt_Lift_Bridge/1.jpg']),
    Exercise(name: 'Side Leg Raises', reps: '45 sec', sets: 2, images: ['Side_Leg_Raises/0.jpg', 'Side_Leg_Raises/1.jpg']),
    Exercise(name: 'Spider Crawl', reps: '45 sec', sets: 2, images: ['Spider_Crawl/0.jpg', 'Spider_Crawl/1.jpg']),
    Exercise(name: 'Arm Circles', reps: '45 sec', images: ['Arm_Circles/0.jpg', 'Arm_Circles/1.jpg']),
  ],
);

// ---------- Export all routines ----------
final List<ActivityRoutine> allRoutines = [
  workoutAbs10Min,
  workoutBeginnerAbs10Min,
  workoutFullBody20MinBeginner,
  workoutCoreStability10Min,
  workoutFullBody20MinIntense,
];