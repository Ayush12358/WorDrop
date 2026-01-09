package com.ayush.wordrop

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ayush.wordrop/device_admin"
    private val REQUEST_CODE_ENABLE_ADMIN = 1

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = ComponentName(this, WorDropDeviceAdminReceiver::class.java)

            if (call.method == "requestDeviceAdmin") {
                if (!dpm.isAdminActive(componentName)) {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                    intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "WorDrop needs admin access to lock the screen via voice command.")
                    startActivityForResult(intent, REQUEST_CODE_ENABLE_ADMIN)
                    result.success(true)
                } else {
                    result.success(true) // Already active
                }
            } else if (call.method == "isAdminActive") {
                result.success(dpm.isAdminActive(componentName))
            } else if (call.method == "lockDevice") {
                if (dpm.isAdminActive(componentName)) {
                    dpm.lockNow()
                    result.success(true)
                } else {
                    result.error("NOT_ADMIN", "Device Admin not enabled", null)
                }
            } else if (call.method == "isDeviceLocked") {
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                result.success(keyguardManager.isKeyguardLocked)
            } else if (call.method == "requestAccessibility") {
                val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                result.success(true)
            } else if (call.method == "isAccessibilityActive") {
                result.success(WorDropAccessibilityService.instance != null)
            } else if (call.method == "lockDeviceAccessibility") {
                val service = WorDropAccessibilityService.instance
                if (service != null) {
                    val success = service.lockDevice()
                    result.success(success)
                } else {
                    result.error("NOT_Bound", "Accessibility Service not bound", null)
                }
            } else if (call.method == "openPrivacySettings") {
                 val intent = Intent(android.provider.Settings.ACTION_PRIVACY_SETTINGS)
                 intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                 startActivity(intent)
                 result.success(true)
            } else if (call.method == "isAssistantActive") {
                val componentName = ComponentName(this, WorDropVoiceInteractionService::class.java)
                val am = android.provider.Settings.Secure.getString(contentResolver, "voice_interaction_service")
                result.success(am == componentName.flattenToString())
            } else if (call.method == "openAssistantSettings") {
                 val intent = Intent(android.provider.Settings.ACTION_VOICE_INPUT_SETTINGS)
                 intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                 startActivity(intent)
                 result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
