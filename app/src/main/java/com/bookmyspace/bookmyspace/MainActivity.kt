package com.bookmyspace.bookmyspace

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.map.DefaultMapConfiguration
import com.bookmyspace.bookmyspace.map.MapAndMarkerCacheManager
import com.bookmyspace.bookmyspace.ui.navigation.AppNavigation
import com.bookmyspace.bookmyspace.ui.theme.BookMySpaceTheme
import com.bookmyspace.bookmyspace.util.RazorpayHelper
import com.razorpay.Checkout
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener
import org.osmdroid.config.Configuration
import java.io.File

class MainActivity : ComponentActivity(), PaymentResultWithDataListener {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            Configuration.getInstance().apply {
                load(applicationContext, applicationContext.getSharedPreferences("osmdroid", MODE_PRIVATE))
                userAgentValue = DefaultMapConfiguration.DEFAULT_USER_AGENT
                osmdroidBasePath = applicationContext.cacheDir
                osmdroidTileCache = File(applicationContext.cacheDir, "osmdroid/tiles")
            }
            MapAndMarkerCacheManager.getInstance(applicationContext).runEvictionPolicy()
        } catch (e: Throwable) {
            e.printStackTrace()
        }
        try {
            if (!android.os.Build.FINGERPRINT.contains("generic") && !android.os.Build.MODEL.contains("sdk")) {
                Checkout.preload(applicationContext)
            }
        } catch (e: Throwable) {
            e.printStackTrace()
        }
        BookMySpaceRepository.init(applicationContext)
        enableEdgeToEdge()
        setContent {
            val themeMode by BookMySpaceRepository.themeMode.collectAsState()
            val selectedThemePreset by BookMySpaceRepository.selectedThemePreset.collectAsState()
            val customPrimaryColorHex by BookMySpaceRepository.customPrimaryColorHex.collectAsState()

            BookMySpaceTheme(
                themeMode = themeMode,
                themePreset = selectedThemePreset,
                customPrimaryHex = customPrimaryColorHex
            ) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    AppNavigation()
                }
            }
        }
    }

    override fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        RazorpayHelper.handlePaymentSuccess(razorpayPaymentId, paymentData)
    }

    override fun onPaymentError(code: Int, response: String?, paymentData: PaymentData?) {
        RazorpayHelper.handlePaymentError(code, response, paymentData)
    }
}
