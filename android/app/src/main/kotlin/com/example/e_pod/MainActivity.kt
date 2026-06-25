package com.example.e_pod

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val whatsappChannel = "baj_epod/whatsapp_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            whatsappChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "sharePdfToWhatsApp") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val phone = call.argument<String>("phone").orEmpty()
            val fileName = call.argument<String>("fileName").orEmpty()
            val message = call.argument<String>("message").orEmpty()
            val pdfBytes = call.argument<ByteArray>("pdfBytes")

            if (phone.isBlank() || fileName.isBlank() || pdfBytes == null) {
                result.error(
                    "INVALID_ARGUMENTS",
                    "Phone number, file name, and PDF are required.",
                    null
                )
                return@setMethodCallHandler
            }

            sharePdfToWhatsApp(phone, fileName, message, pdfBytes, result)
        }
    }

    private fun sharePdfToWhatsApp(
        phone: String,
        fileName: String,
        message: String,
        pdfBytes: ByteArray,
        result: MethodChannel.Result
    ) {
        val whatsappPackage = findInstalledWhatsAppPackage()
        if (whatsappPackage == null) {
            result.error("WHATSAPP_NOT_INSTALLED", "WhatsApp is not installed.", null)
            return
        }

        try {
            val shareDir = File(cacheDir, "whatsapp_share").apply { mkdirs() }
            val pdfFile = File(shareDir, fileName).apply { writeBytes(pdfBytes) }
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                pdfFile
            )

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                setPackage(whatsappPackage)
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, message)
                putExtra("jid", "$phone@s.whatsapp.net")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            grantUriPermission(
                whatsappPackage,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            startActivity(intent)
            result.success(true)
        } catch (error: ActivityNotFoundException) {
            result.error("WHATSAPP_NOT_FOUND", "WhatsApp could not be opened.", null)
        } catch (error: Exception) {
            result.error("WHATSAPP_SHARE_FAILED", error.message, null)
        }
    }

    private fun findInstalledWhatsAppPackage(): String? {
        val packages = listOf("com.whatsapp", "com.whatsapp.w4b")
        return packages.firstOrNull { packageName ->
            try {
                packageManager.getPackageInfo(packageName, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }
}
