package com.example.mi_fruver_pos.security

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.UserManager
import android.util.Log

class NovaDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        private const val TAG = "NovaDeviceAdmin"

        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context.applicationContext, NovaDeviceAdminReceiver::class.java)
        }

        fun aplicarRestriccionesDeSeguridad(context: Context) {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = getComponentName(context)

            if (dpm.isDeviceOwnerApp(context.packageName)) {
                try {
                    dpm.setUninstallBlocked(adminComponent, context.packageName, true)
                    dpm.addUserRestriction(adminComponent, UserManager.DISALLOW_SAFE_BOOT)
                    dpm.addUserRestriction(adminComponent, UserManager.DISALLOW_APPS_CONTROL)
                    dpm.setLockTaskPackages(adminComponent, arrayOf(context.packageName))
                    dpm.setLockTaskFeatures(adminComponent, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
                    Log.i(TAG, "Políticas de Device Owner aplicadas exitosamente.")
                } catch (e: Exception) {
                    Log.e(TAG, "Error aplicando restricciones de Device Owner: \${e.message}")
                }
            } else {
                Log.w(TAG, "La aplicación NO tiene rol de Device Owner. Algunas restricciones no aplicarán.")
            }
        }
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.i(TAG, "Device Admin Habilitado.")
        aplicarRestriccionesDeSeguridad(context)
    }

    override fun onLockTaskModeEntering(context: Context, intent: Intent, pkg: String) {
        super.onLockTaskModeEntering(context, intent, pkg)
        Log.w(TAG, "Iniciando Lock Task Mode Kiosco en: \$pkg")
    }

    override fun onLockTaskModeExiting(context: Context, intent: Intent) {
        super.onLockTaskModeExiting(context, intent)
        Log.w(TAG, "Saliendo de Lock Task Mode.")
    }
}
