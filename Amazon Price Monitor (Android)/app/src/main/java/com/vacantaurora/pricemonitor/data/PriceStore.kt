package com.vacantaurora.pricemonitor.data

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.vacantaurora.pricemonitor.PriceMonitorApp
import com.vacantaurora.pricemonitor.R
import com.vacantaurora.pricemonitor.model.CartItem
import com.vacantaurora.pricemonitor.model.PriceEntry
import com.vacantaurora.pricemonitor.model.priceValue
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Persists tracked items and merges fresh scrapes into price history — a direct
 * port of the iOS PriceStore. Storage uses SharedPreferences + JSON (the
 * Android counterpart to UserDefaults + Codable).
 */
class PriceStore(private val context: Context) {

    private val prefs = context.getSharedPreferences("price_data", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    /** Notify when a price drops by at least this percentage. */
    private val notifyPercentage = 10.0

    // MARK: - Persistence

    fun loadItems(): List<CartItem> {
        val raw = prefs.getString(KEY_DATA, null) ?: return emptyList()
        return runCatching { json.decodeFromString<List<CartItem>>(raw) }.getOrDefault(emptyList())
    }

    fun lastUpdated(): Instant? =
        prefs.getLong(KEY_UPDATED, 0L).takeIf { it > 0 }?.let { Instant.ofEpochMilli(it) }

    private fun save(items: List<CartItem>, updated: Instant) {
        prefs.edit()
            .putString(KEY_DATA, json.encodeToString(items))
            .putLong(KEY_UPDATED, updated.toEpochMilli())
            .apply()
    }

    // MARK: - Process New Items

    /** Merges a fresh scrape into stored history and returns the updated list. */
    fun processNewItems(current: List<CartScrapeItem>): List<CartItem> {
        val existing = loadItems()
        val now = Instant.now()
        val next = mutableListOf<CartItem>()

        for (item in current) {
            val prior = existing.firstOrNull { it.id == item.id }
            // Sanitize: keep only plausible prices.
            var history = (prior?.history ?: emptyList()).filter { it.price > 10 }.toMutableList()
            val lastEntry = history.lastOrNull()

            // Anomaly detection: if price increased > 200%, reset history.
            if (lastEntry != null && lastEntry.price > 0) {
                val increase = (item.price - lastEntry.price) / lastEntry.price * 100
                if (increase > 200) history = mutableListOf()
            }

            // Notification logic: alert on a meaningful price drop.
            history.lastOrNull()?.let { lastSafe ->
                if (lastSafe.price > 10) {
                    val diff = lastSafe.price - item.price
                    if (diff > 0 && (diff / lastSafe.price) * 100 >= notifyPercentage) {
                        sendNotification(item.title, lastSafe.price, item.price)
                    }
                }
            }

            // Add a new entry unless we already recorded this exact price today.
            val newEntry = PriceEntry(date = ISO.format(now), price = item.price)
            val lastDate = lastEntry?.let { runCatching { Instant.parse(it.date) }.getOrNull() }
            val sameDay = lastDate?.let {
                it.atZone(ZoneId.systemDefault()).toLocalDate() ==
                    now.atZone(ZoneId.systemDefault()).toLocalDate()
            } ?: false

            if (lastEntry == null || lastEntry.price != item.price || !sameDay) {
                history.add(newEntry)
            }

            // Limit history to the most recent 30 entries.
            if (history.size > 30) history = history.takeLast(30).toMutableList()

            next.add(CartItem(item.id, item.title, item.imageURL, history))
        }

        save(next, now)
        return next
    }

    // MARK: - Notifications

    private fun sendNotification(title: String, oldPrice: Double, newPrice: Double) {
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) return

        val shortTitle = if (title.length > 40) title.take(37) + "..." else title
        val body = context.getString(R.string.price_drop_body, shortTitle, oldPrice.priceValue(), newPrice.priceValue())

        val notification = NotificationCompat.Builder(context, PriceMonitorApp.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.price_drop_title))
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(title.hashCode(), notification)
    }

    // MARK: - Demo Data

    fun populateWithDemoData(): List<CartItem> {
        val now = Instant.now()
        fun daysAgo(d: Long) = ISO.format(now.minusSeconds(86400 * d))
        val demo = listOf(
            CartItem("B0CHX6BKK5", "Apple iPhone 15 Pro (256 GB) - Titânio Natural",
                "https://m.media-amazon.com/images/I/41lRlXsSGsL._AC_SY200_.jpg", listOf(
                    PriceEntry(daysAgo(5), 9299.00), PriceEntry(daysAgo(2), 8999.00), PriceEntry(ISO.format(now), 8799.00))),
            CartItem("B09DFCB66S", "Console PlayStation 5",
                "https://m.media-amazon.com/images/I/51mWHXY8hyL._AC_SY200_.jpg", listOf(
                    PriceEntry(daysAgo(7), 4499.00), PriceEntry(daysAgo(3), 4199.00), PriceEntry(ISO.format(now), 3999.00))),
            CartItem("B09V3HBW8Q", "Kindle Paperwhite 16 GB - Tela de 6,8\"",
                "https://m.media-amazon.com/images/I/41QYyFRGqWL._AC_SY200_.jpg", listOf(
                    PriceEntry(daysAgo(10), 799.00), PriceEntry(ISO.format(now), 799.00))),
            CartItem("B084J4WGV9", "Echo Dot (4ª Geração): Smart Speaker com Alexa - Preta",
                "https://m.media-amazon.com/images/I/51PBiByf5bL._AC_SY200_.jpg", listOf(
                    PriceEntry(daysAgo(15), 399.00), PriceEntry(daysAgo(5), 299.00), PriceEntry(ISO.format(now), 349.00))),
        )
        save(demo, now)
        return demo
    }

    companion object {
        private const val KEY_DATA = "amazon_price_data"
        private const val KEY_UPDATED = "amazon_last_updated"
        private val ISO: DateTimeFormatter = DateTimeFormatter.ISO_INSTANT
    }
}
