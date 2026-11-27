/// OpenStreetMap-based vector styles served by OpenFreeMap (free, no API key).
/// https://openfreemap.org
class MapStyles {
  MapStyles._();

  static const String standard = 'https://tiles.openfreemap.org/styles/liberty';
  static const String light = 'https://tiles.openfreemap.org/styles/positron';
  static const String dark = 'https://tiles.openfreemap.org/styles/dark';

  static const List<String> all = [standard, light, dark];

  /// Maps a persisted value (possibly an old `mapbox://` URI) to a valid style.
  static String normalize(String? saved) =>
      all.contains(saved) ? saved! : standard;
}
