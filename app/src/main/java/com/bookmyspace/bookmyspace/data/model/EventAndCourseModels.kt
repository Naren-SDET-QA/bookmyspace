package com.bookmyspace.bookmyspace.data.model

data class Event(
    val id: String,
    val title: String,
    val description: String,
    val venueName: String,
    val imageUrl: String,
    val eventDate: String,
    val timeSlot: String,
    val ticketPrice: Double,
    val totalSeats: Int,
    val seatsBooked: Int,
    val category: String,
    val isRegistered: Boolean = false
)

data class Course(
    val id: String,
    val title: String,
    val academyName: String,
    val coachName: String,
    val description: String,
    val imageUrl: String,
    val durationWeeks: Int,
    val price: Double,
    val level: String, // Beginner, Intermediate, Pro
    val schedule: String,
    val rating: Double,
    val totalEnrolled: Int,
    val isEnrolled: Boolean = false
)
