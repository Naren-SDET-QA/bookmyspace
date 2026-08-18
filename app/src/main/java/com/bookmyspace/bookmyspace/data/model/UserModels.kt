package com.bookmyspace.bookmyspace.data.model

enum class UserRole {
    USER,
    VENUE_OWNER,
    ADMIN
}

data class AuthUser(
    val id: String,
    val email: String,
    val fullName: String,
    val phone: String = "",
    val role: UserRole = UserRole.USER,
    val avatarUrl: String = "",
    val isEmailVerified: Boolean = true
)

data class PendingEmailVerification(
    val email: String,
    val fullName: String,
    val passwordHash: String = "",
    val verificationCode: String,
    val sentAt: Long = System.currentTimeMillis(),
    val expiresAt: Long = System.currentTimeMillis() + (10 * 60 * 1000)
)

data class PendingPasswordReset(
    val email: String,
    val resetToken: String,
    val sentAt: Long = System.currentTimeMillis(),
    val expiresAt: Long = System.currentTimeMillis() + (15 * 60 * 1000)
)

data class AuthState(
    val user: AuthUser? = null,
    val isAuthenticated: Boolean = false,
    val isLoading: Boolean = false
)

data class QuickBookPreferences(
    val preferredLocation: String = "Jubilee Hills, Hyderabad",
    val preferredCapacity: Int = 150,
    val preferredEventType: String = "Birthday Party",
    val preferredBudgetMax: Double = 50000.0,
    val isQuickBookEnabled: Boolean = true
)

enum class ReferralStatus {
    PENDING,
    COMPLETED
}

data class ReferralItem(
    val id: String,
    val friendName: String,
    val friendEmail: String,
    val dateInvited: String,
    val status: ReferralStatus = ReferralStatus.PENDING,
    val creditEarned: Double = 500.0
)

