package com.pbs164.pbs164_pulse

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream

/**
 * Saatin DIY kadran arka planını (240x298 vb.) PAR biçimine çevirici sarmalayıcısı.
 */
object WatchBackground {
    class Result(val par: ByteArray, val quality: Int)

    private fun invokeParTool(raw: ByteArray, width: Int, height: Int, a: Boolean, b: Boolean, c: Boolean): ByteArray? {
        return try {
            val clazz = Class.forName("com.bluetrum.abpartool.ParTool")
            val method = clazz.getMethod(
                "rawToPar",
                ByteArray::class.java,
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                Boolean::class.javaPrimitiveType,
                Boolean::class.javaPrimitiveType,
                Boolean::class.javaPrimitiveType
            )
            method.invoke(null, raw, width, height, a, b, c) as? ByteArray
        } catch (e: Throwable) {
            null
        }
    }

    fun toPar(encoded: ByteArray, width: Int, height: Int, maxBytes: Int, a: Boolean = false, b: Boolean = false, c: Boolean = false, exact: Boolean = false): Result {
        val decoded = BitmapFactory.decodeByteArray(encoded, 0, encoded.size)
            ?: throw IllegalArgumentException("Görsel çözülemedi")
        val base = if (exact && decoded.width == width && decoded.height == height) argbCopy(decoded) else fit(decoded, width, height)

        var quality = 100
        var current = base
        while (true) {
            val par = invokeParTool(rawArgb(current), width, height, a, b, c)
                ?: throw IllegalStateException("PAR dönüştürücü bu derlemede mevcut değil.")
            if (maxBytes <= 0 || par.size <= maxBytes) return Result(par, quality)
            quality -= 5
            if (quality < 5) throw IllegalStateException("Görsel saatin sınırına (${maxBytes} bayt) sığdırılamadı")
            current = jpegRoundTrip(base, quality)
        }
    }

    /** Alfa kanalını koruyan ARGB_8888 kopya (şeffaf rakam/ibre görselleri için). */
    private fun argbCopy(src: Bitmap): Bitmap = src.copy(Bitmap.Config.ARGB_8888, false)

    private fun fit(src: Bitmap, w: Int, h: Int): Bitmap {
        val scaled = if (src.width == w && src.height == h) src else Bitmap.createScaledBitmap(src, w, h, true)
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(out)
        canvas.drawColor(android.graphics.Color.BLACK)
        canvas.drawBitmap(scaled, 0f, 0f, null)
        return out
    }

    private fun jpegRoundTrip(src: Bitmap, quality: Int): Bitmap {
        val bos = ByteArrayOutputStream()
        src.compress(Bitmap.CompressFormat.JPEG, quality, bos)
        val bytes = bos.toByteArray()
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun rawArgb(bitmap: Bitmap): ByteArray {
        val w = bitmap.width
        val h = bitmap.height
        val px = IntArray(w * h)
        bitmap.getPixels(px, 0, w, 0, 0, w, h)
        val out = ByteArray(px.size * 4)
        for (i in px.indices) {
            val p = px[i]
            val o = i * 4
            out[o] = (p shr 24 and 0xFF).toByte()
            out[o + 1] = (p shr 16 and 0xFF).toByte()
            out[o + 2] = (p shr 8 and 0xFF).toByte()
            out[o + 3] = (p and 0xFF).toByte()
        }
        return out
    }
}
