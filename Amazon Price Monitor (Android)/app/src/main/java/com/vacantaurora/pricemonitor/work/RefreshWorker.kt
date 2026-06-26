package com.vacantaurora.pricemonitor.work

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.vacantaurora.pricemonitor.data.AmazonAuth
import com.vacantaurora.pricemonitor.data.CartParser
import com.vacantaurora.pricemonitor.data.PriceStore

/**
 * Periodically re-scrapes the cart in the background and lets [PriceStore] fire
 * a notification on any meaningful price drop. Skips quietly when logged out.
 */
class RefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        if (!AmazonAuth.isLoggedIn()) return Result.success()
        return try {
            val scraped = CartParser.fetchCart(applicationContext)
            PriceStore(applicationContext).processNewItems(scraped)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
