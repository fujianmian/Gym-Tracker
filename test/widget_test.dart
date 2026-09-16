import 'package:flutter_test/flutter_test.dart';
import 'package:gym_set_tracker/main.dart';

void main() {
  test('exercise keeps track of completed and remaining sets', () {
    const exercise = Exercise(id: 'squat', name: 'Squats', target: 4, done: 1);

    expect(exercise.left, 3);
    expect(exercise.copyWith(done: 4).left, 0);
  });

  test('exercise can mark a weight as per side', () {
    const exercise = Exercise(
      id: 'dumbbell-press',
      name: 'Dumbbell Press',
      target: 3,
      weight: '20',
      isPerSide: true,
    );

    expect(exercise.weightLabel, '20 kg / side');
  });

  test('workout exercises are ordered by completed sets, then recency', () {
    const exerciseA = Exercise(
      id: 'a',
      name: 'Exercise A',
      target: 4,
      done: 2,
      lastSetCompletedAt: 200,
    );
    const exerciseB = Exercise(
      id: 'b',
      name: 'Exercise B',
      target: 4,
      done: 3,
      lastSetCompletedAt: 100,
    );

    expect(orderExercisesForWorkout([exerciseA, exerciseB]).first.id, 'b');
    expect(
      orderExercisesForWorkout([
        exerciseA,
        exerciseB.copyWith(done: 2, lastSetCompletedAt: 100),
      ]).first.id,
      'a',
    );
  });

  test('a completed exercise moves below unfinished exercises', () {
    const completed = Exercise(
      id: 'completed',
      name: 'Completed exercise',
      target: 3,
      done: 3,
    );
    const unfinished = Exercise(
      id: 'unfinished',
      name: 'Unfinished exercise',
      target: 4,
      done: 2,
    );

    expect(
      orderExercisesForWorkout([completed, unfinished]).map((item) => item.id),
      ['unfinished', 'completed'],
    );
  });

  test('a new day clears every workout day exercise progress', () {
    const day = WorkoutDay(
      id: 'back',
      name: 'Back',
      exercises: [
        Exercise(
          id: 'row',
          name: 'Row',
          target: 4,
          done: 3,
          lastSetCompletedAt: 123,
        ),
      ],
    );

    final resetDay = resetWorkoutProgress(day);

    expect(resetDay.exercises.single.done, 0);
    expect(resetDay.exercises.single.lastSetCompletedAt, isNull);
  });

  test('body weight entries retain their calendar date and value', () {
    const entry = BodyWeightEntry(date: '2026-08-26', kilograms: 68.5);

    expect(entry.toJson(), {'date': '2026-08-26', 'kilograms': 68.5});
  });
}
