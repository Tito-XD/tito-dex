package com.tito.titodex.launcher.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tito.titodex.launcher.Effect
import com.tito.titodex.launcher.LauncherTheme
import com.tito.titodex.launcher.R
import com.tito.titodex.launcher.Settings
import com.tito.titodex.launcher.Wall
import com.tito.titodex.launcher.inkOnDark
import com.tito.titodex.launcher.plateAlpha

val Navy = Color(0xff2f4361)
val NavyDeep = Color(0xff22324a)
val Cream = Color(0xfffff7e6)
val Paper = Color(0xfffffaf0)
val Coral = Color(0xffff8f6a)
val Yellow = Color(0xfff7d977)
val Danger = Color(0xffd64545)
val JournalInk = Color(0xff36475b)
val JournalLine = Color(0xff7c8999)
val PlasticInk = Color(0xff20334a)
val FlatInk = Color(0xff1a1c20)
val FlatPaper = Color(0xfff9f9ff)

val Nunito = FontFamily(
    Font(R.font.nunito_regular, FontWeight.Normal),
    Font(R.font.nunito_bold, FontWeight.Bold),
    Font(R.font.nunito_extrabold, FontWeight.ExtraBold),
)

fun text(size: TextUnit, weight: FontWeight = FontWeight.Bold, color: Color = Color.Unspecified, spacing: TextUnit = TextUnit.Unspecified) =
    TextStyle(
        fontFamily = Nunito,
        fontSize = size,
        fontWeight = weight,
        color = color,
        letterSpacing = spacing,
        lineHeight = size * 1.25f,
        platformStyle = PlatformTextStyle(includeFontPadding = true),
    )

/** Colours derived from settings, shared by every sticker. */
data class Look(
    val theme: LauncherTheme,
    val bgInk: Color,
    val accentInk: Color,
    val ink: Color,
    val plateAlpha: Float,
    val blur: Boolean,
) {
    val journal get() = theme == LauncherTheme.journal
    val plastic get() = theme == LauncherTheme.plastic
    val flat get() = theme == LauncherTheme.flat
    val sheetInk get() = when (theme) { LauncherTheme.journal -> JournalInk; LauncherTheme.plastic -> PlasticInk; LauncherTheme.flat -> FlatInk }
}

fun lookOf(s: Settings): Look {
    val dark = inkOnDark(s)
    val bgInk = when {
        dark -> Cream
        s.wallpaper == Wall.none && s.theme == LauncherTheme.flat -> FlatInk
        s.wallpaper == Wall.none && s.theme == LauncherTheme.journal -> JournalInk
        else -> Navy
    }
    val accent = when (s.theme) {
        LauncherTheme.journal -> if (dark) Color(0xfff2c9a8) else Color(0xffb0745a)
        LauncherTheme.plastic -> if (dark) Color(0xffb9dfe7) else Color(0xff3d7f93)
        LauncherTheme.flat -> Coral
    }
    val ink = when (s.theme) { LauncherTheme.journal -> JournalInk; LauncherTheme.plastic -> PlasticInk; LauncherTheme.flat -> FlatInk }
    return Look(s.theme, bgInk, accent, ink, plateAlpha(s), s.blurPanels && s.effect != Effect.frost)
}

val LocalLook = compositionLocalOf { lookOf(Settings()) }

fun plateShape(look: Look, journalRadius: Dp = 16.dp): Shape = RoundedCornerShape(
    when (look.theme) { LauncherTheme.journal -> journalRadius; LauncherTheme.plastic -> 26.dp; LauncherTheme.flat -> 20.dp },
)

enum class PlateKind { Plain, Trainer, Shelf, Tito }

/** The themed surface under trainer, shelf and labelled TitoDex. Never a generic card: each theme has its own material. */
@Composable
fun Modifier.plate(look: Look, kind: PlateKind = PlateKind.Plain): Modifier {
    val a = look.plateAlpha
    val shape = plateShape(look)
    return when (look.theme) {
        LauncherTheme.journal -> this
            .drawBehind {
                val r = CornerRadius(16.dp.toPx())
                drawRoundRect(Color(0x2b566a77), topLeft = Offset(0f, 3.dp.toPx()), size = size, cornerRadius = r)
                drawRoundRect(Color(0xffe4dfd3), topLeft = Offset(0f, 2.dp.toPx()), size = size, cornerRadius = r)
            }
            .background(Paper.copy(alpha = a), shape)
            .border(1.25.dp, JournalLine, shape)
        LauncherTheme.plastic -> {
            val (top, bottom) = when (kind) {
                PlateKind.Trainer -> Color(0xfff6f2ff).copy(alpha = a * .95f) to Color(0xffd7cdea).copy(alpha = a * .7f)
                PlateKind.Shelf -> Color(0xffecfafc).copy(alpha = a * .9f) to Color(0xffb9dfe7).copy(alpha = a * .55f)
                else -> Color.White.copy(alpha = a * .95f) to Color(0xffd2e6ee).copy(alpha = a * .62f)
            }
            this
                .shadow(10.dp, shape, ambientColor = Color(0x6013263d), spotColor = Color(0x8013263d))
                .background(Brush.verticalGradient(listOf(top, bottom)), shape)
                .border(1.1.dp, Color.White.copy(alpha = .78f), shape)
                .drawBehind {
                    drawLine(Color.White.copy(alpha = .95f), Offset(18.dp.toPx(), 1.dp.toPx()), Offset(size.width - 18.dp.toPx(), 1.dp.toPx()), 1.5.dp.toPx())
                }
        }
        LauncherTheme.flat -> {
            val color = when (kind) {
                PlateKind.Trainer -> Yellow
                PlateKind.Tito -> Coral
                else -> FlatPaper
            }
            this.background(color.copy(alpha = a), shape)
        }
    }
}
