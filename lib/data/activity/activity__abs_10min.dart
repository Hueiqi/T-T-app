import 'activity_model.dart';

final ActivityRoutine workoutAbs10Min = ActivityRoutine(
  id: 'abs_10min',
  title: '10 Min Ab Workout',
  duration: '10 min',
  difficulty: 'Intermediate',
  focus: 'Core',
  equipment: 'No equipment',
  colorValue: 0xFFE91E63,
  icon: '🔥',
  description:
      'Fast-paced core burner with zero rest. Transition immediately from one move to the next.',
  exercises: [
    Exercise(name: 'Basic Crunches', reps: '30 sec'),
    Exercise(name: 'Bicycle Crunches', reps: '30 sec'),
    Exercise(name: 'Reverse Crunches', reps: '30 sec'),
    Exercise(name: 'Cross Crunches (Left)', reps: '15 sec'),
    Exercise(name: 'Cross Crunches (Right)', reps: '15 sec'),
    Exercise(name: 'Leg Raises', reps: '30 sec'),
    Exercise(name: 'Scissor Kicks', reps: '30 sec'),
    Exercise(name: 'Flutter Kicks', reps: '30 sec'),
    Exercise(name: 'Russian Twists', reps: '30 sec'),
    Exercise(name: 'Heel Taps (Penguin Crunches)', reps: '30 sec'),
    Exercise(name: 'Toe Reaches', reps: '30 sec'),
    Exercise(name: 'Forearm Plank', reps: '30 sec'),
    Exercise(name: 'Mountain Climbers', reps: '30 sec'),
    Exercise(name: 'Spider Planks (knee to elbow)', reps: '30 sec'),
  ],
);
