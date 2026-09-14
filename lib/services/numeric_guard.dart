/// The one place a number arriving from a text field, a database column or a
/// restored backup is turned into something safe to compute with.
///
/// Three separate hazards converge here, and four screens had each re-derived
/// their own partial defence against them:
///
///  * `double.tryParse` accepts the literal strings `Infinity`, `-Infinity`
///    and `NaN`, and none of the app's numeric fields carry
///    `inputFormatters`, so a paste or a letters keyboard reaches the parse.
///  * SQLite's REAL/INTEGER affinity is advisory: `BackupService` writes
///    whatever a hand-edited JSON file holds straight into the column, so a
///    read back out is not guaranteed to be a `num` at all.
///  * `double.toInt()` throws `Unsupported operation: Infinity or NaN` on the
///    far side, out of a `build()` — which turns one bad value persisted
///    months ago into a red error screen on every launch.
///
/// Keeping the rules here rather than in each screen means the guard can be
/// audited in one read, and a new write site inherits it instead of
/// reinventing three quarters of it.
class NumericGuard {
  NumericGuard._();

  /// [value] when it is a usable number, `null` otherwise.
  ///
  /// "Usable" is non-null, finite, and — when [min] is given — at or above
  /// [min], strictly above it when [minExclusive]. That distinction is how a
  /// height rejects a stored `0` that would divide BMI by zero while a target
  /// weight keeps `0` as its legitimate "not set yet" value.
  static double? finite(
    double? value, {
    double? min,
    bool minExclusive = false,
  }) {
    if (value == null || !value.isFinite) return null;
    if (min != null && (minExclusive ? value <= min : value < min)) {
      return null;
    }
    return value;
  }

  /// [raw] parsed as a usable number, or `null`. Blank and unparseable text
  /// both mean `null`, as do `Infinity` and `NaN`. Same [min] rules as
  /// [finite].
  static double? parse(
    String raw, {
    double? min,
    bool minExclusive = false,
  }) =>
      finite(double.tryParse(raw.trim()), min: min, minExclusive: minExclusive);

  /// A kilogram figure that is safe to persist: [raw] when it parses to a
  /// finite, non-negative number, [fallback] (0 by default) otherwise.
  ///
  /// Zero is the value the app already uses for "no weight set", so falling
  /// back to it leaves the user with an obviously-unset field rather than a
  /// fabricated number — and it is what unparseable text already landed on
  /// before any of these guards existed.
  static double sanitiseKg(String raw, {double fallback = 0.0}) =>
      parse(raw, min: 0.0) ?? fallback;

  /// A number read back out of a database column or a decoded backup, where
  /// the stored value may be a `num`, a `String`, or something with no
  /// numeric meaning at all. `null` when no finite number can be read.
  ///
  /// This is the read-side counterpart to [sanitiseKg]: the write sites stop
  /// new poison getting in, this stops poison already on disk from throwing.
  static double? read(Object? value) {
    if (value is num) return finite(value.toDouble());
    if (value is bool) return value ? 1.0 : 0.0;
    if (value is String) return parse(value);
    return null;
  }
}
