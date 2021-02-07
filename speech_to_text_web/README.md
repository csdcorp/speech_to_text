# speech_to_text_web

The web implementation of [`speech_to_text`][1].

## Usage

### Import the package
To use this plugin in your Flutter Web app, simply add it as a dependency in
your pubspec alongside the base `speech_to_text` plugin.

_(This is only temporary: in the future we hope to make this package an
"endorsed" implementation of `url_launcher`, so that it is automatically
included in your Flutter Web app when you depend on `package:speech_to_text`.)_

This is what the above means to your `pubspec.yaml`:

```yaml
...
dependencies:
  ...
  speech_to_text: ^3.1.0
  speech_to_text_web: ^0.1.0
  ...
```

### Use the plugin
Once you have the `speech_to_text_web` dependency in your pubspec, you should
be able to use `package:speech_to_text` as normal.

[1]: ../speech_to_text