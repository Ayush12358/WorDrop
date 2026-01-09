package com.ayush.wordrop

import android.service.voice.VoiceInteractionSessionService
import android.os.Bundle

class WorDropVoiceInteractionSessionService : VoiceInteractionSessionService() {
    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return WorDropVoiceInteractionSession(this)
    }
}
