package pl.reiro.eksplorator

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val KANAL = "pl.reiro.eksplorator/apk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KANAL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "czyMozeInstalowac" -> {
                        // Przed Androidem 8 uprawnienie bylo statyczne w manifescie.
                        val moze = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(moze)
                    }

                    "otworzUstawienieInstalacji" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(null)
                    }

                    "zainstaluj" -> {
                        val sciezka = call.argument<String>("sciezka")
                        if (sciezka == null) {
                            result.error("BRAK_SCIEZKI", "Nie podano sciezki do pliku", null)
                            return@setMethodCallHandler
                        }

                        val plik = File(sciezka)
                        if (!plik.exists()) {
                            result.error("BRAK_PLIKU", "Plik nie istnieje", null)
                            return@setMethodCallHandler
                        }

                        try {
                            // Od Androida 7 nie wolno przekazywac file:// URI innym aplikacjom.
                            // FileProvider tworzy content:// URI, ktory instalator moze odczytac.
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                plik
                            )

                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                // Bez tej flagi instalator dostanie SecurityException.
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }

                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("BLAD_INSTALACJI", e.message ?: "Nieznany blad", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
