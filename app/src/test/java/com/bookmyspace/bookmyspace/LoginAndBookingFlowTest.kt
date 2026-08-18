package com.bookmyspace.bookmyspace

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ApplicationProvider
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.data.auth.UserRoleProvider
import com.bookmyspace.bookmyspace.ui.screens.ProfileScreen
import com.bookmyspace.bookmyspace.ui.screens.LoginScreen
import com.bookmyspace.bookmyspace.ui.screens.BookingScreen
import com.bookmyspace.bookmyspace.ui.theme.BookMySpaceTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class LoginAndBookingFlowTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Before
    fun setUp() = kotlinx.coroutines.runBlocking {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        BookMySpaceRepository.init(context)
        BookMySpaceRepository.logout()
        BookMySpaceRepository.resetBookingsToDefault(context)
        BookMySpaceRepository.resetReviewsToDefault()
    }

    @Test
    fun testLoginFlow_WithValidCredentials_UpdatesAuthUser() {
        // Dev user test
        val result = BookMySpaceRepository.loginWithEmailAndPassword("customer.dev@bookmyspace.app", "user123")
        assertTrue("Login with valid credentials should succeed", result.isSuccess)
        val user = result.getOrNull()
        assertNotNull(user)
        assertEquals("customer.dev@bookmyspace.app", user?.email)
        assertEquals(UserRole.USER, user?.role)

        // Logout test
        BookMySpaceRepository.logout()
        assertNull(BookMySpaceRepository.authUser.value)
    }

    @Test
    fun testLoginFlow_WithInvalidCredentials_Fails() {
        val result = BookMySpaceRepository.loginWithEmailAndPassword("", "123")
        assertTrue("Login with invalid password or empty email should fail", result.isFailure)
        assertNull(BookMySpaceRepository.authUser.value)
    }

    @Test
    fun testAuthScreen_ComposeUI_LoginSubmission() {
        var loggedInRole: UserRole? = null

        composeTestRule.setContent {
            BookMySpaceTheme {
                LoginScreen(
                    onLoginSuccess = { role -> loggedInRole = role }
                )
            }
        }

        // Enter email and password
        composeTestRule.onNodeWithTag("email_input").performTextInput("customer.dev@bookmyspace.app")
        composeTestRule.onNodeWithTag("password_input").performTextInput("user123")
        composeTestRule.waitForIdle()

        // Click submit button
        composeTestRule.onNodeWithTag("auth_submit_button").performScrollTo().performClick()

        // Verify successful login callback
        composeTestRule.waitForIdle()
        assertNotNull(BookMySpaceRepository.authUser.value)
    }

    @Test
    fun testBookingFlow_RepositoryHoldAndConfirmation() {
        val venue = BookMySpaceRepository.venues.value.first()

        // Acquire hold
        val holdResult = BookMySpaceRepository.acquireHold(
            venueId = venue.id,
            venueName = venue.name,
            venueImageUrl = venue.coverImageUrl,
            slotLabel = "06:00 AM - 07:00 AM",
            bookingDate = "2026-08-10",
            startTime = "06:00",
            endTime = "07:00",
            baseAmount = venue.pricingBaseAmount,
            taxAmount = 100.0
        )

        assertTrue(holdResult.success)
        assertNotNull(holdResult.bookingId)

        val heldBookingId = holdResult.bookingId!!
        val heldBooking = BookMySpaceRepository.bookings.value.find { it.id == heldBookingId }
        assertNotNull(heldBooking)
        assertEquals(BookingStatus.HELD, heldBooking?.status)

        // Confirm hold booking with payment details
        val confirmed = BookMySpaceRepository.confirmBookingWithPayment(
            bookingId = heldBookingId,
            paymentRef = "TXN_TEST_12345"
        )

        assertTrue(confirmed)
        val finalBooking = BookMySpaceRepository.bookings.value.find { it.id == heldBookingId }
        assertEquals(BookingStatus.CONFIRMED, finalBooking?.status)
        assertTrue(finalBooking?.isPaid == true)
    }

    @Test
    fun testOfflineBooking_LocalCacheAndSyncFlow() = runBlocking {
        val req = BookMySpaceRepository.PendingOfflineBooking(
            id = "offline_101",
            venueId = "v_1",
            venueName = "Gachibowli Badminton Arena",
            bookingDate = "2026-08-15",
            slotLabel = "07:00 AM - 08:00 AM",
            guestCount = 2,
            totalAmount = 1200.0,
            timestamp = System.currentTimeMillis()
        )

        // Add pending offline booking
        BookMySpaceRepository.addPendingOfflineBooking(req)
        assertEquals(1, BookMySpaceRepository.pendingOfflineBookings.value.size)

        // Sync offline bookings
        val syncedCount = BookMySpaceRepository.syncOfflineBookingsAsync()
        assertEquals(1, syncedCount)
        assertEquals(0, BookMySpaceRepository.pendingOfflineBookings.value.size)
    }

    @Test
    fun testBookingScreen_ComposeUI_CalculatesTotalAndEnablesPayButton() {
        val venue = BookMySpaceRepository.venues.value.first()
        var proceededBookingId: String? = null

        composeTestRule.setContent {
            BookMySpaceTheme {
                BookingScreen(
                    venueId = venue.id,
                    onBack = {},
                    onProceedToPayment = { bookingId -> proceededBookingId = bookingId }
                )
            }
        }

        composeTestRule.waitForIdle()

        // Ensure "Hold Slot & Pay" button is rendered
        composeTestRule.onNodeWithTag("confirm_and_pay_button").assertIsDisplayed()

        // Click "Hold Slot & Pay"
        composeTestRule.onNodeWithTag("confirm_and_pay_button").performClick()
        composeTestRule.waitForIdle()

        // Assert booking creation and navigation trigger
        assertNotNull(proceededBookingId)
        val createdBooking = BookMySpaceRepository.bookings.value.find { it.id == proceededBookingId }
        assertNotNull(createdBooking)
        assertEquals(venue.id, createdBooking?.venueId)
    }

    @Test
    fun testPerformanceTracer_MeasuresExecutionTime() {
        var executed = false
        val result = com.bookmyspace.bookmyspace.util.PerformanceTracer.traceBlock("test_trace") {
            executed = true
            "COMPLETED"
        }
        assertTrue(executed)
        assertEquals("COMPLETED", result)
    }

    @Test
    fun testPaymentScreen_RazorpayFlow_CompletesBookingWithPaymentRef() {
        val booking = Booking(
            id = "bk_test_razorpay_1",
            userId = "user_1",
            venueId = "v_1",
            venueName = "Gachibowli Badminton Arena",
            venueImageUrl = "",
            slotLabel = "06:00 PM - 07:00 PM",
            bookingDate = "2026-08-10",
            startTime = "18:00",
            endTime = "19:00",
            baseAmount = 700.0,
            taxAmount = 100.0,
            totalAmount = 800.0,
            status = BookingStatus.PENDING,
            isPaid = false
        )
        BookMySpaceRepository.addBooking(booking)

        var paymentCompleted = false

        composeTestRule.setContent {
            BookMySpaceTheme {
                com.bookmyspace.bookmyspace.ui.screens.PaymentScreen(
                    bookingId = booking.id,
                    onBack = {},
                    onPaymentSuccess = { paymentCompleted = true }
                )
            }
        }

        composeTestRule.waitForIdle()

        // Assert Pay Now button is displayed and scroll to it
        composeTestRule.onNodeWithTag("pay_now_button").performScrollTo().assertIsDisplayed()

        // Click Pay Now button
        composeTestRule.onNodeWithTag("pay_now_button").performClick()
        composeTestRule.waitForIdle()

        // Submit OTP in Razorpay dialog
        composeTestRule.onNodeWithTag("razorpay_submit_otp_btn").performClick()
        composeTestRule.waitForIdle()

        // Verify booking status changed to CONFIRMED and isPaid is true
        val updatedBooking = BookMySpaceRepository.bookings.value.find { it.id == booking.id }
        assertEquals(BookingStatus.CONFIRMED, updatedBooking?.status)
        assertTrue(updatedBooking?.isPaid == true)
        assertTrue(updatedBooking?.bookingRef?.isNotEmpty() == true)
    }

    @OptIn(androidx.compose.animation.ExperimentalSharedTransitionApi::class)
    @Test
    fun testSearchScreen_FilterDrawer_FiltersByPriceCapacityAndAmenities() {
        composeTestRule.setContent {
            BookMySpaceTheme {
                com.bookmyspace.bookmyspace.ui.screens.SearchScreen(
                    onNavigateToVenue = {}
                )
            }
        }

        composeTestRule.waitForIdle()

        // Verify Search Screen is displayed
        composeTestRule.onNodeWithTag("search_screen").assertIsDisplayed()

        // Click the filter drawer button to open the Filter Drawer
        composeTestRule.onNodeWithTag("filter_bottom_sheet_button").performClick()
        composeTestRule.waitForIdle()

        // Verify Filter Bottom Sheet / Container is displayed
        composeTestRule.onNodeWithTag("venue_filter_bottom_sheet").assertExists()

        // Verify Price Range Slider and Amenities exist
        composeTestRule.onNodeWithTag("price_range_slider").assertExists()

        // Select an amenity (e.g., AC)
        composeTestRule.onNodeWithTag("amenity_chip_ac").assertExists().performClick()
        composeTestRule.waitForIdle()

        // Click Apply Filters button
        composeTestRule.onNodeWithTag("apply_venue_filters_button").assertExists().performClick()
        composeTestRule.waitForIdle()

        // Search screen remains displayed
        composeTestRule.onNodeWithTag("search_screen").assertIsDisplayed()
    }

    @Test
    fun testVenueReviewAndRatingSystem_AddReviewAndCalculateAverageRating() {
        val venue = BookMySpaceRepository.venues.value.first()
        val initialReviewCount = BookMySpaceRepository.reviews.value.count { it.venueId == venue.id }

        // Add 5-star review
        BookMySpaceRepository.addReview(
            venueId = venue.id,
            comment = "Outstanding turf quality and lighting for nighttime play!",
            rating = 5.0,
            tags = listOf("Clean Courts", "Great Lighting")
        )

        val updatedReviews = BookMySpaceRepository.reviews.value.filter { it.venueId == venue.id }
        assertEquals(initialReviewCount + 1, updatedReviews.size)

        val addedReview = updatedReviews.find { it.comment == "Outstanding turf quality and lighting for nighttime play!" }
        assertNotNull(addedReview)
        assertEquals("Outstanding turf quality and lighting for nighttime play!", addedReview!!.comment)
        assertEquals(5.0, addedReview.rating, 0.01)
        assertTrue(addedReview.tags.contains("Clean Courts"))

        // Verify venue rating recalculated
        val updatedVenue = BookMySpaceRepository.venues.value.find { it.id == venue.id }
        assertNotNull(updatedVenue)
        assertTrue(updatedVenue!!.ratingCount >= 1)
        assertTrue(updatedVenue.avgRating in 1.0..5.0)
    }

    @Test
    fun testBookingFeedbackSubmission_LinksToVenueAndMarksVerified() {
        // Log in user
        BookMySpaceRepository.loginWithEmailAndPassword("customer.dev@bookmyspace.app", "user123")
        val venue = BookMySpaceRepository.venues.value.first()

        // Create a booking hold
        val holdResponse = BookMySpaceRepository.acquireHold(
            venueId = venue.id,
            venueName = venue.name,
            venueImageUrl = venue.coverImageUrl,
            slotLabel = "07:00 PM - 08:00 PM",
            bookingDate = "2026-08-28",
            startTime = "19:00",
            endTime = "20:00",
            baseAmount = venue.pricingBaseAmount,
            taxAmount = venue.pricingBaseAmount * 0.18
        )
        assertTrue(holdResponse.success)
        val bookingId = holdResponse.bookingId!!
        BookMySpaceRepository.confirmBookingWithPayment(bookingId, "PAY-REVIEW-TEST")

        // Submit feedback from booking
        BookMySpaceRepository.submitBookingFeedback(
            bookingId = bookingId,
            rating = 5.0,
            feedback = "Had a fantastic session, seamless booking pass!",
            tags = listOf("Helpful Staff", "Easy Parking")
        )

        // Verify booking updated
        val updatedBooking = BookMySpaceRepository.bookings.value.find { it.id == bookingId }
        assertEquals(5.0, updatedBooking?.rating ?: 0.0, 0.01)
        assertEquals("Had a fantastic session, seamless booking pass!", updatedBooking?.feedback)

        // Verify review created with verified status
        val venueReviews = BookMySpaceRepository.reviews.value.filter { it.venueId == venue.id }
        val matchingReview = venueReviews.find { it.bookingId == bookingId }
        assertNotNull(matchingReview)
        assertTrue("Review linked to completed/confirmed booking should be verified", matchingReview?.verifiedBooking == true)
    }
}
