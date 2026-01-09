package com.ayush.wordrop

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class WorDropAccessibilityService : AccessibilityService() {
    companion object {
        var instance: WorDropAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        println("WorDropAccessibilityService connected")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        println("WorDropAccessibilityService unbound")
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We don't need to process events, just perform actions
    }

    override fun onInterrupt() {
        // No-op
    }

    fun lockDevice(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
    }
}
