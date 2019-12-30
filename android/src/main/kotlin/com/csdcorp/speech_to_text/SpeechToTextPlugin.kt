package com.csdcorp.speech_to_text

import android.Manifest
import android.annotation.TargetApi
import android.app.Activity
import android.app.Application
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.SpeechRecognizer.createSpeechRecognizer
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import org.json.JSONObject
import android.content.Context
import android.content.BroadcastReceiver
import java.util.*


enum class SpeechToTextErrors {
  multipleRequests,
  unimplemented,
}

enum class SpeechToTextCallbackMethods {
  textRecognition,
  notifyStatus,
  notifyError,
}

enum class SpeechToTextStatus {
  listening,
  notListening,
  unavailable,
  available,
}

@TargetApi(8)
class SpeechToTextPlugin(activity: Activity, channel: MethodChannel ):
        MethodCallHandler, RecognitionListener, PluginRegistry.RequestPermissionsResultListener {
  private val pluginActivity: Activity = activity
  private val channel: MethodChannel = channel
  private val application: Application = activity.application
  private val minSdkForSpeechSupport = 21
  private val speechToTextPermissionCode = 78521
  private var activeResult: Result? = null
  private var initializedSuccessfully: Boolean = false
  private var permissionToRecordAudio: Boolean = false
  private var speechRecognizer: SpeechRecognizer? = null
  private var recognizerIntent: Intent? = null
  private var previousRecognizerLang: String? = null
  private val defaultLanguageTag: String = Locale.getDefault().toLanguageTag()

  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "plugin.csdcorp.com/speech_to_text")
      val speechPlugin = SpeechToTextPlugin( registrar.activity(), channel )
      channel.setMethodCallHandler(speechPlugin)
      registrar.addRequestPermissionsResultListener(speechPlugin)
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" ->  initialize( result )
      "listen" -> {
        if (null != call.arguments && call.arguments is String) {
          val localeId = call.arguments as String
          startListening( result, localeId )
        } else {
          startListening( result, defaultLanguageTag )
        }
      }
      "stop" -> stopListening( result )
      "cancel" ->  cancelListening( result )
      "locales" -> locales( result )
      else -> result.notImplemented()
    }
  }

  private fun initialize(result: Result) {
    if ( sdkVersionTooLow( result )) {
      return
    }
    if ( null != activeResult ) {
      result.error(SpeechToTextErrors.multipleRequests.name,
              "Only one initialize at a time", null )
      return
    }
    activeResult = result
    initializeIfPermitted( application )
   }

  private fun sdkVersionTooLow(result: Result): Boolean {
    if ( Build.VERSION.SDK_INT < minSdkForSpeechSupport ) {
      result.success(false)
      return true;
    }
    return false;
  }

  private fun isNotInitialized(result: Result): Boolean {
    if ( !initializedSuccessfully ) {
      result.success(false)
    }
    return !initializedSuccessfully
  }

  private fun startListening(result: Result, languageTag: String ) {
    if ( sdkVersionTooLow( result ) || isNotInitialized( result )) {
      return
    }
    setupRecognizerIntent(languageTag)
    speechRecognizer?.startListening(recognizerIntent)
    notifyListening(isRecording = true)
    result.success(true)
  }

  private fun stopListening(result: Result) {
    if ( sdkVersionTooLow( result ) || isNotInitialized( result )) {
      return
    }
    speechRecognizer?.stopListening()
    notifyListening(isRecording = false)
    result.success(true)
  }

  private fun cancelListening(result: Result) {
    if ( sdkVersionTooLow( result ) || isNotInitialized( result )) {
      return
    }
    speechRecognizer?.cancel()
    notifyListening(isRecording = false)
    result.success(true)
  }

  private fun locales(result: Result) {
    if ( sdkVersionTooLow( result ) || isNotInitialized( result )) {
      return
    }
    val detailsIntent = RecognizerIntent.getVoiceDetailsIntent(pluginActivity)
//    val detailsIntent = Intent(RecognizerIntent.ACTION_GET_LANGUAGE_DETAILS)
    pluginActivity.sendOrderedBroadcast(
            detailsIntent, null, LanguageDetailsChecker( result, pluginActivity ),
            null, Activity.RESULT_OK, null, null)
  }

  private fun notifyListening(isRecording: Boolean) {
    val status = when (isRecording) {
      true -> SpeechToTextStatus.listening.name
      false -> SpeechToTextStatus.notListening.name
    }
    channel.invokeMethod( SpeechToTextCallbackMethods.notifyStatus.name, status )
  }

  private fun updateResults(speechBundle: Bundle?, isFinal: Boolean ) {
    val userSaid = speechBundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
    if ( null != userSaid ) {
      val speechResult  = JSONObject()
      speechResult.put("recognizedWords", userSaid.get(0))
      speechResult.put( "finalResult", isFinal )
      channel.invokeMethod( SpeechToTextCallbackMethods.textRecognition.name,
              speechResult.toString())
    }
  }

  private fun initializeIfPermitted(context: Application) {
    permissionToRecordAudio = ContextCompat.checkSelfPermission(context,
            Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    if ( !permissionToRecordAudio ) {
      ActivityCompat.requestPermissions(pluginActivity,
              arrayOf(Manifest.permission.RECORD_AUDIO), speechToTextPermissionCode )
    }
    else {
      completeInitialize()
    }
  }

  private fun completeInitialize() {

    if ( permissionToRecordAudio ) {
      speechRecognizer = createSpeechRecognizer(application.applicationContext).apply {
        setRecognitionListener(this@SpeechToTextPlugin)
      }

      setupRecognizerIntent( defaultLanguageTag )
    }

    initializedSuccessfully = permissionToRecordAudio
    activeResult?.success(permissionToRecordAudio)
    activeResult = null
  }

  private fun setupRecognizerIntent( languageTag: String ) {
    if ( previousRecognizerLang == null || previousRecognizerLang != languageTag ) {
      previousRecognizerLang = languageTag;
      recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, application.packageName)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        if ( languageTag != Locale.getDefault().toLanguageTag()) {
          putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag );
        }
      }

    }
  }

  override fun onRequestPermissionsResult( requestCode: Int, permissions: Array<out String>?,
                                           grantResults: IntArray?): Boolean {
    when (requestCode) {
      speechToTextPermissionCode -> {
        if ( null != grantResults ) {
          permissionToRecordAudio = grantResults.isNotEmpty() &&
                  grantResults.get(0) == PackageManager.PERMISSION_GRANTED
        }
        completeInitialize()
        return true
      }
    }
    return false
  }


  override fun onPartialResults(results: Bundle?) = updateResults(results, false )
  override fun onResults(results: Bundle?) = updateResults(results, true )
  override fun onEndOfSpeech() = notifyListening(isRecording = false)

  override fun onError(errorCode: Int) {
    val errorMsg = when (errorCode) {
      SpeechRecognizer.ERROR_AUDIO -> "error_audio_error"
      SpeechRecognizer.ERROR_CLIENT -> "error_client"
      SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
      SpeechRecognizer.ERROR_NETWORK -> "error_network"
      SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_timeout"
      SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
      SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
      SpeechRecognizer.ERROR_SERVER -> "error_server"
      SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_timeout"
      else -> "error_unknown"
    }
    val speechError  = JSONObject()
    speechError.put("errorMsg", errorMsg )
    speechError.put( "permanent", true )
    channel.invokeMethod( SpeechToTextCallbackMethods.notifyError.name, speechError.toString())
  }

  override fun onReadyForSpeech(p0: Bundle?) {}
  override fun onRmsChanged(p0: Float) {}
  override fun onBufferReceived(p0: ByteArray?) {}
  override fun onEvent(p0: Int, p1: Bundle?) {}
  override fun onBeginningOfSpeech() {}
}

  // See https://stackoverflow.com/questions/10538791/how-to-set-the-language-in-speech-recognition-on-android/10548680#10548680
class LanguageDetailsChecker(flutterResult: Result, pluginActivity: Activity) : BroadcastReceiver() {
  private val pluginActivity: Activity = pluginActivity
  private val result: Result = flutterResult
  private var supportedLanguages: List<String>? = null

  private var languagePreference: String? = null

  override fun onReceive(context: Context, intent: Intent) {
    val results = getResultExtras(true)
    if (results.containsKey(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE)) {
      languagePreference = results.getString(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE)
    }
    if (results.containsKey(RecognizerIntent.EXTRA_SUPPORTED_LANGUAGES)) {
      supportedLanguages = results.getStringArrayList(
              RecognizerIntent.EXTRA_SUPPORTED_LANGUAGES)
      createResponse( supportedLanguages )
    }
  }
    private fun createResponse( supportedLanguages: List<String>? ) {
      val currentLocale = Locale.getDefault()
      val localeNames = ArrayList<String>()
      localeNames.add( buildIdNameForLocale(currentLocale))
      if ( null != supportedLanguages ) {
        for ( lang in supportedLanguages) {
          if ( currentLocale.toLanguageTag() == lang ) {
            continue
          }
          val locale = Locale.forLanguageTag(lang)
         localeNames.add( buildIdNameForLocale(locale))
        }
      }
      pluginActivity.runOnUiThread { result.success(localeNames) }

    }

    private fun buildIdNameForLocale( locale: Locale ): String {
      val name = locale.displayName.replace(':', ' ')
      return "${locale.language}_${locale.country}:$name"
    }
}