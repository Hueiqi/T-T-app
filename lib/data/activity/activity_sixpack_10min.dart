import 'activity_model.dart';

final ActivityRoutine workoutSixpack10Min = ActivityRoutine(
  id: 'sixpack_10min',
  title: '10 Min Sixpack (Advanced)',
  duration: '10 min',
  difficulty: 'Advanced',
  focus: 'Core (Deep)',
  equipment: 'No equipment',
  colorValue: 0xFFFF5722,
  icon: '💥',
  description: 'Target deep abdominals and obliques. No breaks – push through!',
  exercises: [
    Exercise(name: 'Star Crunches', reps: '30 sec'),
    Exercise(name: 'V-Ups', reps: '30 sec'),
    Exercise(name: 'Jackknives', reps: '30 sec'),
    Exercise(name: 'Hollow Body Hold', reps: '30 sec'),
    Exercise(name: 'Boat Pose Hold', reps: '30 sec'),
    Exercise(name: 'Leg Lifts with Criss-Cross', reps: '30 sec'),
    Exercise(name: 'Reverse Crunch with Leg Extension', reps: '30 sec'),
    Exercise(name: 'Plank Jacks', reps: '30 sec'),
    Exercise(name: 'Up-Down Planks (Commandos)', reps: '30 sec'),
    Exercise(name: 'Side Plank Dips (Left)', reps: '20 sec', sets: 2),
    Exercise(name: 'Side Plank Dips (Right)', reps: '20 sec', sets: 2),
    Exercise(name: 'Plank with Reach-Throughs', reps: '30 sec'),
  ],
);
