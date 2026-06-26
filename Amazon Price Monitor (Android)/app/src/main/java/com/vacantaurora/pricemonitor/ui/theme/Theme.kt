package com.vacantaurora.pricemonitor.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Amazon palette, shared with the iOS app's hex colors.
val AmazonOrange = Color(0xFFFF9900)
val PriceDown = Color(0xFF007600)
val PriceUp = Color(0xFFCC0C39)
val PriceStable = Color(0xFFE0A800)
val LoggedInGreen = Color(0xFF4CAF50)

private val LightColors = lightColorScheme(
    primary = AmazonOrange,
    secondary = AmazonOrange,
)

private val DarkColors = darkColorScheme(
    primary = AmazonOrange,
    secondary = AmazonOrange,
)

@Composable
fun PriceMonitorTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        content = content,
    )
}
