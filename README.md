# speech_to_text

A library that exposes device specific speech recognition capability.

This plugin contains a set of classes that make it easy to use the speech recognition 
capabilities of the underlying platform in Flutter. It supports Android, iOS and web. The 
target use cases for this library are commands and short phrases, not continuous spoken
conversion or always on listening. 

## Contents

### [Plugin](https://github.com/csdcorp/speech_to_text/tree/main/speech_to_text)
This [project](https://github.com/csdcorp/speech_to_text/tree/main/speech_to_text) has the code for the plugin on 
multiple native platforms including iOS, Android and the web. 

### [Platform Interface](https://github.com/csdcorp/speech_to_text/tree/main/speech_to_text_platform_interface)
This [project](https://github.com/csdcorp/speech_to_text/tree/main/speech_to_text_platform_interface) defines 
the behaviour required on each host platform. To implement the plugin for a new platform the behaviour of this 
interface is implemented on that platform. See the docs 
[here](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#federated-plugins) for 
a description of the approach.

### [Example apps](https://github.com/csdcorp/speech_to_text/tree/main/speech_to_text/example/)
The main [example app](https://github.com/csdcorp/speech_to_text/tree/main/speech_to_text/example/lib/main.dart) included with the plugin shows basic use of the plugin. 

In addition there is a [`Provider` example](https://github.com/csdcorp/speech_to_text/tree/main/speech_to_text/example/lib/provider_example.dart) that shows how to use the plugin as a [Flutter Provider](https://docs.flutter.dev/development/data-and-backend/state-mgmt/simple). 

_These examples work only with the plugin source checked out because their dependency is on a relative path, not the pub.dev version._

