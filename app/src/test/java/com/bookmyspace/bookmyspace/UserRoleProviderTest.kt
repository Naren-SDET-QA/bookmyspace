package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.auth.UserRoleProvider
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.screens.ProfileActionItem
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.Tune
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class UserRoleProviderTest {

    @Before
    fun setUp() {
        BookMySpaceRepository.logout()
    }

    @Test
    fun testUserRoleProvider_RoleStateReflectsAuthUser() {
        // Customer login
        BookMySpaceRepository.loginWithEmailAndPassword("customer.dev@bookmyspace.app", "user123")
        assertEquals(UserRole.USER, UserRoleProvider.currentRole)
        assertTrue(UserRoleProvider.isCustomer)
        assertFalse(UserRoleProvider.isOwner)
        assertFalse(UserRoleProvider.isAdmin)

        // Switch to Venue Owner
        UserRoleProvider.switchUserRole(UserRole.VENUE_OWNER)
        assertEquals(UserRole.VENUE_OWNER, UserRoleProvider.currentRole)
        assertFalse(UserRoleProvider.isCustomer)
        assertTrue(UserRoleProvider.isOwner)
        assertTrue(UserRoleProvider.hasOwnerPrivileges)
        assertFalse(UserRoleProvider.isAdmin)

        // Switch to Admin
        UserRoleProvider.switchUserRole(UserRole.ADMIN)
        assertEquals(UserRole.ADMIN, UserRoleProvider.currentRole)
        assertFalse(UserRoleProvider.isCustomer)
        assertTrue(UserRoleProvider.hasOwnerPrivileges)
        assertTrue(UserRoleProvider.isAdmin)
        assertTrue(UserRoleProvider.hasAdminPrivileges)
    }

    @Test
    fun testUserRoleProvider_FilterForRole_FiltersItemsAccurately() {
        val sampleItems = listOf(
            ProfileActionItem(
                id = "admin_audit",
                title = "Audit Trail",
                subtitle = null,
                icon = Icons.Default.AdminPanelSettings,
                targetRoles = setOf(UserRole.ADMIN),
                isFeatureEnabled = true,
                onClick = {}
            ),
            ProfileActionItem(
                id = "listing_fields",
                title = "Schema Engine",
                subtitle = null,
                icon = Icons.Default.Tune,
                targetRoles = setOf(UserRole.ADMIN),
                isFeatureEnabled = true,
                onClick = {}
            ),
            ProfileActionItem(
                id = "owner_portal",
                title = "Venue Owner Portal",
                subtitle = null,
                icon = Icons.Default.Storefront,
                targetRoles = setOf(UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = true,
                onClick = {}
            ),
            ProfileActionItem(
                id = "analytics",
                title = "Analytics",
                subtitle = null,
                icon = Icons.Default.Analytics,
                targetRoles = setOf(UserRole.USER, UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = true,
                onClick = {}
            ),
            ProfileActionItem(
                id = "support",
                title = "Help & Support",
                subtitle = null,
                icon = Icons.Default.HelpOutline,
                targetRoles = setOf(UserRole.USER, UserRole.VENUE_OWNER, UserRole.ADMIN),
                isFeatureEnabled = true,
                onClick = {}
            )
        )

        // Customer Role Filter
        val customerFiltered = UserRoleProvider.filterForRole(
            items = sampleItems,
            targetRoles = { it.targetRoles },
            isFeatureEnabled = { it.isFeatureEnabled },
            userRole = UserRole.USER
        )
        assertEquals(2, customerFiltered.size)
        assertTrue(customerFiltered.any { it.id == "analytics" })
        assertTrue(customerFiltered.any { it.id == "support" })
        assertFalse(customerFiltered.any { it.id == "admin_audit" })
        assertFalse(customerFiltered.any { it.id == "owner_portal" })

        // Owner Role Filter
        val ownerFiltered = UserRoleProvider.filterForRole(
            items = sampleItems,
            targetRoles = { it.targetRoles },
            isFeatureEnabled = { it.isFeatureEnabled },
            userRole = UserRole.VENUE_OWNER
        )
        assertEquals(3, ownerFiltered.size)
        assertTrue(ownerFiltered.any { it.id == "owner_portal" })
        assertTrue(ownerFiltered.any { it.id == "analytics" })
        assertTrue(ownerFiltered.any { it.id == "support" })
        assertFalse(ownerFiltered.any { it.id == "admin_audit" })

        // Admin Role Filter
        val adminFiltered = UserRoleProvider.filterForRole(
            items = sampleItems,
            targetRoles = { it.targetRoles },
            isFeatureEnabled = { it.isFeatureEnabled },
            userRole = UserRole.ADMIN
        )
        assertEquals(5, adminFiltered.size)
    }

    @Test
    fun testUserRoleProvider_RespectsFeatureToggles() {
        val instituteItem = ProfileActionItem(
            id = "institutes",
            title = "Institutes Directory",
            subtitle = null,
            icon = Icons.Default.School,
            targetRoles = setOf(UserRole.USER, UserRole.ADMIN),
            isFeatureEnabled = false, // Disabled via toggle
            onClick = {}
        )

        val result = UserRoleProvider.filterForRole(
            items = listOf(instituteItem),
            targetRoles = { it.targetRoles },
            isFeatureEnabled = { it.isFeatureEnabled },
            userRole = UserRole.ADMIN
        )
        assertTrue("Disabled feature item should be excluded even for Admin", result.isEmpty())
    }

    @Test
    fun testUserRoleProvider_DynamicMenuRecomputedOnLoginAndSwitchAccounts() {
        // Step 1: Customer Login
        BookMySpaceRepository.loginWithEmailAndPassword("customer.dev@bookmyspace.app", "user123")
        assertEquals(UserRole.USER, UserRoleProvider.currentRole)

        // Step 2: Switch to Venue Owner Account
        BookMySpaceRepository.loginWithEmailAndPassword("owner.dev@bookmyspace.app", "owner123")
        assertEquals(UserRole.VENUE_OWNER, UserRoleProvider.currentRole)
        assertTrue(UserRoleProvider.isOwner)
        assertTrue(UserRoleProvider.hasOwnerPrivileges)

        // Step 3: Switch to Admin Account
        BookMySpaceRepository.loginWithEmailAndPassword("admin.dev@bookmyspace.app", "admin123")
        assertEquals(UserRole.ADMIN, UserRoleProvider.currentRole)
        assertTrue(UserRoleProvider.isAdmin)
        assertTrue(UserRoleProvider.hasAdminPrivileges)

        // Step 4: Logout (defaults back to USER)
        BookMySpaceRepository.logout()
        assertEquals(UserRole.USER, UserRoleProvider.currentRole)
        assertTrue(UserRoleProvider.isCustomer)
    }
}
