package com.tito.titodex.launcher.ui

import android.os.Build
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.tito.titodex.launcher.Effect
import com.tito.titodex.launcher.LauncherTheme
import com.tito.titodex.launcher.Wall

/** Original vector backgrounds per theme, plus the user's private photo. Effects are layered on top. */
@Composable
fun Wallpaper(theme: LauncherTheme, wall: Wall, effect: Effect, photo: ImageBitmap?, modifier: Modifier = Modifier) {
    Box(modifier.clipToBounds()) {
        val frost = effect == Effect.frost && Build.VERSION.SDK_INT >= 31
        Canvas(Modifier.fillMaxSize().then(if (frost) Modifier.blur(9.dp) else Modifier)) {
            drawWall(theme, if (wall == Wall.photo && photo == null) Wall.none else wall, photo)
        }
        if (effect == Effect.frost && !frost) Canvas(Modifier.fillMaxSize()) { drawRect(Color(0x55ffffff)) }
        if (effect == Effect.dim) Canvas(Modifier.fillMaxSize()) { drawRect(Color(0x6b0b2036)) }
        if (effect == Effect.scanlines) Canvas(Modifier.fillMaxSize()) {
            var y = 0f
            val step = 4.dp.toPx()
            while (y < size.height) { drawRect(Color(0x1f000000), Offset(0f, y), Size(size.width, 1.dp.toPx())); y += step }
        }
    }
}

private fun DrawScope.hills(colors: List<Color>) {
    val w = size.width
    val h = size.height
    colors.forEachIndexed { i, c ->
        val p = Path().apply {
            moveTo(0f, h * (.58f + i * .13f))
            cubicTo(w * .25f, h * (.50f + i * .10f), w * .62f, h * (.78f + i * .08f), w, h * (.55f + i * .13f))
            lineTo(w, h); lineTo(0f, h); close()
        }
        drawPath(p, c)
    }
}

private fun DrawScope.sun(cx: Float, cy: Float, d: Float, c: Color) = drawCircle(c, d / 2, Offset(cx, cy))

fun DrawScope.drawWall(theme: LauncherTheme, wall: Wall, photo: ImageBitmap?) {
    val w = size.width
    val h = size.height
    when (wall) {
        Wall.none -> when (theme) {
            LauncherTheme.journal -> {
                drawRect(Brush.linearGradient(listOf(Color(0xffaec2d0), Color(0xffdbe4e0)), Offset(0f, 0f), Offset(w * .6f, h)))
                val step = 16.dp.toPx()
                var y = step / 2
                while (y < h) {
                    var x = step / 2
                    while (x < w) { drawCircle(Color(0x2436475b), 1.dp.toPx(), Offset(x, y)); x += step }
                    y += step
                }
                for (i in 0..3) {
                    val p = Path().apply {
                        moveTo(w * .38f, h * (.30f + i * .04f))
                        cubicTo(w * .58f, h * (.18f + i * .04f), w * .78f, h * (.46f + i * .04f), w * 1.06f, h * (.30f + i * .04f))
                    }
                    drawPath(p, Color(0x73ffffff), style = Stroke(1.dp.toPx()))
                }
            }
            LauncherTheme.plastic -> {
                drawRect(Brush.linearGradient(listOf(Color(0xff344d6b), Color(0xff58768f), Color(0xff758fa2)), Offset(0f, 0f), Offset(w * .5f, h)))
                drawCircle(Brush.radialGradient(listOf(Color(0x8cb9dfe7), Color.Transparent), Offset(w * .82f, h * .16f), w * .34f), w * .34f, Offset(w * .82f, h * .16f))
                drawCircle(Brush.radialGradient(listOf(Color(0x73d7cdea), Color.Transparent), Offset(w * .10f, h * .72f), w * .40f), w * .40f, Offset(w * .10f, h * .72f))
                drawCircle(Brush.radialGradient(listOf(Color(0x61bfe2d4), Color.Transparent), Offset(w * .72f, h), w * .42f), w * .42f, Offset(w * .72f, h))
            }
            LauncherTheme.flat -> {
                drawRect(Color(0xffe3e6ef))
                sun(w * .87f, -h * .30f + w * .39f, w * .78f, Color(0xffafc7da))
                sun(0f, h * .34f + w * .20f, w * .40f, Yellow)
                sun(w * .73f, h * .58f + w * .03f, w * .06f, Coral)
            }
        }
        Wall.coast -> {
            drawRect(Brush.verticalGradient(listOf(Color(0xff8ec5c6), Color(0xffdbe8d4))))
            sun(w * .785f, h * .235f, w * .15f, Color(0xbfffe4ab))
            hills(listOf(Color(0x1f2f4361), Color(0x2e2f4361), Color(0x402f4361)))
        }
        Wall.dusk -> {
            drawRect(Brush.verticalGradient(0f to Color(0xff5b5f86), .62f to Color(0xffb88d9b), 1f to Color(0xffe0b09a)))
            sun(w * .755f, h * .325f, w * .17f, Color(0xadffe4ab))
            hills(listOf(Color(0x332f4361), Color(0x4d2f4361), Color(0x6b212d46)))
            for ((x, y) in listOf(.62f to .12f, .86f to .09f, .93f to .30f, .30f to .14f, .12f to .26f)) drawCircle(Color(0xbffff7e6), 1.4.dp.toPx(), Offset(w * x, h * y))
        }
        Wall.forest -> {
            drawRect(Brush.verticalGradient(listOf(Color(0xff8ab09b), Color(0xffc8d8b6))))
            hills(listOf(Color(0x24255d55), Color(0x38255d55), Color(0x52255d55)))
            for (i in 0..4) {
                val x = w * (.60f + i * .07f)
                val y = h * (.52f + (i % 2) * .03f)
                drawPath(Path().apply { moveTo(x, y - h * .09f); lineTo(x - w * .035f, y + h * .02f); lineTo(x + w * .035f, y + h * .02f); close() }, Color(0x6629574f))
            }
        }
        Wall.photo -> {
            if (photo != null) {
                val scale = maxOf(w / photo.width, h / photo.height)
                val dw = photo.width * scale
                val dh = photo.height * scale
                drawImage(photo, dstOffset = IntOffset(((w - dw) / 2).toInt(), ((h - dh) / 2).toInt()), dstSize = IntSize(dw.toInt(), dh.toInt()))
            }
            drawRect(Brush.verticalGradient(0f to Color(0x8c001020), .26f to Color(0x47001020), .52f to Color.Transparent))
        }
    }
}
