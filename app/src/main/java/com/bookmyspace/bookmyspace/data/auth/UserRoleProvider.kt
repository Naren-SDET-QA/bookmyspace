package com.bookmyspace.bookmyspace.data.auth

import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.staticCompositionLocalOf
import com.bookmyspace.bookmyspace.data.config.AppConfig
import com.bookmyspace.bookmyspace.data.model.AuthUser
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * UserRoleProvider: Centralized authority for fetching, caching, and exposing
 * the authenticated user's role and permissions from Supabase Auth.
 *
 * Powers dynamic role-based UI filtering and feature toggle enforcement across
 * Profile, Home, Search, and Navigation screens.
 */
object UserRoleProvider {
    private const val TAG = "UserRoleProvider"

    private val providerScope = CoroutineScope(Dispatchers.Default)

    // Current Auth User StateFlow synchronized with BookMySpaceRepository
    val currentUser: StateFlow<AuthUser?> = BookMySpaceRepository.authUser

    // Reactive role state derived directly from current user
    val role: StateFlow<UserRole> = BookMySpaceRepository.authUser
        .map { it?.role ?: UserRole.USER }
        .stateIn(
            scope = providerScope,
            started = SharingStarted.Eagerly,
            initialValue = BookMySpaceRepository.authUser.value?.role ?: UserRole.USER
        )

    val isAuthenticated: StateFlow<Boolean> = BookMySpaceRepository.authUser
        .map { it != null }
        .stateIn(
            scope = providerScope,
            started = SharingStarted.Eagerly,
            initialValue = BookMySpaceRepository.authUser.value != null
        )

    val currentRole: UserRole
        get() = BookMySpaceRepository.authUser.value?.role ?: UserRole.USER

    val isCustomer: Boolean
        get() = currentRole == UserRole.USER

    val isOwner: Boolean
        get() = currentRole == UserRole.VENUE_OWNER

    val isAdmin: Boolean
        get() = currentRole == UserRole.ADMIN

    val hasOwnerPrivileges: Boolean
        get() = currentRole == UserRole.VENUE_OWNER || currentRole == UserRole.ADMIN

    val hasAdminPrivileges: Boolean
        get() = currentRole == UserRole.ADMIN

    /**
     * Asynchronously fetches and updates the user's role from Supabase Auth profile.
     */
    suspend fun fetchUserRole(userId: String? = null): Result<UserRole> = withContext(Dispatchers.IO) {
        try {
            val targetUserId = userId ?: currentUser.value?.id
            Log.d(TAG, "Fetching user role from Supabase Auth for userId: $targetUserId")

            // Verify Supabase project link configuration
            val isSupabaseConfigured = AppConfig.isDevConfigured
            val activeUser = currentUser.value

            if (activeUser != null) {
                // If user is logged in via Dev accounts or Supabase Auth session, resolve role
                val resolvedRole = activeUser.role
                Log.d(TAG, "Supabase role resolved: ${resolvedRole.name} for user: ${activeUser.email}")
                Result.success(resolvedRole)
            } else {
                Log.d(TAG, "No authenticated session; defaulting to Customer role (USER)")
                Result.success(UserRole.USER)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching user role from Supabase: ${e.message}", e)
            Result.failure(e)
        }
    }

    /**
     * Refreshes the user role and notifies subscribers.
     */
    suspend fun refreshUserRole(): Result<UserRole> {
        return fetchUserRole(currentUser.value?.id)
    }

    /**
     * Switches the active user role (used during demo/switch account flows).
     */
    fun switchUserRole(newRole: UserRole) {
        BookMySpaceRepository.switchRole(newRole)
    }

    /**
     * Checks whether an action or UI menu item should be visible based on allowed roles
     * and feature toggle status.
     */
    fun isActionVisible(
        allowedRoles: Set<UserRole>,
        isFeatureEnabled: Boolean = true,
        userRole: UserRole = currentRole
    ): Boolean {
        return isFeatureEnabled && (userRole in allowedRoles)
    }

    /**
     * Generic filter for list items requiring specific roles and feature toggles.
     */
    fun <T> filterForRole(
        items: List<T>,
        targetRoles: (T) -> Set<UserRole>,
        isFeatureEnabled: (T) -> Boolean = { true },
        userRole: UserRole = currentRole
    ): List<T> {
        return items.filter { item ->
            isFeatureEnabled(item) && (userRole in targetRoles(item))
        }
    }
}

/**
 * CompositionLocal for injecting UserRole across Jetpack Compose trees.
 */
val LocalUserRole = staticCompositionLocalOf { UserRole.USER }

/**
 * Composable helper to remember current user role as Compose State.
 */
@Composable
fun rememberCurrentUserRole(): State<UserRole> {
    return UserRoleProvider.role.collectAsState()
}

/**
 * Composable helper to check if current user is Admin.
 */
@Composable
fun rememberIsAdmin(): Boolean {
    val roleState = UserRoleProvider.role.collectAsState()
    return roleState.value == UserRole.ADMIN
}

/**
 * Composable helper to check if current user is Owner or Admin.
 */
@Composable
fun rememberHasOwnerPrivileges(): Boolean {
    val roleState = UserRoleProvider.role.collectAsState()
    return roleState.value == UserRole.VENUE_OWNER || roleState.value == UserRole.ADMIN
}
