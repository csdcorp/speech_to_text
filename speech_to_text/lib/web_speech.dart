@JS()
library web_speech.js;

import 'dart:html';

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
  external void start();
  external void stop();
  external void abort();
  external set onresult(void Function(SpeechRecognitionEvent event) eventFunc);
  external set onspeechstart(domEventCallback eventFunc);
  external set onspeechend(domEventCallback eventFunc);
  external set onaudiostart(domEventCallback eventFunc);
  external set onaudioend(domEventCallback eventFunc);
  external set onstart(domEventCallback eventFunc);
  external set onend(domEventCallback eventFunc);
  external set onerror(void Function(SpeechRecognitionError event) eventFunc);
}
