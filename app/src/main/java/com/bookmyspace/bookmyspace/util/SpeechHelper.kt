package com.bookmyspace.bookmyspace.util

import android.content.Context
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale

class SpeechHelper private constructor(context: Context) : TextToSpeech.OnInitListener {

    private var tts: TextToSpeech? = TextToSpeech(context.applicationContext, this)
    private var isReady = false

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val currentAppLang = LocalizedStrings.currentLanguage.value
            val result = tts?.setLanguage(currentAppLang.locale)
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                // Fallback to US English if locale missing
                tts?.setLanguage(Locale.US)
            }
            isReady = true
        } else {
            Log.e("SpeechHelper", "TTS Initialization failed")
        }
    }

    fun updateLanguage(appLanguage: AppLanguage) {
        if (isReady && tts != null) {
            val result = tts?.setLanguage(appLanguage.locale)
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale.US)
            }
        }
    }

    fun speak(text: String) {
        if (isReady && tts != null) {
            tts?.stop()
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "UtteranceId_${System.currentTimeMillis()}")
        }
    }

    fun stop() {
        tts?.stop()
    }

    fun release() {
        try {
            tts?.stop()
            tts?.shutdown()
            tts = null
            instance = null
        } catch (e: Exception) {
            Log.e("SpeechHelper", "Error shutting down TTS", e)
        }
    }

    companion object {
        @Volatile
        private var instance: SpeechHelper? = null

        fun getInstance(context: Context): SpeechHelper {
            return instance ?: synchronized(this) {
                instance ?: SpeechHelper(context).also { instance = it }
            }
        }
    }
}
