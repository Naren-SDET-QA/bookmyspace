plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.bookmyspace.bookmyspace"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.aistudio.bookmyspace.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "SUPABASE_URL", "\"https://zykxneztahxbjduagutv.supabase.co\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"sb_publishable_D3kAHDoTejg6FGSjEPXTWQ_wjoH3Hl5\"")
        buildConfigField("String", "RAZORPAY_KEY_ID", "\"rzp_test_TIVzop8X6CjVX9\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.androidx.navigation.compose)
    implementation("androidx.compose.animation:animation")

    // Room Persistence & Local Offline Database
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    // Performance Monitoring & Tracing
    implementation(libs.androidx.tracing)

    // WorkManager Background Task Scheduler
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    // Real OpenStreetMap / MapLibre tile engine
    implementation("org.osmdroid:osmdroid-android:6.1.18")

    // Coil Image Caching and Async Loading
    implementation("io.coil-kt:coil-compose:2.7.0")

    // Razorpay SDK Integration
    implementation("com.razorpay:checkout:1.6.38")

    // Firebase Cloud Messaging (FCM)
    implementation("com.google.firebase:firebase-messaging-ktx:24.1.0")

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
