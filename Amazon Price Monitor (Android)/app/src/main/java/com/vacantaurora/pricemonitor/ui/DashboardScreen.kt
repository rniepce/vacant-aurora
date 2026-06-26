package com.vacantaurora.pricemonitor.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.vacantaurora.pricemonitor.DashboardState
import com.vacantaurora.pricemonitor.R
import com.vacantaurora.pricemonitor.SortOption
import com.vacantaurora.pricemonitor.model.CartItem
import com.vacantaurora.pricemonitor.model.priceValue
import com.vacantaurora.pricemonitor.ui.theme.AmazonOrange
import com.vacantaurora.pricemonitor.ui.theme.LoggedInGreen
import com.vacantaurora.pricemonitor.ui.theme.PriceDown
import com.vacantaurora.pricemonitor.ui.theme.PriceStable
import com.vacantaurora.pricemonitor.ui.theme.PriceUp
import kotlin.math.abs

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun DashboardScreen(
    state: DashboardState,
    sortedItems: List<CartItem>,
    onRefresh: () -> Unit,
    onSortChange: (SortOption) -> Unit,
    onOpenLogin: () -> Unit,
    onOpenItem: (String) -> Unit,
    onEnableDemo: () -> Unit = {},
) {
    var sortMenuOpen by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    // Long-press the title to load demo data (for store screenshots).
                    Text(
                        stringResource(R.string.app_title),
                        modifier = Modifier.combinedClickable(
                            onClick = {},
                            onLongClick = onEnableDemo,
                        ),
                    )
                },
                actions = {
                    IconButton(onClick = onOpenLogin) {
                        Icon(
                            Icons.Default.AccountCircle,
                            contentDescription = stringResource(R.string.account),
                            tint = if (state.isLoggedIn) LoggedInGreen else AmazonOrange,
                        )
                    }
                },
            )
        },
        bottomBar = {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Button(
                    onClick = onRefresh,
                    enabled = !state.isLoading,
                    colors = ButtonDefaults.buttonColors(containerColor = AmazonOrange),
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.refresh))
                }
                Spacer(Modifier.weight(1f))
                Box {
                    TextButton(onClick = { sortMenuOpen = true }) {
                        Icon(Icons.Default.SwapVert, contentDescription = null)
                        Spacer(Modifier.width(4.dp))
                        Text(stringResource(state.sort.labelRes))
                    }
                    DropdownMenu(expanded = sortMenuOpen, onDismissRequest = { sortMenuOpen = false }) {
                        SortOption.entries.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(stringResource(option.labelRes)) },
                                onClick = { onSortChange(option); sortMenuOpen = false },
                            )
                        }
                    }
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                state.isLoading -> Column(
                    Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    CircularProgressIndicator(color = AmazonOrange)
                    Spacer(Modifier.size(12.dp))
                    Text(stringResource(R.string.reading_cart))
                }

                state.items.isEmpty() -> EmptyState(isLoggedIn = state.isLoggedIn)

                else -> ItemList(state, sortedItems, onOpenItem)
            }
        }
    }
}

@Composable
private fun EmptyState(isLoggedIn: Boolean) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Default.ShoppingCart, contentDescription = null, modifier = Modifier.size(56.dp), tint = Color.Gray)
        Spacer(Modifier.size(12.dp))
        Text(stringResource(R.string.empty_title), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.size(6.dp))
        Text(
            stringResource(if (isLoggedIn) R.string.empty_logged_in else R.string.empty_logged_out),
            style = MaterialTheme.typography.bodyMedium,
            color = Color.Gray,
        )
    }
}

@Composable
private fun ItemList(state: DashboardState, items: List<CartItem>, onOpenItem: (String) -> Unit) {
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(vertical = 8.dp),
    ) {
        state.errorMessage?.let { error ->
            item {
                Text(
                    error,
                    color = PriceUp,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                )
            }
        }
        items(items, key = { it.id }) { item ->
            ItemRow(item, onClick = { onOpenItem(item.id) })
        }
    }
}

@Composable
private fun ItemRow(item: CartItem, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AsyncImage(
            model = item.imageURL,
            contentDescription = item.title,
            contentScale = ContentScale.Fit,
            modifier = Modifier.size(56.dp).clip(RoundedCornerShape(10.dp)),
        )
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(
                item.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                maxLines = 2,
            )
            Spacer(Modifier.size(5.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                item.currentPrice?.let { price ->
                    Text("R$", fontSize = 11.sp, color = AmazonOrange)
                    Spacer(Modifier.width(2.dp))
                    Text(price.priceValue(), fontWeight = FontWeight.Bold, color = AmazonOrange)
                }
                item.priceChangePercent?.let { change ->
                    if (abs(change) > 0.01) {
                        Spacer(Modifier.width(8.dp))
                        val color = if (change < 0) PriceDown else PriceUp
                        Row(
                            Modifier
                                .clip(CircleShape)
                                .background(color.copy(alpha = 0.1f))
                                .padding(horizontal = 7.dp, vertical = 3.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                if (change < 0) Icons.Default.ArrowDownward else Icons.Default.ArrowUpward,
                                contentDescription = null,
                                tint = color,
                                modifier = Modifier.size(10.dp),
                            )
                            Text(
                                "${"%.1f".format(abs(change))}%",
                                color = color,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            }
        }
        Spacer(Modifier.width(8.dp))
        val trendColor = when (item.trend) {
            CartItem.Trend.DOWN -> PriceDown
            CartItem.Trend.UP -> PriceUp
            CartItem.Trend.STABLE -> PriceStable
        }
        Box(Modifier.size(8.dp).clip(CircleShape).background(trendColor))
    }
}
