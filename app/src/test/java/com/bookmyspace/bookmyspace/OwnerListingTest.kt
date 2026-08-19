package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.CustomerSection
import com.bookmyspace.bookmyspace.data.model.CustomerSectionCatalog
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class OwnerListingTest {

    @Test
    fun ownerCategoriesExcludeAllChipAndStayInsideSection() {
        CustomerSection.entries.forEach { section ->
            val cats = CustomerSectionCatalog.ownerCategories(section)
            assertTrue(cats.none { it.id == "all" })
            cats.forEach { category ->
                assertEquals(section, CustomerSection.fromAny(category.id) ?: section)
            }
        }
    }

    @Test
    fun lodgeAndPgUseMeetingRoomWhenOnlyBaseCategoriesExist() {
        val baseOnly = listOf(
            com.bookmyspace.bookmyspace.data.model.VenueCategory("fh", "function_hall", "Function Hall"),
            com.bookmyspace.bookmyspace.data.model.VenueCategory("mr", "meeting_room", "Meeting Room"),
            com.bookmyspace.bookmyspace.data.model.VenueCategory("sg", "sports_ground", "Sports Ground")
        )
        val lodgeSlug = CustomerSectionCatalog.resolveOwnerCategorySlug(
            baseOnly,
            CustomerSection.LODGE_ROOMS,
            "hotel"
        )
        assertEquals("meeting_room", lodgeSlug)
        assertEquals(null, CustomerSection.fromAny(lodgeSlug))

        val pgSlug = CustomerSectionCatalog.resolveOwnerCategorySlug(
            baseOnly,
            CustomerSection.PG_HOSTELS,
            "ladies_pg"
        )
        assertEquals("meeting_room", pgSlug)
    }

    @Test
    fun persistableSlugNeverCrossesSections() {
        assertEquals(
            CustomerSection.FUNCTION_HALLS,
            CustomerSection.fromAny(
                CustomerSectionCatalog.persistableCategorySlug(
                    CustomerSection.FUNCTION_HALLS,
                    "banquet_hall"
                )
            )
        )
        assertEquals(
            CustomerSection.LODGE_ROOMS,
            CustomerSection.fromAny(
                CustomerSectionCatalog.persistableCategorySlug(
                    CustomerSection.LODGE_ROOMS,
                    "guest_house"
                )
            )
        )
        assertEquals(
            CustomerSection.PG_HOSTELS,
            CustomerSection.fromAny(
                CustomerSectionCatalog.persistableCategorySlug(
                    CustomerSection.PG_HOSTELS,
                    "ladies_pg"
                )
            )
        )
        assertEquals(
            CustomerSection.INSTITUTES_CLASSES,
            CustomerSection.fromAny(
                CustomerSectionCatalog.persistableCategorySlug(
                    CustomerSection.INSTITUTES_CLASSES,
                    "dance_academy"
                )
            )
        )
    }

    @Test
    fun createAndPublishStayInSelectedSection() {
        val created = BookMySpaceRepository.createOwnerVenue(
            name = "Starlight Ladies PG",
            categorySlug = "ladies_pg",
            description = "Ladies PG near campus",
            address = "Madhapur",
            city = "Hyderabad",
            price = 9000.0,
            imageUrls = listOf("https://example.com/cover.jpg", "https://example.com/room.jpg"),
            latitude = 17.45,
            longitude = 78.39,
            capacity = 12,
            isActive = false,
            facilities = listOf("Ladies PG", "Wi-Fi")
        )

        assertFalse(created.isActive)
        assertEquals(CustomerSection.PG_HOSTELS, CustomerSectionCatalog.sectionForVenue(created))
        assertFalse(CustomerSectionCatalog.matchesVenue(created, CustomerSection.FUNCTION_HALLS))
        assertEquals(2, created.images.size)
        assertTrue(created.images.first().isCover)

        val published = BookMySpaceRepository.setVenuePublished(created.id, true)
        assertTrue(published.isActive)
        assertTrue(
            BookMySpaceRepository.venuesForCustomerSection(CustomerSection.PG_HOSTELS)
                .any { it.id == created.id }
        )

        BookMySpaceRepository.setVenuePublished(created.id, false)
        assertFalse(
            BookMySpaceRepository.venuesForCustomerSection(CustomerSection.PG_HOSTELS)
                .any { it.id == created.id }
        )
    }

    @Test
    fun persistPhotoStreamWritesLocalFileUri() {
        val dest = File.createTempFile("owner-photo", ".jpg")
        dest.deleteOnExit()
        val uri = BookMySpaceRepository.copyOwnerPhotoStream(
            "gallery-bytes".byteInputStream(),
            dest
        )
        assertTrue(uri.startsWith("file:"))
        assertEquals("gallery-bytes", dest.readText())
    }

    @Test
    fun deleteListingRemovesItFromOwnerInventory() {
        val created = BookMySpaceRepository.createOwnerVenue(
            name = "Temp Hall",
            categorySlug = "marriage_hall",
            description = "Hall to delete",
            address = "Banjara Hills",
            city = "Hyderabad",
            price = 20000.0,
            isActive = false
        )
        assertTrue(BookMySpaceRepository.venues.value.any { it.id == created.id })
        BookMySpaceRepository.deleteOwnerVenue(created.id)
        assertFalse(BookMySpaceRepository.venues.value.any { it.id == created.id })
    }

    @Test
    fun instituteListingIsAdvertisingOnly() {
        val created = BookMySpaceRepository.createOwnerVenue(
            name = "CodeLab Academy",
            categorySlug = "computer_it",
            description = "Coding classes",
            address = "Gachibowli",
            city = "Hyderabad",
            price = 2500.0,
            isActive = true,
            facilities = listOf("Computer & IT Classes")
        )
        assertEquals(
            CustomerSection.INSTITUTES_CLASSES,
            CustomerSectionCatalog.sectionForVenue(created)
        )
        assertFalse(CustomerSection.INSTITUTES_CLASSES.isBookable)
        assertTrue(created.timeSlots.isEmpty())
    }

    @Test
    fun wrongSectionSlugIsRejected() {
        try {
            BookMySpaceRepository.createOwnerVenue(
                name = "Cowork",
                categorySlug = "coworking_space",
                description = "Desks",
                address = "Hitech",
                city = "Hyderabad",
                price = 500.0
            )
            throw AssertionError("Expected coworking create to fail")
        } catch (ex: IllegalStateException) {
            assertTrue(ex.message!!.contains("Function Hall"))
        }
    }
}
