package com.vacantaurora.pricemonitor.model

import kotlinx.serialization.Serializable
import java.text.NumberFormat

@Serializable
data class PriceEntry(
    val date: String, // ISO-8601 instant string
    val price: Double,
) {
    val id: String get() = date
}

@Serializable
data class CartItem(
    val id: String, // ASIN
    val title: String,
    val imageURL: String? = null,
    val history: List<PriceEntry> = emptyList(),
) {
    val currentPrice: Double? get() = history.lastOrNull()?.price

    val lowestPrice: Double? get() = history.minOfOrNull { it.price }

    val highestPrice: Double? get() = history.maxOfOrNull { it.price }

    val priceChangePercent: Double?
        get() {
            if (history.size < 2) return null
            val first = history.first().price
            val last = history.last().price
            if (first <= 0) return null
            return ((last - first) / first) * 100
        }

    enum class Trend { UP, DOWN, STABLE }

    val trend: Trend
        get() {
            val change = priceChangePercent ?: return Trend.STABLE
            return when {
                change < -0.01 -> Trend.DOWN
                change > 0.01 -> Trend.UP
                else -> Trend.STABLE
            }
        }
}

/**
 * Price formatted with the user's locale grouping/decimals, without the currency
 * symbol (the "R$" prefix is rendered separately in the UI). e.g. "8.799,00" / "8,799.00".
 */
fun Double.priceValue(): String {
    val formatter = NumberFormat.getNumberInstance().apply {
        minimumFractionDigits = 2
        maximumFractionDigits = 2
    }
    return formatter.format(this)
}
