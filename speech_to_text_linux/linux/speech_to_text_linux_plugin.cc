#include "include/speech_to_text_linux/speech_to_text_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <pulse/error.h>
#include <pulse/simple.h>
#include <vosk_api.h>

#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>

// method names exchanged with the Dart side.
static constexpr char kChannelName[] = "speech_to_text_linux";
static constexpr char kTextRecognition[] = "textRecognition";
static constexpr char kNotifyError[] = "notifyError";
static constexpr char kNotifyStatus[] = "notifyStatus";
static constexpr char kSoundLevelChange[] = "soundLevelChange";

// status strings
static constexpr char kStatusListening[] = "listening";
static constexpr char kStatusNotListening[] = "notListening";
static constexpr char kStatusDone[] = "done";
static constexpr char kStatusDoneNoResult[] = "doneNoResult";

// resulttype values for textRecognition payloads
static constexpr int kResultTypePartial = 0;
static constexpr int kResultTypeFinal = 2;

// vosk requires 16 kHz mono signed 16-bit little-endian PCM.
static constexpr double kSampleRate = 16000.0;
// 100 ms of audio per read (16000 * 2 bytes * 0.1s).
static constexpr size_t kReadBytes = 3200;

// escapes utf-8 text for inclusion in a JSON string
static std::string JsonEscape(const std::string& in) {
  std::string out;
  out.reserve(in.size() + 8);
  for (char c : in) {
    switch (c) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        if (static_cast<unsigned char>(c) < 0x20) {
          char buf[8];
          snprintf(buf, sizeof(buf), "\\u%04x", c);
          out += buf;
        } else {
          out += c;
        }
    }
  }
  return out;
}

// extracts raw string from a JSON object
static std::string ExtractRawString(const std::string& json,
                                    const std::string& key) {
  const std::string needle = "\"" + key + "\"";
  size_t k = json.find(needle);
  if (k == std::string::npos) return "";
  size_t colon = json.find(':', k + needle.size());
  if (colon == std::string::npos) return "";
  size_t quote = json.find('"', colon);
  if (quote == std::string::npos) return "";
  std::string out;
  for (size_t i = quote + 1; i < json.size(); ++i) {
    char c = json[i];
    if (c == '\\') {
      out.push_back(c);
      if (i + 1 < json.size()) {
        out.push_back(json[i + 1]);
        ++i;
      }
      continue;
    }
    if (c == '"') break;
    out.push_back(c);
  }
  return out;
}

// builds the textRecognition payload
static std::string BuildResultJson(const std::string& raw_words, bool is_final) {
  std::string json = "{\"alternates\":[{\"recognizedWords\":\"";
  json += raw_words;
  json += "\",\"confidence\":1.0}],\"resultType\":";
  json += (is_final ? std::to_string(kResultTypeFinal)
                    : std::to_string(kResultTypePartial));
  json += "}";
  return json;
}


namespace {
struct InvokeData {
  FlMethodChannel* channel;
  gchar* method;
  FlValue* args;
};

// run on GTK main thread
gboolean InvokeOnMain(gpointer user_data) {
  auto* d = static_cast<InvokeData*>(user_data);
  fl_method_channel_invoke_method(d->channel, d->method, d->args, nullptr,
                                  nullptr, nullptr);
  g_object_unref(d->channel);
  g_free(d->method);
  fl_value_unref(d->args);
  delete d;
  return G_SOURCE_REMOVE;
}

// posts a method call to GTK main thread
void PostInvoke(FlMethodChannel* channel, const char* method, FlValue* args) {
  if (channel == nullptr) {
    fl_value_unref(args);
    return;
  }
  auto* d = new InvokeData{FL_METHOD_CHANNEL(g_object_ref(channel)),
                           g_strdup(method), args};
  g_idle_add(InvokeOnMain, d);
}
}  // namespace

// recognition engine via a background thread
class SttEngine {
 public:
  explicit SttEngine(FlMethodChannel* channel) : channel_(channel) {}

  ~SttEngine() {
    StopThread(false);
    if (model_ != nullptr) {
      vosk_model_free(model_);
      model_ = nullptr;
    }
  }

  bool Initialize(const std::string& model_path, bool debug_logging) {
    vosk_set_log_level(debug_logging ? 0 : -1);
    if (model_path.empty()) {
      EmitError("A Vosk model path must be supplied via the 'modelPath' option",
                true);
      return false;
    }
    if (model_ != nullptr) {
      vosk_model_free(model_);
      model_ = nullptr;
    }
    model_ = vosk_model_new(model_path.c_str());
    if (model_ == nullptr) {
      EmitError("Failed to load Vosk model at: " + model_path, true);
      return false;
    }
    return true;
  }

  bool Listen(bool partial_results) {
    if (model_ == nullptr) {
      EmitError("Speech recognition is not initialized", true);
      return false;
    }
    if (listening_.load()) {
      return false;
    }
    partial_results_ = partial_results;
    listening_.store(true);
    want_final_.store(true);
    worker_ = std::thread(&SttEngine::Run, this);
    return true;
  }

  void Stop() { StopThread(true); }
  void Cancel() { StopThread(false); }

  std::string locale() const { return locale_; }

 private:
  void StopThread(bool emit_final) {
    want_final_.store(emit_final);
    listening_.store(false);
    if (worker_.joinable()) {
      worker_.join();
    }
  }

  void EmitText(const std::string& json) {
    PostInvoke(channel_, kTextRecognition, fl_value_new_string(json.c_str()));
  }

  void EmitStatus(const char* status) {
    PostInvoke(channel_, kNotifyStatus, fl_value_new_string(status));
  }

  void EmitError(const std::string& message, bool permanent) {
    std::string json = "{\"errorMsg\":\"" + JsonEscape(message) +
                       "\",\"permanent\":" + (permanent ? "true" : "false") +
                       "}";
    PostInvoke(channel_, kNotifyError, fl_value_new_string(json.c_str()));
  }

  void EmitSoundLevel(double level) {
    PostInvoke(channel_, kSoundLevelChange, fl_value_new_float(level));
  }

  // applies a space between fragments
  static void Append(std::string* acc, const std::string& fragment) {
    if (fragment.empty()) return;
    if (!acc->empty()) acc->push_back(' ');
    *acc += fragment;
  }

  // bg thread. captures audio and feeds vosk & streams partial results
  void Run() {
    VoskRecognizer* recognizer = vosk_recognizer_new(model_, kSampleRate);
    if (recognizer == nullptr) {
      EmitError("Failed to create Vosk recognizer", true);
      EmitStatus(kStatusNotListening);
      EmitStatus(kStatusDoneNoResult);
      return;
    }
    vosk_recognizer_set_words(recognizer, 1);

    pa_sample_spec spec;
    spec.format = PA_SAMPLE_S16LE;
    spec.rate = static_cast<uint32_t>(kSampleRate);
    spec.channels = 1;

    int error = 0;
    pa_simple* stream =
        pa_simple_new(nullptr, "speech_to_text", PA_STREAM_RECORD, nullptr,
                      "recognition", &spec, nullptr, nullptr, &error);
    if (stream == nullptr) {
      EmitError(std::string("Unable to open microphone: ") + pa_strerror(error),
                true);
      EmitStatus(kStatusNotListening);
      EmitStatus(kStatusDoneNoResult);
      vosk_recognizer_free(recognizer);
      return;
    }

    EmitStatus(kStatusListening);

    std::string accumulated;
    std::string last_emitted;
    bool produced_result = false;
    uint8_t buffer[kReadBytes];

    while (listening_.load()) {
      if (pa_simple_read(stream, buffer, sizeof(buffer), &error) < 0) {
        EmitError(std::string("Microphone read failed: ") + pa_strerror(error),
                  true);
        break;
      }

      EmitSoundLevel(ComputeDecibels(buffer, sizeof(buffer)));

      int end_of_utterance = vosk_recognizer_accept_waveform(
          recognizer, reinterpret_cast<const char*>(buffer), sizeof(buffer));

      if (end_of_utterance) {
        std::string text =
            ExtractRawString(vosk_recognizer_result(recognizer), "text");
        Append(&accumulated, text);
      }

      if (partial_results_) {
        std::string current = accumulated;
        if (!end_of_utterance) {
          std::string partial = ExtractRawString(
              vosk_recognizer_partial_result(recognizer), "partial");
          Append(&current, partial);
        }
        if (!current.empty() && current != last_emitted) {
          last_emitted = current;
          produced_result = true;
          EmitText(BuildResultJson(current, false));
        }
      }
    }

    // drain buffer and emit final result
    std::string tail =
        ExtractRawString(vosk_recognizer_final_result(recognizer), "text");
    Append(&accumulated, tail);

    pa_simple_free(stream);
    vosk_recognizer_free(recognizer);

    if (want_final_.load() && !accumulated.empty()) {
      EmitText(BuildResultJson(accumulated, true));
      produced_result = true;
    }

    EmitStatus(kStatusNotListening);
    EmitStatus((want_final_.load() && produced_result) ? kStatusDone
                                                       : kStatusDoneNoResult);
  }

  // computes the RMS decibel level of a buffer of signed 16-bit PCM samples
  static double ComputeDecibels(const uint8_t* buffer, size_t bytes) {
    const int16_t* samples = reinterpret_cast<const int16_t*>(buffer);
    size_t count = bytes / sizeof(int16_t);
    if (count == 0) return -160.0;
    double sum_squares = 0.0;
    for (size_t i = 0; i < count; ++i) {
      double sample = static_cast<double>(samples[i]);
      sum_squares += sample * sample;
    }
    double rms = std::sqrt(sum_squares / static_cast<double>(count));
    if (rms <= 0.0) return -160.0;
    return 20.0 * std::log10(rms / 32768.0);
  }

  FlMethodChannel* channel_ = nullptr;
  VoskModel* model_ = nullptr;
  std::string locale_ = "en_US";
  std::atomic<bool> listening_{false};
  std::atomic<bool> want_final_{true};
  bool partial_results_ = true;
  std::thread worker_;
};

// gobject plugin wrapper for the recognition engine
struct _SpeechToTextLinuxPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
  SttEngine* engine;
};

#define SPEECH_TO_TEXT_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), speech_to_text_linux_plugin_get_type(), \
                              SpeechToTextLinuxPlugin))

G_DEFINE_TYPE(SpeechToTextLinuxPlugin, speech_to_text_linux_plugin,
              g_object_get_type())

static gboolean GetBool(FlValue* args, const char* key, gboolean fallback) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL) {
    return fl_value_get_bool(value);
  }
  return fallback;
}

static std::string GetString(FlValue* args, const char* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return "";
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
    return fl_value_get_string(value);
  }
  return "";
}

// handles when dart calls a method via plugin channel e.g "listen", "stop", etc.
static void HandleMethodCall(SpeechToTextLinuxPlugin* self,
                             FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "hasPermission") == 0) {
    // microphone access is unrestricted in a normal desktop session.
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "initialize") == 0) {
    bool ok = self->engine->Initialize(GetString(args, "modelPath"),
                                       GetBool(args, "debugLogging", FALSE));
    g_autoptr(FlValue) result = fl_value_new_bool(ok);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "listen") == 0) {
    bool ok = self->engine->Listen(GetBool(args, "partialResults", TRUE));
    g_autoptr(FlValue) result = fl_value_new_bool(ok);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "stop") == 0) {
    self->engine->Stop();
    g_autoptr(FlValue) result = fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "cancel") == 0) {
    self->engine->Cancel();
    g_autoptr(FlValue) result = fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "locales") == 0) {
    // vosk does not support multi-locale, so we just use en_US
    g_autoptr(FlValue) result = fl_value_new_list();
    std::string entry = self->engine->locale() + ":English (United States)";
    fl_value_append_take(result, fl_value_new_string(entry.c_str()));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send method call response: %s", error->message);
  }
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  SpeechToTextLinuxPlugin* self = SPEECH_TO_TEXT_LINUX_PLUGIN(user_data);
  HandleMethodCall(self, method_call);
}

// handle plugin disposal & clean up
static void speech_to_text_linux_plugin_dispose(GObject* object) {
  SpeechToTextLinuxPlugin* self = SPEECH_TO_TEXT_LINUX_PLUGIN(object);
  if (self->engine != nullptr) {
    delete self->engine;
    self->engine = nullptr;
  }
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(speech_to_text_linux_plugin_parent_class)->dispose(object);
}

static void speech_to_text_linux_plugin_class_init(
    SpeechToTextLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = speech_to_text_linux_plugin_dispose;
}

static void speech_to_text_linux_plugin_init(SpeechToTextLinuxPlugin* self) {
  self->channel = nullptr;
  self->engine = nullptr;
}

void speech_to_text_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  SpeechToTextLinuxPlugin* plugin = SPEECH_TO_TEXT_LINUX_PLUGIN(
      g_object_new(speech_to_text_linux_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));
  plugin->engine = new SttEngine(plugin->channel);

  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin),
      g_object_unref);

  g_object_unref(plugin);
}
