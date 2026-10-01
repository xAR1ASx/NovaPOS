package com.example.mi_fruver_pos.security

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class LockScreenActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configurarVentanaSegura()
        setContentView(crearVistaBloqueo())
        iniciarKiosco()
    }

    override fun onResume() {
        super.onResume()
        aplicarModoInmersivo()
        iniciarKiosco()
    }

    private fun configurarVentanaSegura() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
        setFinishOnTouchOutside(false)
    }

    private fun iniciarKiosco() {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

        if (dpm.isLockTaskPermitted(packageName)) {
            if (am.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
                try {
                    startLockTask()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun aplicarModoInmersivo() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }

    private fun crearVistaBloqueo(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#B71C1C"))
            setPadding(60, 60, 60, 60)
        }

        val icono = TextView(this).apply {
            text = "🔒"
            textSize = 72f
            gravity = Gravity.CENTER
        }

        val titulo = TextView(this).apply {
            text = "TERMINAL BLOQUEADA"
            textSize = 32f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 20, 0, 10)
        }

        val subtitulo = TextView(this).apply {
            text = "SUSPENSIÓN POR MORA DE CUOTA DE FINANCIAMIENTO"
            textSize = 18f
            setTextColor(Color.parseColor("#FFCDD2"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }

        val mensaje = TextView(this).apply {
            text = "El hardware y sistema POS han sido deshabilitados de forma remota. " +
                   "Para reactivar este equipo, debe normalizar el saldo pendiente y " +
                   "conectar la terminal a una red Wi-Fi con acceso a Internet.\n\n" +
                   "Soporte Financiero / Administración: +57 300 000 0000"
            textSize = 15f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(40, 0, 40, 40)
        }

        val btnWifi = Button(this).apply {
            text = "CONECTAR A WI-FI"
            setBackgroundColor(Color.WHITE)
            setTextColor(Color.parseColor("#B71C1C"))
            typeface = Typeface.DEFAULT_BOLD
            setOnClickListener {
                try {
                    startActivity(Intent(android.provider.Settings.ACTION_WIFI_SETTINGS))
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        root.addView(icono)
        root.addView(titulo)
        root.addView(subtitulo)
        root.addView(mensaje)
        root.addView(btnWifi)

        return root
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Bloqueado intencionalmente
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_HOME || 
            keyCode == KeyEvent.KEYCODE_BACK || 
            keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
}
