package com.csdcorp.speech_to_text

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin
import android.Manifest
import android.annotation.TargetApi
import android.app.Activity
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
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import org.json.JSONArray
import java.util.*


enum class SpeechToTextErrors {
    multipleRequests,
    unimplemented,
    noLanguageIntent,
    recognizerNotAvailable,
    missingOrInvalidArg,
    unknown
}

enum class SpeechToTextCallbackMethods {
    textRecognition,
    notifyStatus,
    notifyError,
    soundLevelChange,
}

enum class SpeechToTextStatus {
    listening,
    notListening,
    unavailable,
    available,
}

enum class ListenMode {
    deviceDefault,
    dictation,
    search,
    confirmation,
}

const val pluginChannelName = "plugin.csdcorp.com/speech_to_text"

@TargetApi(8)
/** SpeechToTextPlugin */
public class SpeechToTextPlugin :
        MethodCallHandler, RecognitionListener,
        PluginRegistry.RequestPermissionsResultListener, FlutterPlugin,
        ActivityAware {
    private var pluginContext: Context? = null
    private var channel: MethodChannel? = null
    private val minSdkForSpeechSupport = 21
    private val speechToTextPermissionCode = 28521
    private val missingConfidence: Double = -1.0
    private val logTag = "SpeechToTextPlugin"
    private var currentActivity: Activity? = null
    private var activeResult: Result? = null
    private var initializedSuccessfully: Boolean = false
    private var permissionToRecordAudio: Boolean = false
    private var listening = false
    private var debugLogging: Boolean = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var recognizerIntent: Intent? = null
    private var previousRecognizerLang: String? = null
    private var previousPartialResults: Boolean = true
    private var previousListenMode: ListenMode = ListenMode.deviceDefault
    private var lastFinalTime: Long = 0
    private val handler: Handler = Handler(Looper.getMainLooper())
    private val defaultLanguageTag: String = Locale.getDefault().toLanguageTag()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {

        onAttachedToEngine(flutterPluginBinding.getApplicationContext(), flutterPluginBinding.getBinaryMessenger());
    }

    // This static function is optional and equivalent to onAttachedToEngine. It supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    //
    // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
    // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
    // depending on the user's project. onAttachedToEngine or registerWith must both be defined
    // in the same class.
    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val speechPlugin = SpeechToTextPlugin()
            speechPlugin.currentActivity = registrar.activity()
            registrar.addRequestPermissionsResultListener(speechPlugin)
            speechPlugin.onAttachedToEngine(registrar.context(), registrar.messenger())
        }
    }

    private fun onAttachedToEngine(applicationContext: Context, messenger: BinaryMessenger) {
        this.pluginContext = applicationContext;
        channel = MethodChannel(messenger, pluginChannelName)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        this.pluginContext = null;
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        currentActivity = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull rawrResult: Result) {
        val result = ChannelResultWrapper(rawrResult)
        try {
            when (call.method) {
                "has_permission" -> hasPermission(result)
                "initialize" -> {
                    var dlog = call.argument<Boolean>("debugLogging")
                    if (null != dlog) {
                        debugLogging = dlog
                    }
                    initialize(result)
                }
                "listen" -> {
                    var localeId = call.argument<String>("localeId")
                    if (null == localeId) {
                        localeId = defaultLanguageTag
                    }
                    var partialResults = call.argument<Boolean>("partialResults")
                    if (null == partialResults) {
                        partialResults = true
                    }
                    val listenModeIndex = call.argument<Int>("listenMode")
                    if ( null == listenModeIndex ) {
                        result.error(SpeechToTextErrors.missingOrInvalidArg.name,
                                "listenMode is required", null)
                        return
                    }
                    startListening(result, localeId, partialResults, listenModeIndex )
                }
                "stop" -> stopListening(result)
                "cancel" -> cancelListening(result)
                "locales" -> locales(result)
                else -> result.notImplemented()
            }
        } catch (exc: Exception) {
            Log.e(logTag, "Unexpected exception", exc)
            result.error(SpeechToTextErrors.unknown.name,
                    "Unexpected exception", exc.localizedMessage)
        }
    }

    private fun hasPermission(result: Result) {
        if (sdkVersionTooLow(result)) {
            return
        }
        debugLog("Start has_permission")
        val localContext = pluginContext
        if (localContext != null) {
            val hasPerm = ContextCompat.checkSelfPermission(localContext,
                    Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
            result.success(hasPerm)
        }
    }

    private fun initialize(result: Result) {
        if (sdkVersionTooLow(result)) {
            return
        }
        debugLog("Start initialize")
        if (null != activeResult) {
            result.error(SpeechToTextErrors.multipleRequests.name,
                    "Only one initialize at a time", null)
            return
        }
        activeResult = result
        val localContext = pluginContext
        initializeIfPermitted(pluginContext)
    }

    private fun sdkVersionTooLow(result: Result): Boolean {
        if (Build.VERSION.SDK_INT < minSdkForSpeechSupport) {
            result.success(false)
            return true;
        }
        return false;
    }

    private fun isNotInitialized(result: Result): Boolean {
        if (!initializedSuccessfully || null == pluginContext) {
            result.success(false)
        }
        return !initializedSuccessfully
    }

    private fun isListening(): Boolean {
        return listening
    }

    private fun isNotListening(): Boolean {
        return !listening
    }

    private fun startListening(result: Result, languageTag: String, partialResults: Boolean,
                               listenModeIndex: Int) {
        if (sdkVersionTooLow(result) || isNotInitialized(result) || isListening()) {
            return
        }
        debugLog("Start listening")
        var listenMode = ListenMode.deviceDefault
        if ( listenModeIndex == ListenMode.dictation.ordinal) {
            listenMode = ListenMode.dictation
        }
        setupRecognizerIntent(languageTag, partialResults, listenMode)
        handler.post {
            run {
                speechRecognizer?.startListening(recognizerIntent)
            }
        }
        notifyListening(isRecording = true)
        result.success(true)
        debugLog("Start listening done")
    }

    private fun stopListening(result: Result) {
        if (sdkVersionTooLow(result) || isNotInitialized(result) || isNotListening()) {
            return
        }
        debugLog("Stop listening")
        handler.post {
            run {
                speechRecognizer?.stopListening()
            }
        }
        notifyListening(isRecording = false)
        result.success(true)
        debugLog("Stop listening done")
    }

    private fun cancelListening(result: Result) {
        if (sdkVersionTooLow(result) || isNotInitialized(result) || isNotListening()) {
            return
        }
        debugLog("Cancel listening")
        handler.post {
            run {
                speechRecognizer?.cancel()
            }
        }
        notifyListening(isRecording = false)
        result.success(true)
        debugLog("Cancel listening done")
    }

    private fun locales(result: Result) {
        if (sdkVersionTooLow(result) || isNotInitialized(result)) {
            return
        }
        var detailsIntent = RecognizerIntent.getVoiceDetailsIntent(pluginContext)
        if (null == detailsIntent) {
            detailsIntent = Intent(RecognizerIntent.ACTION_GET_LANGUAGE_DETAILS)
        }
        if (null == detailsIntent) {
            result.error(SpeechToTextErrors.noLanguageIntent.name,
                    "Could not get voice details", null)
            return
        }
        pluginContext?.sendOrderedBroadcast(
                detailsIntent, null, LanguageDetailsChecker(result),
                null, Activity.RESULT_OK, null, null)
    }

    private fun notifyListening(isRecording: Boolean) {
        debugLog("Notify listening")
        listening = isRecording
        val status = when (isRecording) {
            true -> SpeechToTextStatus.listening.name
            false -> SpeechToTextStatus.notListening.name
        }
        channel?.invokeMethod(SpeechToTextCallbackMethods.notifyStatus.name, status)
        debugLog("Notify listening done")
    }

    private fun updateResults(speechBundle: Bundle?, isFinal: Boolean) {
        if (isDuplicateFinal( isFinal )) {
            debugLog("Discarding duplicate final")
            return
        }
        val userSaid = speechBundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (null != userSaid && userSaid.isNotEmpty()) {
            val speechResult = JSONObject()
            speechResult.put("finalResult", isFinal)
            val confidence = speechBundle?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
            val alternates = JSONArray()
            for (resultIndex in 0..userSaid.size - 1) {
                val speechWords = JSONObject()
                speechWords.put("recognizedWords", userSaid[resultIndex])
                if (null != confidence && confidence.size >= userSaid.size) {
                    speechWords.put("confidence", confidence[resultIndex])
                } else {
                    speechWords.put("confidence", missingConfidence)
                }
                alternates.put(speechWords)
            }
            speechResult.put("alternates", alternates)
            val jsonResult = speechResult.toString()
            debugLog("Calling results callback")
            channel?.invokeMethod(SpeechToTextCallbackMethods.textRecognition.name,
                    jsonResult)
        }
    }

    private fun isDuplicateFinal( isFinal: Boolean ) : Boolean {
        if ( !isFinal ) {
            return false
        }
        val delta = System.currentTimeMillis() - lastFinalTime
        lastFinalTime = System.currentTimeMillis()
        return delta >= 0 && delta < 100
    }

    private fun initializeIfPermitted(context: Context?) {
        val localContext = context
        if (null == localContext) {
            completeInitialize()
            return
        }
        permissionToRecordAudio = ContextCompat.checkSelfPermission(localContext,
                Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        debugLog("Checked permission")
        if (!permissionToRecordAudio) {
            val localActivity = currentActivity
            if (null != localActivity) {
                debugLog("Requesting permission")
                ActivityCompat.requestPermissions(localActivity,
                        arrayOf(Manifest.permission.RECORD_AUDIO), speechToTextPermissionCode)
            } else {
                debugLog("no permission, no activity, completing")
                completeInitialize()
            }
        } else {
            debugLog("has permission, completing")
            completeInitialize()
        }
        debugLog("leaving initializeIfPermitted")
    }

    private fun completeInitialize() {

        debugLog("completeInitialize")
        if (permissionToRecordAudio) {
            debugLog("Testing recognition availability")
            if (!SpeechRecognizer.isRecognitionAvailable(pluginContext)) {
                Log.e(logTag, "Speech recognition not available on this device")
                activeResult?.error(SpeechToTextErrors.recognizerNotAvailable.name,
                        "Speech recognition not available on this device", "")
                activeResult = null
                return
            }

            debugLog("Creating recognizer")
            speechRecognizer = createSpeechRecognizer(pluginContext).apply {
                debugLog("Setting listener")
                setRecognitionListener(this@SpeechToTextPlugin)
            }
            if (null == speechRecognizer) {
                Log.e(logTag, "Speech recognizer null")
                activeResult?.error(
                        SpeechToTextErrors.recognizerNotAvailable.name,
                        "Speech recognizer null", "")
                activeResult = null
            }

            debugLog("before setup intent")
            setupRecognizerIntent(defaultLanguageTag, true, ListenMode.deviceDefault)
            debugLog("after setup intent")
        }

        initializedSuccessfully = permissionToRecordAudio
        debugLog("sending result")
        activeResult?.success(permissionToRecordAudio)
        debugLog("leaving complete")
        activeResult = null
    }

    private fun setupRecognizerIntent(languageTag: String, partialResults: Boolean, listenMode: ListenMode) {
        debugLog("setupRecognizerIntent")
        if (previousRecognizerLang == null ||
                previousRecognizerLang != languageTag ||
                partialResults != previousPartialResults || previousListenMode != listenMode ) {
            previousRecognizerLang = languageTag;
            previousPartialResults = partialResults
            previousListenMode = listenMode
            handler.post {
                run {
                    recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        debugLog("In RecognizerIntent apply")
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        debugLog("put model")
                        val localContext = pluginContext
                        if (null != localContext) {
                            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE,
                                    localContext.applicationInfo.packageName)
                        }
                        debugLog("put package")
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResults)
                        debugLog("put partial")
                        if (languageTag != Locale.getDefault().toLanguageTag()) {
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag);
                            debugLog("put languageTag")
                        }
                    }
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?,
                                            grantResults: IntArray?): Boolean {
        when (requestCode) {
            speechToTextPermissionCode -> {
                if (null != grantResults) {
                    permissionToRecordAudio = grantResults.isNotEmpty() &&
                            grantResults.get(0) == PackageManager.PERMISSION_GRANTED
                }
                completeInitialize()
                return true
            }
        }
        return false
    }


    override fun onPartialResults(results: Bundle?) = updateResults(results, false)
    override fun onResults(results: Bundle?) = updateResults(results, true)
    override fun onEndOfSpeech() = notifyListening(isRecording = false)

    override fun onError(errorCode: Int) {
        val errorMsg = when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "error_audio_error"
            SpeechRecognizer.ERROR_CLIENT -> "error_client"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
            SpeechRecognizer.ERROR_NETWORK -> "error_network"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
            SpeechRecognizer.ERROR_SERVER -> "error_server"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
            else -> "error_unknown"
        }
        sendError(errorMsg)
    }

    private fun debugLog( msg: String ) {
        if ( debugLogging ) {
            Log.d( logTag, msg )
        }
    }

    private fun sendError(errorMsg: String) {
        val speechError = JSONObject()
        speechError.put("errorMsg", errorMsg)
        speechError.put("permanent", true)
        handler.post {
            run {
                channel?.invokeMethod(SpeechToTextCallbackMethods.notifyError.name, speechError.toString())
            }
        }
    }

    override fun onRmsChanged(rmsdB: Float) {
        handler.post {
            run {
                channel?.invokeMethod(SpeechToTextCallbackMethods.soundLevelChange.name, rmsdB)
            }
        }
    }

    override fun onReadyForSpeech(p0: Bundle?) {}
    override fun onBufferReceived(p0: ByteArray?) {}
    override fun onEvent(p0: Int, p1: Bundle?) {}
    override fun onBeginningOfSpeech() {}
}

// See https://stackoverflow.com/questions/10538791/how-to-set-the-language-in-speech-recognition-on-android/10548680#10548680
class LanguageDetailsChecker(flutterResult: Result) : BroadcastReceiver() {
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
            createResponse(supportedLanguages)
        }
    }

    private fun createResponse(supportedLanguages: List<String>?) {
        val currentLocale = Locale.getDefault()
        val localeNames = ArrayList<String>()
        localeNames.add(buildIdNameForLocale(currentLocale))
        if (null != supportedLanguages) {
            for (lang in supportedLanguages) {
                if (currentLocale.toLanguageTag() == lang) {
                    continue
                }
                val locale = Locale.forLanguageTag(lang)
                localeNames.add(buildIdNameForLocale(locale))
            }
        }
        result.success(localeNames)

    }

    private fun buildIdNameForLocale(locale: Locale): String {
        val name = locale.displayName.replace(':', ' ')
        return "${locale.language}_${locale.country}:$name"
    }
}

private class ChannelResultWrapper(result: Result) : Result {
    // Caller handler
    val handler: Handler = Handler(Looper.getMainLooper())
    val result: Result = result

    // make sure to respond in the caller thread
    override fun success(results: Any?) {

        handler.post {
            run {
                result.success(results);
            }
        }
    }

    override fun error(errorCode: String?, errorMessage: String?, data: Any?) {
        handler.post {
            run {
                result.error(errorCode, errorMessage, data);
            }
        }
    }

    override fun notImplemented() {
        handler.post {
            run {
                result.notImplemented();
            }
        }
    }
}
