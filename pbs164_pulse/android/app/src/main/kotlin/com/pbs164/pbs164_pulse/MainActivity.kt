package com.pbs164.pbs164_pulse

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.pbs164.pulse/native"
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchAssistant" -> {
                    val assistantType = call.argument<String>("type") ?: "google"
                    val success = launchAssistantApp(assistantType)
                    result.success(success)
                }
                "openBluetoothSettings" -> {
                    val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "ringPhone" -> {
                    startRingingPhone()
                    result.success(true)
                }
                "stopRingPhone" -> {
                    stopRingingPhone()
                    result.success(true)
                }
                "makePar" -> {
                    val image = call.argument<ByteArray>("image")
                    val width = call.argument<Int>("width") ?: 240
                    val height = call.argument<Int>("height") ?: 298
                    val maxBytes = call.argument<Int>("maxBytes") ?: 0
                    val fa = call.argument<Boolean>("a") ?: false
                    val fb = call.argument<Boolean>("b") ?: false
                    val fc = call.argument<Boolean>("c") ?: false
                    val exact = call.argument<Boolean>("exact") ?: false
                    if (image == null) {
                        result.error("ARG", "image eksik", null)
                    } else {
                        // Dönüştürme ağır: ana iş parçacığını bloklamayalım
                        Thread {
                            try {
                                val r = WatchBackground.toPar(image, width, height, maxBytes, fa, fb, fc, exact)
                                runOnUiThread { result.success(mapOf("par" to r.par, "quality" to r.quality)) }
                            } catch (e: Throwable) {
                                runOnUiThread { result.error("PAR", e.message, null) }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchAssistantApp(type: String): Boolean {
        return try {
            when (type.lowercase()) {
                "gemini" -> {
                    val geminiIntent = packageManager.getLaunchIntentForPackage("com.google.android.apps.bard")
                    if (geminiIntent != null) {
                        geminiIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(geminiIntent)
                        true
                    } else {
                        val intent = Intent(Intent.ACTION_VOICE_COMMAND).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        true
                    }
                }
                "chatgpt" -> {
                    val gptIntent = packageManager.getLaunchIntentForPackage("com.openai.chatgpt")
                    if (gptIntent != null) {
                        gptIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(gptIntent)
                        true
                    } else {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://chatgpt.com")).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(browserIntent)
                        true
                    }
                }
                else -> { // "google"
                    val intent = Intent(Intent.ACTION_VOICE_COMMAND).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    true
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun startRingingPhone() {
        try {
            val alert = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, alert).apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                }
                play()
            }

            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val timings = longArrayOf(0, 800, 400, 800, 400, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(timings, -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopRingingPhone() {
        try {
            ringtone?.stop()
            ringtone = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
