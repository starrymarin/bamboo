import 'dart:math';

const _availableChars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';

String randomKey() {
  return List.generate(
    5,
    (index) => _availableChars[Random().nextInt(_availableChars.length)],
  ).join();
}
