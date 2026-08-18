package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.AppSectionConfig
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminAppSectionsScreen(
    onNavigateBack: () -> Unit
) {
    val appSections by BookMySpaceRepository.appSections.collectAsState()
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val isAdmin = authUser?.role == UserRole.ADMIN

    var showResetDialog by remember { mutableStateOf(false) }
    var snackbarMessage by remember { mutableStateOf<String?>(null) }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(snackbarMessage) {
        snackbarMessage?.let {
            snackbarHostState.showSnackbar(it)
            snackbarMessage = null
        }
    }

    val activeCount = remember(appSections) { appSections.count { it.isEnabled } }
    val totalCount = appSections.size

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Admin → App Sections",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                        Text(
                            text = "Control major active sections & simplify user experience",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("admin_sections_back_btn")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = { showResetDialog = true },
                        modifier = Modifier.testTag("admin_sections_reset_btn")
                    ) {
                        Icon(Icons.Default.RestartAlt, contentDescription = "Reset Defaults")
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            contentPadding = PaddingValues(vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Admin Security & Status Banner
            item {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = if (isAdmin) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)
                    else MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.6f),
                    border = BorderStroke(
                        1.dp,
                        if (isAdmin) MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)
                        else MaterialTheme.colorScheme.error.copy(alpha = 0.4f)
                    ),
                    modifier = Modifier.fillMaxWidth().testTag("admin_sections_status_card")
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = if (isAdmin) Icons.Default.AdminPanelSettings else Icons.Default.Lock,
                                    contentDescription = null,
                                    tint = if (isAdmin) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text(
                                        text = if (isAdmin) "Admin Security Active" else "Read-Only View (Requires Admin)",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp,
                                        color = if (isAdmin) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onErrorContainer
                                    )
                                    Text(
                                        text = "Active Sections: $activeCount of $totalCount enabled",
                                        fontSize = 12.sp,
                                        color = if (isAdmin) MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f) else MaterialTheme.colorScheme.onErrorContainer.copy(alpha = 0.8f)
                                    )
                                }
                            }

                            if (!isAdmin) {
                                Button(
                                    onClick = {
                                        BookMySpaceRepository.switchUserRole(UserRole.ADMIN)
                                        snackbarMessage = "Switched session to Admin mode for testing"
                                    },
                                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                    modifier = Modifier.testTag("admin_switch_role_btn")
                                ) {
                                    Text("Switch to Admin", fontSize = 11.sp)
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = "💡 When a section is disabled by Admin, its related categories, search results, cards, filters, and forms are completely hidden from normal users. Enabled sections automatically become streamlined and ultra-simple.",
                            fontSize = 11.5.sp,
                            lineHeight = 16.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // Section Toggles List Header
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Major App Sections",
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Text(
                        text = "Instant Live Sync",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }

            // List of Sections
            items(appSections, key = { it.sectionId }) { section ->
                AdminSectionToggleCard(
                    section = section,
                    isAdmin = isAdmin,
                    onToggle = { isEnabled ->
                        val res = BookMySpaceRepository.toggleAppSection(section.sectionId, isEnabled, adminOverride = !isAdmin)
                        if (res.isSuccess) {
                            snackbarMessage = if (isEnabled) "✅ '${section.title}' section ENABLED for users" else "🚫 '${section.title}' section HIDDEN from users"
                        } else {
                            snackbarMessage = res.exceptionOrNull()?.message ?: "Failed to update section"
                        }
                    }
                )
            }
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            icon = { Icon(Icons.Default.RestartAlt, contentDescription = null, tint = MaterialTheme.colorScheme.primary) },
            title = { Text("Reset All Sections?") },
            text = { Text("This will restore all major app sections to their default enabled state.") },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.resetAppSectionsToDefault()
                        showResetDialog = false
                        snackbarMessage = "All sections have been restored to default state"
                    },
                    modifier = Modifier.testTag("confirm_reset_sections_btn")
                ) {
                    Text("Reset to Defaults")
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
fun AdminSectionToggleCard(
    section: AppSectionConfig,
    isAdmin: Boolean,
    onToggle: (Boolean) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(
            1.dp,
            if (section.isEnabled) MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)
            else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
        ),
        shadowElevation = if (section.isEnabled) 1.5.dp else 0.dp,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("admin_section_card_${section.sectionId}")
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(
                                if (section.isEnabled) MaterialTheme.colorScheme.primaryContainer
                                else MaterialTheme.colorScheme.surfaceVariant
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(section.emoji, fontSize = 22.sp)
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = section.title,
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = section.subtitle,
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            lineHeight = 15.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.width(8.dp))

                Switch(
                    checked = section.isEnabled,
                    onCheckedChange = onToggle,
                    modifier = Modifier.testTag("section_switch_${section.sectionId}")
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Subcategories chips preview
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = if (section.isEnabled) Color(0xFFE8F5E9) else Color(0xFFECEFF1)
                ) {
                    Text(
                        text = if (section.isEnabled) "● VISIBLE TO USERS" else "○ DISABLED / HIDDEN",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (section.isEnabled) Color(0xFF2E7D32) else Color(0xFF546E7A),
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }

                if (section.quickOptions.isNotEmpty()) {
                    Text(
                        text = section.quickOptions.take(3).joinToString(", "),
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1
                    )
                }
            }
        }
    }
}
