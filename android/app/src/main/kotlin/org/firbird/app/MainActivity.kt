package org.firbird.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.metadata.MetadataExtractor
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {
    private val channelName = "org.firbird.app/inference"
    private var interpreter: Interpreter? = null
    private var labels: List<String> = emptyList()

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

    override fun onDestroy() { interpreter?.close(); super.onDestroy() }
}
