package com.vacantaurora.pricemonitor.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.vacantaurora.pricemonitor.R
import com.vacantaurora.pricemonitor.model.CartItem
import com.vacantaurora.pricemonitor.model.priceValue
import com.vacantaurora.pricemonitor.ui.theme.AmazonOrange
import com.vacantaurora.pricemonitor.ui.theme.PriceDown

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ItemDetailScreen(item: CartItem?, onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.detail_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
            )
        },
    ) { padding ->
        if (item == null) {
            Column(Modifier.fillMaxSize().padding(padding), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text(stringResource(R.string.err_no_items))
            }
            return@Scaffold
        }

        Column(
            Modifier.fillMaxSize().padding(padding).padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AsyncImage(
                model = item.imageURL,
                contentDescription = item.title,
                contentScale = ContentScale.Fit,
                modifier = Modifier.size(120.dp).clip(RoundedCornerShape(12.dp)),
            )
            Spacer(Modifier.height(12.dp))
            Text(item.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(16.dp))

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                Stat(stringResource(R.string.current), item.currentPrice)
                Stat(stringResource(R.string.lowest), item.lowestPrice, color = PriceDown)
                Stat(stringResource(R.string.highest), item.highestPrice)
            }

            Spacer(Modifier.height(24.dp))
            if (item.history.size >= 2) {
                Text(stringResource(R.string.history), style = MaterialTheme.typography.titleSmall, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                PriceChart(item.history.map { it.price }, Modifier.fillMaxWidth().height(160.dp))
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: Double?, color: androidx.compose.ui.graphics.Color = AmazonOrange) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = MaterialTheme.typography.labelSmall)
        Spacer(Modifier.height(2.dp))
        Row {
            Text("R$ ", style = MaterialTheme.typography.labelSmall, color = color)
            Text(value?.priceValue() ?: "—", fontWeight = FontWeight.Bold, color = color)
        }
    }
}

/** Minimal sparkline of the price history. */
@Composable
private fun PriceChart(prices: List<Double>, modifier: Modifier = Modifier) {
    val min = prices.min()
    val max = prices.max()
    val range = (max - min).takeIf { it > 0 } ?: 1.0
    Canvas(modifier) {
        if (prices.size < 2) return@Canvas
        val stepX = size.width / (prices.size - 1)
        val path = Path()
        prices.forEachIndexed { i, p ->
            val x = stepX * i
            val y = size.height - ((p - min) / range).toFloat() * size.height
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(path, color = AmazonOrange, style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4f))
        prices.forEachIndexed { i, p ->
            val x = stepX * i
            val y = size.height - ((p - min) / range).toFloat() * size.height
            drawCircle(AmazonOrange, radius = 5f, center = Offset(x, y))
        }
    }
}
