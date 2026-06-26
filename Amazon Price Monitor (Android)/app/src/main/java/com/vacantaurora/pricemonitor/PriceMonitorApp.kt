package com.vacantaurora.pricemonitor

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.vacantaurora.pricemonitor.work.RefreshWorker
import java.util.concurrent.TimeUnit

class PriceMonitorApp : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        schedulePeriodicRefresh()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notif_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = getString(R.string.notif_channel_desc) }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    /** Background price check every ~6h — a capability the iOS app does not have. */
    private fun schedulePeriodicRefresh() {
        val request = PeriodicWorkRequestBuilder<RefreshWorker>(6, TimeUnit.HOURS)
            .setConstraints(
                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            )
            .build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "amazon_price_refresh",
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    companion object {
        const val CHANNEL_ID = "price_drops"
    }
}
