import 'package:json_annotation/json_annotation.dart';

part 'speech_recognition_error.g.dart';

/// A single error returned from the underlying speech services.
///
/// Errors are either transient or permanent. Permanent errors
/// block speech recognition from continuing and must be
/// addressed before recognition will work. Transient errors
/// cause individual recognition sessions to fail but subsequent
/// attempts may well succeed.
@JsonSerializable()
class SpeechRecognitionError {
  /// Use this to differentiate the various error conditions.
  ///
  /// Not meant for display to the user.
  final String errorMsg;

  /// True means that recognition cannot continue until
  /// the error is resolved.
  final bool permanent;

  SpeechRecognitionError(this.errorMsg, this.permanent);

  factory SpeechRecognitionError.fromJson(Map<String, dynamic> json) =>
      _$SpeechRecognitionErrorFromJson(json);
  Map<String, dynamic> toJson() => _$SpeechRecognitionErrorToJson(this);

  @override
  String toString() {
    return 'SpeechRecognitionError msg: $errorMsg, permanent: $permanent';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SpeechRecognitionError &&
            errorMsg == other.errorMsg &&
            permanent == other.permanent;
  }

  @override
  int get hashCode => errorMsg.hashCode;
}
