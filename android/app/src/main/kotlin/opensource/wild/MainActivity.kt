package opensource.wild

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.sync.Mutex
import kotlin.coroutines.EmptyCoroutineContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.file.Files
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val scope = CoroutineScope(EmptyCoroutineContext)
    private val uiThreadHandler = Handler(Looper.getMainLooper())
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "methods").setMethodCallHandler { call, result ->
            result.withCoroutine {
                when (call.method) {
                    "dataRoot" -> {
                        androidDataLocal()
                    }
                    else -> {
                        null
                    }
                }
            }
        }
    }

    private fun MethodChannel.Result.withCoroutine(exec: () -> Any?) {
        scope.launch {
            try {
                val data = exec()
                uiThreadHandler.post {
                    when (data) {
                        null -> {
                            notImplemented()
                        }
                        is Unit -> {
                            success(null)
                        }
                        else -> {
                            success(data)
                        }
                    }
                }
            } catch (e: Exception) {
                uiThreadHandler.post {
                    error("", e.message, "")
                }
            }

        }
    }

    private fun androidDataLocal(): String {
        val localFile = File(context!!.filesDir.absolutePath, "data.local")
        if (localFile.exists()) {
            val path = String(FileInputStream(localFile).use { it.readBytes() })
            if (File(path).isDirectory) {
                return path
            }
        }
        return context!!.filesDir.absolutePath
    }
}
