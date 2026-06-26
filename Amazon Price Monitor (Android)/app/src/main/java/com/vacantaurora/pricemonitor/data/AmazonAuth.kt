package com.vacantaurora.pricemonitor.data

import android.webkit.CookieManager

/**
 * Login state derived from Amazon cookies. Mirrors the iOS AmazonAuth: a real
 * auth cookie (`at-main` / `sess-at-main`) must be present — `session-id` alone
 * is set for anonymous sessions and is intentionally ignored.
 */
object AmazonAuth {
    fun isLoggedIn(): Boolean {
        val cookies = CookieManager.getInstance()
            .getCookie("https://www.amazon.com.br") ?: return false
        return cookies.split(";")
            .map { it.trim().substringBefore('=') }
            .any { it == "at-main" || it == "sess-at-main" }
    }
}
