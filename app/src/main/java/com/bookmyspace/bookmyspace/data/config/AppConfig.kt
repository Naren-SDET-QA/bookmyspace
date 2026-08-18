package com.bookmyspace.bookmyspace.data.config

import com.bookmyspace.bookmyspace.BuildConfig

object AppConfig {
    val supabaseUrl: String = BuildConfig.SUPABASE_URL
    val supabasePublishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY
    val razorpayKeyId: String = BuildConfig.RAZORPAY_KEY_ID
    const val projectRef: String = "zykxneztahxbjduagutv"
    const val expectedProjectName: String = "bookmyspace-dev"

    val isDevConfigured: Boolean
        get() = supabaseUrl.contains("zykxneztahxbjduagutv") && supabasePublishableKey.startsWith("sb_publishable_")
}
