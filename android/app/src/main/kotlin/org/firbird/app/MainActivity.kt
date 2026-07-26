package org.firbird3.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaPlayer
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.metadata.MetadataExtractor
import java.io.FileInputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {
    private val channelName = "org.firbird3.app/inference"
    private var interpreter: Interpreter? = null
    private var labels: List<String> = emptyList()
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "warmUp" -> { ensureModel(); result.success(null) }
                    "identify" -> result.success(identify(call.argument<String>("imagePath")!!, call.argument<Int>("topK") ?: 5))
                    "dispose" -> { interpreter?.close(); interpreter = null; result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (exception: Exception) {
                result.error("inference_failed", exception.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.firbird3.app/media_player").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "play" -> {
                        val path = call.argument<String>("path") ?: throw IllegalArgumentException("Missing audio path")
                        stopMedia()
                        mediaPlayer = MediaPlayer().apply {
                            setDataSource(path)
                            setOnCompletionListener { stopMedia() }
                            prepare()
                            start()
                        }
                        result.success(null)
                    }
                    "setVolume" -> {
                        val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                        mediaPlayer?.setVolume(volume, volume)
                        result.success(null)
                    }
                    "pause" -> { mediaPlayer?.pause(); result.success(null) }
                    "resume" -> { mediaPlayer?.start(); result.success(null) }
                    "seekTo" -> { mediaPlayer?.seekTo(call.argument<Int>("positionMs") ?: 0); result.success(null) }
                    "position" -> result.success(mapOf(
                        "positionMs" to (mediaPlayer?.currentPosition ?: 0),
                        "durationMs" to (mediaPlayer?.duration ?: 0),
                        "isPlaying" to (mediaPlayer?.isPlaying == true),
                    ))
                    "playLooping" -> {
                        val path = call.argument<String>("path") ?: throw IllegalArgumentException("Missing audio path")
                        stopMedia()
                        mediaPlayer = MediaPlayer().apply {
                            setDataSource(path)
                            isLooping = true
                            prepare()
                            start()
                        }
                        result.success(null)
                    }
                    "stop" -> { stopMedia(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (exception: Exception) {
                result.error("media_failed", exception.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.firbird3.app/screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.firbird3.app/downloads").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "publishWav" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                            ?: throw IllegalArgumentException("Missing source path")
                        val displayName = call.argument<String>("displayName")
                            ?: throw IllegalArgumentException("Missing display name")
                        result.success(publishWavToDownloads(sourcePath, displayName))
                    }
                    else -> result.notImplemented()
                }
            } catch (exception: Exception) {
                result.error("download_failed", exception.message, null)
            }
        }
    }

    private fun ensureModel() {
        if (interpreter != null) return
        val descriptor = assets.openFd("flutter_assets/assets/models/birds_v1.tflite")
        val input = FileInputStream(descriptor.fileDescriptor).channel
        val mapped = input.map(java.nio.channels.FileChannel.MapMode.READ_ONLY, descriptor.startOffset, descriptor.declaredLength)
        interpreter = Interpreter(mapped, Interpreter.Options().setNumThreads(4))
        labels = MetadataExtractor(mapped.duplicate())
            .getAssociatedFile("probability-labels-en.txt")
            .bufferedReader()
            .readLines()
    }

    private fun identify(path: String, topK: Int): List<Map<String, Any>> {
        ensureModel()
        val source = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("Image cannot be opened")
        val bitmap = Bitmap.createScaledBitmap(source, 224, 224, true)
        val inputType = interpreter!!.getInputTensor(0).dataType()
        val input = ByteBuffer.allocateDirect(224 * 224 * 3 * if (inputType == DataType.FLOAT32) 4 else 1)
            .order(ByteOrder.nativeOrder())
        for (y in 0 until 224) for (x in 0 until 224) {
            val pixel = bitmap.getPixel(x, y)
            val channels = intArrayOf((pixel shr 16) and 0xFF, (pixel shr 8) and 0xFF, pixel and 0xFF)
            channels.forEach { channel ->
                if (inputType == DataType.FLOAT32) input.putFloat((channel - 127.5f) / 127.5f)
                else input.put(channel.toByte())
            }
        }
        // Interpreter reads from the buffer's current position. Rewind after
        // filling it so each selected photo, rather than an exhausted buffer,
        // becomes the model input.
        input.rewind()
        val scores = if (interpreter!!.getOutputTensor(0).dataType() == DataType.FLOAT32) {
            FloatArray(labels.size).also { interpreter!!.run(input, it) }.map { it.toDouble() }
        } else {
            Array(1) { ByteArray(labels.size) }.also { interpreter!!.run(input, it) }[0]
                .map { (it.toInt() and 0xFF) / 255.0 }
        }
        if (bitmap !== source) bitmap.recycle()
        source.recycle()
        return scores.mapIndexed { index, score -> index to score }
            .sortedByDescending { it.second }.take(topK).map { (index, score) ->
                mapOf("label" to labels[index], "score" to score)
            }
    }

    private fun stopMedia() {
        mediaPlayer?.run {
            if (isPlaying) stop()
            reset()
            release()
        }
        mediaPlayer = null
    }

    private fun publishWavToDownloads(sourcePath: String, displayName: String): String {
        require(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "Public Downloads export requires Android 10 or newer."
        }
        val source = File(sourcePath)
        require(source.exists()) { "Recording file does not exist." }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, "audio/wav")
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/FirBird",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create the Downloads file.")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Could not open the Downloads file.")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (exception: Exception) {
            resolver.delete(uri, null, null)
            throw exception
        }
        return uri.toString()
    }

    override fun onPause() { stopMedia(); super.onPause() }
    override fun onDestroy() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        stopMedia()
        interpreter?.close()
        super.onDestroy()
    }
}
