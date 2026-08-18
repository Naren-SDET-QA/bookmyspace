package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.CustomerSection
import com.bookmyspace.bookmyspace.data.model.CustomerSectionCatalog
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class CustomerSectionCatalogTest {

    @Before
    fun setUp() {
        BookMySpaceRepository.clearSelectedCustomerSection()
    }

    @Test
    fun catalogHasExactlyFourCustomerSections() {
        assertEquals(4, CustomerSection.entries.size)
        assertEquals(
            listOf("function_halls", "lodge_rooms", "pg_hostels", "institutes_classes"),
            CustomerSection.entries.map { it.id }
        )
    }

    @Test
    fun hallSectionDoesNotIncludeLodgePgOrSportsVenues() {
        val venues = BookMySpaceRepository.venues.value
        val halls = venues.filter {
            CustomerSectionCatalog.matchesVenue(it, CustomerSection.FUNCTION_HALLS)
        }
        assertTrue(halls.any { it.name.contains("Royal Grand", ignoreCase = true) })
        assertTrue(halls.any { it.name.contains("Emerald Bay", ignoreCase = true) })
        assertFalse(halls.any { it.pgDetails != null })
        assertFalse(halls.any { it.hotelDetails != null })
        assertFalse(halls.any { it.name.contains("Badminton", ignoreCase = true) })
        assertFalse(halls.any { it.name.contains("UrbanNest", ignoreCase = true) })
        assertFalse(halls.any { it.name.contains("Crown Imperial", ignoreCase = true) })
    }

    @Test
    fun lodgeSectionOnlyIncludesHotelStays() {
        val lodges = BookMySpaceRepository.venues.value.filter {
            CustomerSectionCatalog.matchesVenue(it, CustomerSection.LODGE_ROOMS)
        }
        assertTrue(lodges.isNotEmpty())
        assertTrue(lodges.all { it.hotelDetails != null || it.category?.slug == "hotel_stay" })
        assertFalse(lodges.any { it.pgDetails != null })
        assertFalse(lodges.any { CustomerSectionCatalog.sectionForVenue(it) == CustomerSection.FUNCTION_HALLS })
    }

    @Test
    fun pgSectionDoesNotIncludeHalls() {
        val pgs = BookMySpaceRepository.venues.value.filter {
            CustomerSectionCatalog.matchesVenue(it, CustomerSection.PG_HOSTELS)
        }
        assertTrue(pgs.any { it.name.contains("Ladies PG", ignoreCase = true) })
        assertFalse(pgs.any { it.name.contains("Convention", ignoreCase = true) })
        assertFalse(pgs.any { it.name.contains("Emerald Bay", ignoreCase = true) })
    }

    @Test
    fun ladiesPgCategoryDoesNotReturnGentsOrCoLivingOnlyBySlug() {
        val ladies = BookMySpaceRepository.venues.value.filter {
            CustomerSectionCatalog.matchesVenue(it, CustomerSection.PG_HOSTELS, "ladies_pg")
        }
        assertTrue(ladies.isNotEmpty())
        assertTrue(ladies.all { it.pgDetails?.pgType?.contains("Ladies", ignoreCase = true) == true })
    }

    @Test
    fun instituteSectionIncludesSportsVenuesNotHalls() {
        val sports = BookMySpaceRepository.venues.value.filter {
            CustomerSectionCatalog.matchesVenue(it, CustomerSection.INSTITUTES_CLASSES, "sports_academy")
        }
        assertTrue(sports.any { it.name.contains("Badminton", ignoreCase = true) })
        assertFalse(sports.any { it.name.contains("Function Hall", ignoreCase = true) })
    }

    @Test
    fun repositorySelectedSectionScopesVenueHelper() {
        BookMySpaceRepository.setSelectedCustomerSection(CustomerSection.PG_HOSTELS)
        val scoped = BookMySpaceRepository.venuesForCustomerSection()
        assertTrue(scoped.isNotEmpty())
        assertTrue(scoped.all { CustomerSectionCatalog.sectionForVenue(it) == CustomerSection.PG_HOSTELS })

        BookMySpaceRepository.clearSelectedCustomerSection()
        assertNull(BookMySpaceRepository.selectedCustomerSection.value)
        assertTrue(BookMySpaceRepository.venuesForCustomerSection().isEmpty())
    }

    @Test
    fun bookingLabelsStaySectionSpecific() {
        assertEquals("Book Now", CustomerSectionCatalog.bookingCtaLabel(CustomerSection.FUNCTION_HALLS))
        assertEquals("Book Stay", CustomerSectionCatalog.bookingCtaLabel(CustomerSection.LODGE_ROOMS))
        assertEquals("Reserve", CustomerSectionCatalog.bookingCtaLabel(CustomerSection.PG_HOSTELS))
        assertEquals("Enroll", CustomerSectionCatalog.bookingCtaLabel(CustomerSection.INSTITUTES_CLASSES))
        assertEquals("Book Hall Slot", CustomerSectionCatalog.bookingScreenTitle(CustomerSection.FUNCTION_HALLS))
        assertEquals("Reserve PG", CustomerSectionCatalog.bookingScreenTitle(CustomerSection.PG_HOSTELS))
    }
}
