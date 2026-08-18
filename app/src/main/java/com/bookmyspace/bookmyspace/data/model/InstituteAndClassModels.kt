package com.bookmyspace.bookmyspace.data.model

/**
 * Institute Listing Subscription Plans
 */
enum class InstituteListingPlanTier(
    val planId: String,
    val title: String,
    val price: Double,
    val durationDays: Int,
    val maxClasses: Int,
    val maxPhotos: Int,
    val badge: String,
    val description: String,
    val features: List<String>
) {
    STARTER(
        planId = "plan_starter_monthly",
        title = "Starter Academy",
        price = 999.0,
        durationDays = 30,
        maxClasses = 5,
        maxPhotos = 6,
        badge = "Basic",
        description = "Ideal for independent tutors & boutique sports coaches.",
        features = listOf(
            "Post up to 5 Active Classes",
            "Upload up to 6 Institute Photos",
            "1-Tap Student Call & WhatsApp Leads",
            "Standard City Search Placement",
            "Basic Analytics & Inquiries"
        )
    ),
    GROWTH_PRO(
        planId = "plan_pro_quarterly",
        title = "Growth Pro",
        price = 2499.0,
        durationDays = 90,
        maxClasses = 15,
        maxPhotos = 15,
        badge = "Most Popular",
        description = "For established sports academies, dance studios & institutes.",
        features = listOf(
            "Post up to 15 Active Classes",
            "Upload up to 15 Photos & Faculty Profiles",
            "Verified Academy Badge ✓",
            "Priority Search & Category Ranking",
            "1-Tap Call, WhatsApp & Google Maps",
            "Lead Alerts & WhatsApp Notifications"
        )
    ),
    ENTERPRISE(
        planId = "plan_enterprise_yearly",
        title = "Enterprise / Premium",
        price = 4999.0,
        durationDays = 365,
        maxClasses = 50,
        maxPhotos = 30,
        badge = "Best Value",
        description = "For multi-branch academies, premium coaching & large institutions.",
        features = listOf(
            "Unlimited / Up to 50 Active Classes",
            "Unlimited Faculty & Photo Galleries",
            "Top Featured Badge on Home & Search",
            "Instant Webhook & Idempotent Billing",
            "Dedicated Support & Profile Verification",
            "Zero Lead Commission"
        )
    )
}

/**
 * Subscription record for an Institute Owner
 */
data class InstituteListingSubscription(
    val ownerId: String,
    val planTier: InstituteListingPlanTier,
    val paymentId: String,
    val startDate: Long = System.currentTimeMillis(),
    val expiryDate: Long = System.currentTimeMillis() + (planTier.durationDays * 24L * 3600L * 1000L),
    val isActive: Boolean = true,
    val idempotencyKey: String = "idemp_${System.currentTimeMillis()}_${ownerId.take(4)}"
) {
    val isExpired: Boolean
        get() = System.currentTimeMillis() > expiryDate
}

/**
 * Faculty or Coach profile associated with an Institute
 */
data class FacultyMember(
    val id: String,
    val name: String,
    val qualification: String = "",
    val experienceYears: Int = 0,
    val subjectOrSpecialization: String = "",
    val photoUrl: String = "",
    val bio: String = ""
)

/**
 * Delivery mode for classes
 */
enum class ClassDeliveryMode(val label: String, val shortBadge: String) {
    OFFLINE("Offline (In-Person)", "In-Person"),
    ONLINE("Online (Live Sessions)", "Online Live"),
    HYBRID("Hybrid (Online + Offline)", "Hybrid")
}

/**
 * Publishing status for classes
 */
enum class ClassPublishStatus(val label: String) {
    PUBLISHED("Published"),
    PAUSED("Paused"),
    DRAFT("Draft")
}

/**
 * Class / Batch item posted by an Institute Owner
 */
data class InstituteClass(
    val id: String,
    val instituteId: String,
    val instituteName: String = "",
    val ownerId: String,
    val title: String,
    val category: String, // e.g. "Sports & Fitness", "Music & Arts", "Academics", "Dance", "Coding & Tech", "Martial Arts"
    val description: String = "",
    val imageUrls: List<String> = emptyList(),
    val facultyId: String? = null,
    val facultyName: String = "",
    val daysOfWeek: List<String> = emptyList(), // e.g. ["Mon", "Wed", "Fri"]
    val startTime: String = "", // e.g. "06:00 PM"
    val endTime: String = "", // e.g. "07:30 PM"
    val durationText: String = "", // e.g. "90 mins"
    val feeAmount: Double = 0.0,
    val feeBillingCycle: String = "per month", // "per month", "per batch", "per hour", "full course"
    val deliveryMode: ClassDeliveryMode = ClassDeliveryMode.OFFLINE,
    val location: String = "",
    val contactPhone: String = "",
    val contactWhatsapp: String = "",
    val status: ClassPublishStatus = ClassPublishStatus.PUBLISHED,
    val locationHierarchy: LocationHierarchy? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
) {
    val isPublished: Boolean get() = status == ClassPublishStatus.PUBLISHED
    val isPaused: Boolean get() = status == ClassPublishStatus.PAUSED
}

/**
 * Institute / Academy Profile
 */
data class InstituteProfile(
    val id: String,
    val ownerId: String,
    val name: String,
    val logoUrl: String = "",
    val imageUrls: List<String> = emptyList(),
    val description: String = "",
    val categories: List<String> = emptyList(),
    val facultyMembers: List<FacultyMember> = emptyList(),
    val phone: String = "",
    val whatsapp: String = "",
    val address: String = "",
    val city: String = "Bangalore",
    val state: String = "Karnataka",
    val latitude: Double = 12.9716,
    val longitude: Double = 77.5946,
    val websiteUrl: String = "",
    val instagramUrl: String = "",
    val isVerified: Boolean = true,
    val isPublished: Boolean = true,
    val locationHierarchy: LocationHierarchy? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)
