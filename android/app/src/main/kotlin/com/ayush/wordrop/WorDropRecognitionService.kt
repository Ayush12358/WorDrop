package com.ayush.wordrop

import android.speech.RecognitionService
import android.content.Intent

class WorDropRecognitionService : RecognitionService() {
    override fun onStartListening(intent: Intent, callback: Callback) {
        // Stub - we don't necessarily need to implement this fully if we just want the permission
    }
    
    override fun onStopListening(callback: Callback) {
        // Stub
    }

    override fun onCancel(callback: Callback) {
        // Stub
    }
}
