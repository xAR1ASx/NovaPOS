package com.example.mi_fruver_pos.security

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class DeadManSwitchWorker(
    private val context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        const val PREFS_NAME = "novapos_security_prefs"
        const val KEY_LAST_SYNC_EPOCH = "last_valid_sync_timestamp"
        const val KEY_LICENSE_TYPE = "license_type" // 'financiado' or 'contado'
        const val MAX_OFFLINE_HOURS = 72L
        private const val TAG = "DeadManSwitch"

        fun actualizarTimestampLicencia(context: Context, isFinanced: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val ahora = System.currentTimeMillis()
            prefs.edit().apply {
                putLong(KEY_LAST_SYNC_EPOCH, ahora)
                putString(KEY_LICENSE_TYPE, if (isFinanced) "financiado" else "contado")
            }.apply()
            Log.i(TAG, "Timestamp de licencia renovado con éxito: \$ahora (Financiado: \$isFinanced)")
        }

        fun forzarBloqueoInmediato(context: Context) {
            val intent = Intent(context, LockScreenActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
        }
    }

    override suspend fun doWork(): Result {
        val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ultimoTimestamp = prefs.getLong(KEY_LAST_SYNC_EPOCH, 0L)
        val licenseType = prefs.getString(KEY_LICENSE_TYPE, "contado")
        
        // Exentar clientes de contado
        if (licenseType != "financiado") {
            Log.i(TAG, "Cliente de CONTADO. Se exime del Dead Man's Switch.")
            return Result.success()
        }

        val ahora = System.currentTimeMillis()

        if (ultimoTimestamp == 0L) {
            actualizarTimestampLicencia(context, true)
            return Result.success()
        }

        val limiteMilisegundos = TimeUnit.HOURS.toMillis(MAX_OFFLINE_HOURS)
        val tiempoTranscurrido = ahora - ultimoTimestamp

        if (ahora < ultimoTimestamp) {
            Log.e(TAG, "Manipulación de reloj del sistema detectada. Ejecutando bloqueo.")
            forzarBloqueoInmediato(context)
            return Result.success()
        }

        if (tiempoTranscurrido > limiteMilisegundos) {
            Log.w(TAG, "Dead Man's Switch ACTIVADO: \$tiempoTranscurrido ms sin validación online. Bloqueando.")
            forzarBloqueoInmediato(context)
        } else {
            val horasRestantes = TimeUnit.MILLISECONDS.toHours(limiteMilisegundos - tiempoTranscurrido)
            Log.d(TAG, "Licencia offline válida. Quedan aproximadamente \$horasRestantes horas de gracia.")
        }

        return Result.success()
    }
}
