package io.github.mikechokki.palier

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity : exigée par local_auth pour la boîte de dialogue d'empreinte.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Garder l'écran allumé pendant une séance guidée : quelques lignes ici plutôt
        // qu'un paquet de plus. Le drapeau ne vaut que pour cette fenêtre, au premier
        // plan ; Android le retire de lui-même quand l'application passe derrière.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "palier/ecran").setMethodCallHandler { call, result ->
            when (call.method) {
                "garderAllume" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
