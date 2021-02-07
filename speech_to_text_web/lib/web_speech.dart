@JS()
library web_speech.js;

import 'package:js/js.dart';

typedef domEventCallback = void Function(Event event);
typedef emptyCallback = void Function();

@JS()
class SpeechRecognition {
  external factory SpeechRecognition();
  external String get lang;
  external set lang(String isoLang);
  external set interimResults(bool interim);
  external set continuous(bool interim);
  external start();
  external stop();
  external abort();
  external set onresult(void Function(SpeechRecognitionEvent event) eventFunc);
  external set onspeechstart(domEventCallback eventFunc);
  external set onspeechend(domEventCallback eventFunc);
  external set onaudiostart(domEventCallback eventFunc);
  external set onaudioend(domEventCallback eventFunc);
  external set onstart(domEventCallback eventFunc);
  external set onend(domEventCallback eventFunc);
  external set onerror(void Function(SpeechRecognitionError event) eventFunc);
}

@JS()
class Event {
  external String get type;
}

@JS()
class SpeechRecognitionError {
  external String get error;
  external String get message;
}

@JS()
class SpeechRecognitionEvent {
  external int get resultIndex;
  external SpeechRecognitionResultList get results;
}

@JS()
class SpeechRecognitionResultList {
  external int get length;
  external SpeechRecognitionResult item(int index);
}

@JS()
class SpeechRecognitionResult {
  external bool get isFinal;
  external int get length;
  external SpeechRecognitionAlternative item(int index);
}

@JS()
class SpeechRecognitionAlternative {
  external String get transcript;
  external double get confidence;
}
