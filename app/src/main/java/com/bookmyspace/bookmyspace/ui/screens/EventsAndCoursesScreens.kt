package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.CourseCard
import com.bookmyspace.bookmyspace.ui.components.EventCard

@Composable
fun EventsScreen() {
    val events by BookMySpaceRepository.events.collectAsState()

    Column(modifier = Modifier.fillMaxSize()) {
        Surface(
            color = MaterialTheme.colorScheme.primaryContainer,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text("Sports Tournaments & Events", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Join local leagues, open championships and friendly matches", fontSize = 12.sp)
            }
        }

        LazyColumn(
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(events) { event ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(event.title, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text("🏟️ ${event.venueName}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(event.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Entry Fee: ₹${event.ticketPrice.toInt()}", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                            Button(
                                onClick = { BookMySpaceRepository.toggleEventRegistration(event.id) },
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text(if (event.isRegistered) "Registered ✓" else "Register / Ticket")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CoursesScreen() {
    val courses by BookMySpaceRepository.courses.collectAsState()
    var selectedCourseForQuickEnroll by remember { mutableStateOf<com.bookmyspace.bookmyspace.data.model.Course?>(null) }

    if (selectedCourseForQuickEnroll != null) {
        val course = selectedCourseForQuickEnroll!!
        AlertDialog(
            onDismissRequest = { selectedCourseForQuickEnroll = null },
            title = { Text("⚡ 1-Tap Quick Course Enrollment", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary) },
            text = {
                Column {
                    Text("Course: ${course.title}", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Text("Coach: ${course.coachName}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Batch: Morning / Evening Flexible Batch", fontSize = 12.sp)
                    Text("Duration: ${course.durationWeeks} Weeks", fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(8.dp))
                    HorizontalDivider()
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Course Fee:", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text(if (course.price == 0.0) "FREE" else "₹${course.price.toInt()}", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary, fontSize = 15.sp)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.toggleCourseEnrollment(course.id)
                        selectedCourseForQuickEnroll = null
                    }
                ) {
                    Text(if (course.price == 0.0) "Join Now" else "⚡ Pay & Enroll ₹${course.price.toInt()}")
                }
            },
            dismissButton = {
                TextButton(onClick = { selectedCourseForQuickEnroll = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Surface(
            color = MaterialTheme.colorScheme.secondaryContainer,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text("Sports Academies & Coaching", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text("Learn from certified coaches and former national athletes", fontSize = 12.sp)
            }
        }

        LazyColumn(
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(courses) { course ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(course.title, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                        Text("👨‍🏫 ${course.coachName}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(course.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                        ) {
                            Text("₹${course.price.toInt()} / ${course.durationWeeks} Wks", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                            
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                if (!course.isEnrolled) {
                                    FilledTonalButton(
                                        onClick = { selectedCourseForQuickEnroll = course },
                                        shape = RoundedCornerShape(10.dp)
                                    ) {
                                        Text("⚡ Quick Enroll", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                }

                                Button(
                                    onClick = { BookMySpaceRepository.toggleCourseEnrollment(course.id) },
                                    shape = RoundedCornerShape(10.dp)
                                ) {
                                    Text(if (course.isEnrolled) "Enrolled ✓" else "Enroll")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
