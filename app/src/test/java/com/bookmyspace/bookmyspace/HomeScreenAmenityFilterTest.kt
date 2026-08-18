package com.bookmyspace.bookmyspace

import android.content.Context
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.test.core.app.ApplicationProvider
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.screens.HomeScreen
import com.bookmyspace.bookmyspace.ui.theme.BookMySpaceTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class HomeScreenAmenityFilterTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private lateinit var context: Context

    @Before
    fun setUp() = runBlocking {
        context = ApplicationProvider.getApplicationContext<Context>()
        BookMySpaceRepository.init(context)
        BookMySpaceRepository.clearSelectedCustomerSection()
    }

    @Test
    fun testRepository_ContainsRichAmenityVenues() {
        val venues = BookMySpaceRepository.venues.value
        assertTrue("Venues list should not be empty", venues.isNotEmpty())

        val venuesWithChangingRooms = venues.filter { v ->
            v.facilities.any { it.facility.contains("Changing", ignoreCase = true) || it.facility.contains("Shower", ignoreCase = true) }
        }
        assertTrue("Should have venues with Changing Rooms", venuesWithChangingRooms.isNotEmpty())

        val venuesWithWifi = venues.filter { v ->
            v.facilities.any { it.facility.contains("Wi-Fi", ignoreCase = true) || it.facility.contains("Wifi", ignoreCase = true) }
        }
        assertTrue("Should have venues with Wi-Fi", venuesWithWifi.isNotEmpty())

        val venuesWithParking = venues.filter { v ->
            v.parkingCapacity > 0 || v.facilities.any { it.facility.contains("Parking", ignoreCase = true) }
        }
        assertTrue("Should have venues with Parking", venuesWithParking.isNotEmpty())
    }

    @OptIn(androidx.compose.animation.ExperimentalSharedTransitionApi::class)
    @Test
    fun testHomeScreen_FirstScreenShowsOnlyFourSections() {
        composeTestRule.setContent {
            BookMySpaceTheme {
                HomeScreen(
                    onNavigateToVenue = {},
                    onNavigateToSearch = {},
                    onNavigateToEvents = {},
                    onNavigateToCourses = {},
                    onNavigateToNotifications = {}
                )
            }
        }
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithTag("home_screen").assertExists()
        composeTestRule.onNodeWithText("Function Halls", substring = true).assertExists()
        composeTestRule.onNodeWithText("Lodge / Rooms", substring = true).assertExists()
        composeTestRule.onNodeWithText("PG / Hostels", substring = true).assertExists()
        composeTestRule.onNodeWithText("Institutes / Classes", substring = true).assertExists()
        composeTestRule.onNodeWithText("Royal Grand Convention", substring = true).assertDoesNotExist()
        composeTestRule.onNodeWithText("UrbanNest", substring = true).assertDoesNotExist()
        composeTestRule.onNodeWithText("Choose Category").assertDoesNotExist()
    }

    @OptIn(androidx.compose.animation.ExperimentalSharedTransitionApi::class)
    @Test
    fun testHomeScreen_RendersAmenityFilterChips() {
        composeTestRule.setContent {
            BookMySpaceTheme {
                HomeScreen(
                    onNavigateToVenue = {},
                    onNavigateToSearch = {},
                    onNavigateToEvents = {},
                    onNavigateToCourses = {},
                    onNavigateToNotifications = {},
                    initialSelectedSection = com.bookmyspace.bookmyspace.ui.screens.MainHomeSection.FUNCTION_HALLS
                )
            }
        }
        composeTestRule.waitForIdle()

        // Scroll to amenity chips container inside home LazyColumn
        composeTestRule.onNodeWithTag("home_screen").performScrollToNode(hasTestTag("home_amenity_filter_chips_row"))
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithTag("home_amenity_filter_chips_row").assertExists()
        composeTestRule.onNodeWithTag("amenity_filter_chip_parking").assertExists()
        composeTestRule.onNodeWithTag("amenity_filter_chip_wifi").assertExists()
        composeTestRule.onNodeWithTag("amenity_filter_chip_changing_rooms").assertExists()

        // Toggle changing rooms chip
        composeTestRule.onNodeWithTag("amenity_filter_chip_changing_rooms").performClick()
        composeTestRule.waitForIdle()
    }

    @Test
    fun testVenueFilterBottomSheet_RendersAndTogglesAmenitiesWithAnimation() {
        var appliedMinPrice = 0f
        var appliedMaxPrice = 10000f
        var appliedMinRating = 0f
        var appliedAmenities = emptySet<String>()

        composeTestRule.setContent {
            BookMySpaceTheme {
                com.bookmyspace.bookmyspace.ui.components.VenueFilterContent(
                    initialMinPrice = 0f,
                    initialMaxPrice = 10000f,
                    initialMinRating = 0f,
                    initialSelectedAmenities = emptySet(),
                    maxPriceLimit = 10000f,
                    matchingVenuesCount = 5,
                    onDismissRequest = {},
                    onApplyFilters = { minP, maxP, minR, amenities ->
                        appliedMinPrice = minP
                        appliedMaxPrice = maxP
                        appliedMinRating = minR
                        appliedAmenities = amenities
                    },
                    onResetFilters = {}
                )
            }
        }
        composeTestRule.waitForIdle()

        // Verify Sheet Content and Amenity Chips
        composeTestRule.onNodeWithTag("venue_filter_content_container").assertIsDisplayed()
        composeTestRule.onNodeWithTag("amenity_chip_wifi").performScrollTo().assertIsDisplayed()
        composeTestRule.onNodeWithTag("amenity_chip_parking").performScrollTo().assertIsDisplayed()

        // Toggle Wi-Fi amenity chip
        composeTestRule.onNodeWithTag("amenity_chip_wifi").performScrollTo().performClick()
        composeTestRule.waitForIdle()

        // Apply filters
        composeTestRule.onNodeWithTag("apply_venue_filters_button").performClick()
        composeTestRule.waitForIdle()

        assertTrue("Wi-Fi amenity should be applied", appliedAmenities.contains("wifi"))
    }
}
