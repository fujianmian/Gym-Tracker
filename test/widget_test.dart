import 'package:flutter_test/flutter_test.dart';
import 'package:gym_set_tracker/main.dart';

void main() {
  test('exercise keeps track of completed and remaining sets', () {
    const exercise = Exercise(id: 'squat', name: 'Squats', target: 4, done: 1);

    expect(exercise.left, 3);
    expect(exercise.copyWith(done: 4).left, 0);
  });

  test('body weight entries retain their calendar date and value', () {
    const entry = BodyWeightEntry(date: '2026-08-26', kilograms: 68.5);

    expect(entry.toJson(), {'date': '2026-08-26', 'kilograms': 68.5});
  });
}
