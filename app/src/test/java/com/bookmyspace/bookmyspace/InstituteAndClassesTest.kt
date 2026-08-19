package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class InstituteAndClassesTest {

    private val testOwnerId = "usr_test_owner_999"

    @Before
    fun setup() {
        // Reset or prepare test states
    }

    @Test
    fun testPlanPurchaseAndSubscriptionUnlock() {
        // Initially unsubscribed
        assertFalse(BookMySpaceRepository.hasActiveListingPlan(testOwnerId))

        // Purchase Plan
        val purchaseSuccess = BookMySpaceRepository.purchaseInstituteListingPlan(
            ownerId = testOwnerId,
            planTier = InstituteListingPlanTier.GROWTH_PRO,
            paymentId = "pay_test_rzp_9999"
        )
        assertTrue(purchaseSuccess)
        assertTrue(BookMySpaceRepository.hasActiveListingPlan(testOwnerId))

        val retrievedSub = BookMySpaceRepository.getOwnerSubscription(testOwnerId)
        assertEquals(InstituteListingPlanTier.GROWTH_PRO, retrievedSub?.planTier)
        assertEquals("pay_test_rzp_9999", retrievedSub?.paymentId)
        assertTrue(retrievedSub?.isActive == true)
    }

    @Test
    fun testInstituteProfileAndFacultyCrud() {
        // Ensure subscribed
        BookMySpaceRepository.setListingPlanForTesting(testOwnerId, InstituteListingPlanTier.STARTER)
        assertTrue(BookMySpaceRepository.hasActiveListingPlan(testOwnerId))

        // Create Institute
        val profile = InstituteProfile(
            id = "",
            ownerId = testOwnerId,
            name = "Champion Tennis & Squash Academy",
            description = "Top rated sports training academy",
            logoUrl = "https://images.unsplash.com/photo-1",
            imageUrls = listOf("https://images.unsplash.com/photo-2", "https://images.unsplash.com/photo-3"),
            phone = "+91 9876543210",
            whatsapp = "+91 9876543210",
            address = "Road No 36, Jubilee Hills",
            city = "Hyderabad",
            categories = listOf("Sports & Fitness", "Tennis")
        )

        val saveRes = BookMySpaceRepository.saveInstituteProfile(testOwnerId, profile)
        assertTrue(saveRes.isSuccess)
        val createdInst = saveRes.getOrNull()
        assertNotNull(createdInst)
        assertTrue(createdInst!!.id.isNotBlank())
        assertEquals("Champion Tennis & Squash Academy", createdInst.name)

        // Add Faculty
        val coach = FacultyMember(
            id = "",
            name = "Coach Rajesh Kumar",
            qualification = "ITF Level 2 Certified",
            experienceYears = 10,
            subjectOrSpecialization = "Junior & Pro Tennis",
            bio = "Coached state level champions"
        )
        val facRes = BookMySpaceRepository.addOrUpdateFaculty(testOwnerId, createdInst.id, coach)
        assertTrue(facRes.isSuccess)

        // Verify institute contains faculty
        val updatedInst = BookMySpaceRepository.institutes.value.find { it.id == createdInst.id }
        assertNotNull(updatedInst)
        assertEquals(1, updatedInst!!.facultyMembers.size)
        assertEquals("Coach Rajesh Kumar", updatedInst.facultyMembers[0].name)

        // Delete Faculty
        val facId = updatedInst.facultyMembers[0].id
        val delSuccess = BookMySpaceRepository.deleteFaculty(testOwnerId, createdInst.id, facId)
        assertTrue(delSuccess)
        val instAfterDelete = BookMySpaceRepository.institutes.value.find { it.id == createdInst.id }
        assertEquals(0, instAfterDelete?.facultyMembers?.size)
    }

    @Test
    fun testClassCreationEditingAndPublishStatusLifecycle() {
        BookMySpaceRepository.setListingPlanForTesting(testOwnerId, InstituteListingPlanTier.ENTERPRISE)

        val newClass = InstituteClass(
            id = "",
            instituteId = "inst_001",
            ownerId = testOwnerId,
            title = "Weekend Smash Badminton Coaching",
            category = "Sports & Fitness",
            description = "Comprehensive badminton batch for beginners and intermediate players.",
            imageUrls = listOf("https://images.unsplash.com/photo-court"),
            facultyName = "Coach Sandeep",
            daysOfWeek = listOf("Sat", "Sun"),
            startTime = "07:00 AM",
            endTime = "09:00 AM",
            durationText = "2 Hours",
            feeAmount = 2500.0,
            feeBillingCycle = "per month",
            deliveryMode = ClassDeliveryMode.OFFLINE,
            location = "Smash Arena, Gachibowli",
            contactPhone = "+91 9988776655",
            contactWhatsapp = "+91 9988776655",
            status = ClassPublishStatus.PUBLISHED
        )

        val saveRes = BookMySpaceRepository.saveClass(testOwnerId, newClass)
        assertTrue(saveRes.isSuccess)
        val saved = saveRes.getOrNull()
        assertNotNull(saved)
        assertTrue(saved!!.id.isNotBlank())
        assertEquals(ClassPublishStatus.PUBLISHED, saved.status)
        assertTrue(saved.isPublished)

        // Search test - Student should find it
        val searchResults = BookMySpaceRepository.searchClasses("Badminton", "All", null)
        assertTrue(searchResults.any { it.id == saved.id })

        // Pause Class
        val pauseSuccess = BookMySpaceRepository.pauseClass(testOwnerId, saved.id)
        assertTrue(pauseSuccess)
        val pausedClass = BookMySpaceRepository.instituteClasses.value.find { it.id == saved.id }
        assertEquals(ClassPublishStatus.PAUSED, pausedClass?.status)
        assertTrue(pausedClass?.isPaused == true)

        // Student search should NOT show paused classes
        val searchAfterPause = BookMySpaceRepository.searchClasses("Badminton", "All", null)
        assertFalse(searchAfterPause.any { it.id == saved.id })

        // Unpause Class
        val unpauseSuccess = BookMySpaceRepository.unpauseClass(testOwnerId, saved.id)
        assertTrue(unpauseSuccess)
        val unpausedClass = BookMySpaceRepository.instituteClasses.value.find { it.id == saved.id }
        assertEquals(ClassPublishStatus.PUBLISHED, unpausedClass?.status)

        // Edit Class Title and Fee
        val updatedDetails = unpausedClass!!.copy(
            title = "Weekend Smash Pro Badminton Coaching (Advanced)",
            feeAmount = 3500.0
        )
        val updateRes = BookMySpaceRepository.saveClass(testOwnerId, updatedDetails)
        assertTrue(updateRes.isSuccess)
        val finalClass = BookMySpaceRepository.instituteClasses.value.find { it.id == saved.id }
        assertEquals("Weekend Smash Pro Badminton Coaching (Advanced)", finalClass?.title)
        assertEquals(3500.0, finalClass?.feeAmount ?: 0.0, 0.01)

        // Delete Class
        val delSuccess = BookMySpaceRepository.deleteClass(testOwnerId, saved.id)
        assertTrue(delSuccess)
        assertNull(BookMySpaceRepository.instituteClasses.value.find { it.id == saved.id })
    }

    @Test
    fun testStudentSearchFiltering() {
        val mathClass = BookMySpaceRepository.searchClasses("Python", "All", null)
        assertTrue(mathClass.isNotEmpty())
        assertEquals("Tech & Coding", mathClass[0].category)

        // Filter by Mode
        val onlineOnly = BookMySpaceRepository.searchClasses("", "All", ClassDeliveryMode.ONLINE)
        assertTrue(onlineOnly.all { it.deliveryMode == ClassDeliveryMode.ONLINE })

        val offlineOnly = BookMySpaceRepository.searchClasses("", "All", ClassDeliveryMode.OFFLINE)
        assertTrue(offlineOnly.all { it.deliveryMode == ClassDeliveryMode.OFFLINE })
    }

    @Test
    fun testCreatePayPublishExpiryAndRenewalLifecycle() {
        val ownerId = "usr_lifecycle_${System.currentTimeMillis()}"
        val draft = InstituteProfile(
            id = "", ownerId = ownerId, name = "Lifecycle Academy",
            phone = "+91 9000000000", whatsapp = "+91 9000000000", isPublished = true
        )

        val saved = BookMySpaceRepository.saveInstituteProfile(ownerId, draft).getOrThrow()
        assertFalse("Unpaid listings must remain hidden", saved.isPublished)
        assertFalse(BookMySpaceRepository.getPublishedInstitutes().any { it.id == saved.id })

        BookMySpaceRepository.purchaseInstituteListingPlan(
            ownerId, InstituteListingPlanTier.STARTER, "pay_lifecycle_1", "idem_lifecycle_1"
        )
        assertEquals("Active", BookMySpaceRepository.getOwnerListingStatus(ownerId))
        assertTrue(BookMySpaceRepository.getPublishedInstitutes().any { it.id == saved.id })

        BookMySpaceRepository.cancelOrExpireListingPlanForTesting(ownerId)
        assertEquals("Expired", BookMySpaceRepository.getOwnerListingStatus(ownerId))
        assertFalse(BookMySpaceRepository.getPublishedInstitutes().any { it.id == saved.id })

        BookMySpaceRepository.purchaseInstituteListingPlan(
            ownerId, InstituteListingPlanTier.GROWTH_PRO, "pay_lifecycle_2", "idem_lifecycle_2"
        )
        assertEquals("Active", BookMySpaceRepository.getOwnerListingStatus(ownerId))
        assertTrue(BookMySpaceRepository.getPublishedInstitutes().any { it.id == saved.id })
    }
}
