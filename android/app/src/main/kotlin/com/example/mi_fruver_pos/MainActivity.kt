package com.example.mi_fruver_pos

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.example.mi_fruver_pos.security.DeadManSwitchWorker
import com.example.mi_fruver_pos.security.LockScreenActivity
import com.example.mi_fruver_pos.security.NovaDeviceAdminReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.novapos.security/kiosk"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NovaDeviceAdminReceiver.aplicarRestriccionesDeSeguridad(this)
        iniciarDeadManSwitchWorker()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "activarBloqueoMora" -> {
                    val intent = Intent(this, LockScreenActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "desactivarBloqueo" -> {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    if (am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE) {
                        stopLockTask()
                    }
                    result.success(true)
                }
                "renovarTimestampLicencia" -> {
                    val isFinanced = call.argument<Boolean>("isFinanced") ?: false
                    DeadManSwitchWorker.actualizarTimestampLicencia(this, isFinanced)
                    result.success(true)
                }
                "esDeviceOwner" -> {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                    result.success(dpm.isDeviceOwnerApp(packageName))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun iniciarDeadManSwitchWorker() {
        val workRequest = PeriodicWorkRequestBuilder<DeadManSwitchWorker>(1, TimeUnit.HOURS).build()
        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            "DeadManSwitchSecurityWork",
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }
}
