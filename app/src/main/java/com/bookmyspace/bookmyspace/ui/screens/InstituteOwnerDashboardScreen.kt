package com.bookmyspace.bookmyspace.ui.screens

import android.app.Activity
import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.DynamicConfigurableFieldsForm
import com.bookmyspace.bookmyspace.util.RazorpayHelper
import com.bookmyspace.bookmyspace.util.RazorpayPaymentListener
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InstituteOwnerDashboardScreen(
    onNavigateBack: () -> Unit,
    onNavigateToLogin: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val subscriptions by BookMySpaceRepository.instituteSubscriptions.collectAsState()
    val institutes by BookMySpaceRepository.institutes.collectAsState()
    val classes by BookMySpaceRepository.instituteClasses.collectAsState()

    // Determine current user ID (or default to owner.dev for testing/demo)
    val currentUserId = authUser?.id ?: "usr_dev_owner_002"
    val isOwnerSubscribed = BookMySpaceRepository.hasActiveListingPlan(currentUserId)
    val currentSubscription = BookMySpaceRepository.getOwnerSubscription(currentUserId)
    val dashboardSubscription = BookMySpaceRepository.getOwnerSubscriptionForDashboard(currentUserId)
    val listingStatus = BookMySpaceRepository.getOwnerListingStatus(currentUserId)
    val expiryText = dashboardSubscription?.let {
        SimpleDateFormat("dd MMM yyyy", Locale.getDefault()).format(Date(it.expiryDate))
    }

    // Current owner's institute profile and classes
    val ownerInstitute = institutes.find { it.ownerId == currentUserId }
    val ownerClasses = classes.filter { it.ownerId == currentUserId }

    var selectedTab by remember { mutableIntStateOf(0) } // 0: My Classes, 1: Institute Profile & Faculty, 2: Listing Plan
    var showPlanSelectionModal by remember { mutableStateOf(false) }
    var showAddEditClassModal by remember { mutableStateOf(false) }
    var classBeingEdited by remember { mutableStateOf<InstituteClass?>(null) }
    var showAddFacultyModal by remember { mutableStateOf(false) }
    var showDeleteConfirmClass by remember { mutableStateOf<InstituteClass?>(null) }
    var isPaymentProcessing by remember { mutableStateOf(false) }
    var paymentSuccessMessage by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Institute Owner Portal", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(
                            if (isOwnerSubscribed) "Active Plan: ${currentSubscription?.planTier?.title ?: "Pro"} · Expires $expiryText"
                            else "$listingStatus${expiryText?.let { " · Expired $it" } ?: ""}",
                            fontSize = 12.sp,
                            color = if (isOwnerSubscribed) Color(0xFF2E7D32) else MaterialTheme.colorScheme.error,
                            fontWeight = FontWeight.Medium
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("owner_dashboard_back_btn")
                    ) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (dashboardSubscription != null) {
                        TextButton(
                            onClick = { showPlanSelectionModal = true },
                            modifier = Modifier.testTag("upgrade_plan_top_btn")
                        ) {
                            Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(if (isOwnerSubscribed) "Plan Details" else "Renew Plan")
                        }
                    }
                }
            )
        },
        floatingActionButton = {
            if (isOwnerSubscribed && selectedTab == 0) {
                ExtendedFloatingActionButton(
                    onClick = {
                        classBeingEdited = null
                        showAddEditClassModal = true
                    },
                    icon = { Icon(Icons.Default.Add, contentDescription = null) },
                    text = { Text("Post New Class") },
                    modifier = Modifier.testTag("post_new_class_fab")
                )
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // If Owner has NO active listing plan, show Plan Paywall
            if (!isOwnerSubscribed) {
                UnsubscribedOwnerPaywallView(
                    onSelectPlan = { plan ->
                        if (activity != null) {
                            isPaymentProcessing = true
                            RazorpayHelper.startInstitutePlanPayment(
                                activity = activity,
                                plan = plan,
                                user = authUser,
                                listener = object : RazorpayPaymentListener {
                                    override fun onPaymentSuccess(paymentId: String, orderId: String?, signature: String?) {
                                        BookMySpaceRepository.purchaseInstituteListingPlan(
                                            ownerId = currentUserId,
                                            planTier = plan,
                                            paymentId = paymentId
                                        )
                                        isPaymentProcessing = false
                                        paymentSuccessMessage = "Payment verified! Your ${plan.title} plan is unlocked."
                                        Toast.makeText(context, "Listing plan unlocked successfully!", Toast.LENGTH_LONG).show()
                                    }

                                    override fun onPaymentError(code: Int, description: String?) {
                                        isPaymentProcessing = false
                                        Toast.makeText(context, "Payment cancelled or failed: $description", Toast.LENGTH_SHORT).show()
                                    }
                                }
                            )
                        } else {
                            // Instant activation for tests / local env
                            BookMySpaceRepository.setListingPlanForTesting(currentUserId, plan)
                            Toast.makeText(context, "${plan.title} activated successfully!", Toast.LENGTH_SHORT).show()
                        }
                    }
                )
            } else {
                // Owner HAS active listing plan -> Full Dashboard
                // Top Summary & Stats
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                        .testTag("owner_stats_card"),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        horizontalArrangement = Arrangement.SpaceAround,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("${ownerClasses.size}", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = MaterialTheme.colorScheme.primary)
                            Text("Total Classes", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("${ownerClasses.count { it.isPublished }}", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = Color(0xFF2E7D32))
                            Text("Published", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("${ownerClasses.count { it.isPaused }}", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = Color(0xFFF57C00))
                            Text("Paused", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("${ownerInstitute?.facultyMembers?.size ?: 0}", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = MaterialTheme.colorScheme.secondary)
                            Text("Faculty", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }

                // Main Tabs
                TabRow(
                    selectedTabIndex = selectedTab,
                    modifier = Modifier.fillMaxWidth().testTag("owner_dashboard_tabs")
                ) {
                    Tab(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        text = { Text("My Classes (${ownerClasses.size})", fontWeight = FontWeight.SemiBold) },
                        icon = { Icon(Icons.Default.School, contentDescription = null, modifier = Modifier.size(16.dp)) },
                        modifier = Modifier.testTag("tab_my_classes")
                    )
                    Tab(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        text = { Text("Academy Profile", fontWeight = FontWeight.SemiBold) },
                        icon = { Icon(Icons.Default.Apartment, contentDescription = null, modifier = Modifier.size(16.dp)) },
                        modifier = Modifier.testTag("tab_academy_profile")
                    )
                }

                // Tab Content
                if (selectedTab == 0) {
                    // Classes Management Tab
                    if (ownerClasses.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(24.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.AddBox, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                                Spacer(modifier = Modifier.height(12.dp))
                                Text("No Classes Created Yet", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                Text("Tap '+ Post New Class' below to publish your first batch.", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(
                                    onClick = {
                                        classBeingEdited = null
                                        showAddEditClassModal = true
                                    },
                                    modifier = Modifier.testTag("empty_state_add_class_btn")
                                ) {
                                    Icon(Icons.Default.Add, contentDescription = null)
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Post First Class")
                                }
                            }
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .testTag("owner_classes_list"),
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(ownerClasses, key = { it.id }) { classItem ->
                                OwnerClassManagementCard(
                                    classItem = classItem,
                                    onEdit = {
                                        classBeingEdited = classItem
                                        showAddEditClassModal = true
                                    },
                                    onTogglePause = {
                                        if (classItem.isPaused) {
                                            BookMySpaceRepository.unpauseClass(currentUserId, classItem.id)
                                            Toast.makeText(context, "Class '${classItem.title}' is now Published", Toast.LENGTH_SHORT).show()
                                        } else {
                                            BookMySpaceRepository.pauseClass(currentUserId, classItem.id)
                                            Toast.makeText(context, "Class '${classItem.title}' is now Paused", Toast.LENGTH_SHORT).show()
                                        }
                                    },
                                    onTogglePublish = {
                                        val newStatus = if (classItem.isPublished) ClassPublishStatus.DRAFT else ClassPublishStatus.PUBLISHED
                                        BookMySpaceRepository.toggleClassPublishStatus(currentUserId, classItem.id, newStatus)
                                        Toast.makeText(context, "Status updated to ${newStatus.label}", Toast.LENGTH_SHORT).show()
                                    },
                                    onDelete = { showDeleteConfirmClass = classItem }
                                )
                            }
                        }
                    }
                } else {
                    // Academy Profile & Faculty Tab
                    OwnerInstituteProfileEditor(
                        ownerId = currentUserId,
                        initialProfile = ownerInstitute ?: InstituteProfile(
                            id = "",
                            ownerId = currentUserId,
                            name = "My Academy",
                            phone = authUser?.phone.orEmpty(),
                            whatsapp = authUser?.phone.orEmpty()
                        ),
                        onAddFacultyClick = { showAddFacultyModal = true },
                        onDeleteFaculty = { facultyId ->
                            if (ownerInstitute != null) {
                                BookMySpaceRepository.deleteFaculty(currentUserId, ownerInstitute.id, facultyId)
                                Toast.makeText(context, "Faculty removed", Toast.LENGTH_SHORT).show()
                            }
                        }
                    )
                }
            }
        }
    }

    // Plan Selection / Upgrade Dialog
    if (showPlanSelectionModal) {
        AlertDialog(
            onDismissRequest = { showPlanSelectionModal = false },
            title = { Text("Choose Institute Listing Plan", fontWeight = FontWeight.Bold) },
            text = {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(InstituteListingPlanTier.values()) { plan ->
                        val isCurrent = currentSubscription?.planTier == plan
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    BookMySpaceRepository.setListingPlanForTesting(currentUserId, plan)
                                    showPlanSelectionModal = false
                                    Toast.makeText(context, "Plan updated to ${plan.title}", Toast.LENGTH_SHORT).show()
                                },
                            colors = CardDefaults.cardColors(
                                containerColor = if (isCurrent) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant
                            ),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(plan.title, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Text("₹${plan.price.toInt()}", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.primary)
                                }
                                Text(plan.description, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                if (isCurrent) {
                                    Text("✓ Currently Active Plan", fontWeight = FontWeight.Bold, fontSize = 11.sp, color = Color(0xFF2E7D32))
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showPlanSelectionModal = false }) {
                    Text("Close")
                }
            }
        )
    }

    // Add / Edit Class Modal
    if (showAddEditClassModal) {
        val defaultInstituteId = ownerInstitute?.id ?: "inst_001"
        AddEditClassFormDialog(
            ownerId = currentUserId,
            instituteId = defaultInstituteId,
            existingClass = classBeingEdited,
            facultyList = ownerInstitute?.facultyMembers ?: emptyList(),
            onDismiss = { showAddEditClassModal = false },
            onSave = { savedClass ->
                val result = BookMySpaceRepository.saveClass(currentUserId, savedClass)
                if (result.isSuccess) {
                    showAddEditClassModal = false
                    Toast.makeText(context, "Class '${savedClass.title}' saved successfully!", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(context, "Error: ${result.exceptionOrNull()?.message}", Toast.LENGTH_LONG).show()
                }
            }
        )
    }

    // Add Faculty Modal
    if (showAddFacultyModal && ownerInstitute != null) {
        AddFacultyDialog(
            onDismiss = { showAddFacultyModal = false },
            onSave = { faculty ->
                val result = BookMySpaceRepository.addOrUpdateFaculty(currentUserId, ownerInstitute.id, faculty)
                if (result.isSuccess) {
                    showAddFacultyModal = false
                    Toast.makeText(context, "Faculty '${faculty.name}' added successfully!", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(context, "Error: ${result.exceptionOrNull()?.message}", Toast.LENGTH_SHORT).show()
                }
            }
        )
    }

    // Delete Class Confirm Dialog
    showDeleteConfirmClass?.let { classToDelete ->
        AlertDialog(
            onDismissRequest = { showDeleteConfirmClass = null },
            title = { Text("Delete Class?", fontWeight = FontWeight.Bold) },
            text = { Text("Are you sure you want to delete '${classToDelete.title}'? This action cannot be undone and will remove it from student discovery.") },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.deleteClass(currentUserId, classToDelete.id)
                        showDeleteConfirmClass = null
                        Toast.makeText(context, "Class deleted successfully", Toast.LENGTH_SHORT).show()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.testTag("confirm_delete_class_btn")
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmClass = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}

/**
 * Paywall Screen for Unsubscribed Institute Owners
 */
@Composable
fun UnsubscribedOwnerPaywallView(
    onSelectPlan: (InstituteListingPlanTier) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .testTag("owner_unsubscribed_paywall"),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Lock, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Institute Listing Plan Required", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MaterialTheme.colorScheme.onPrimaryContainer)
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        "To create your academy profile, add faculty, and publish classes for students to find on BookMySpace, please choose an active listing plan.",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.9f)
                    )
                }
            }
        }

        item {
            Text("Select Your Listing Plan", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }

        items(InstituteListingPlanTier.values()) { plan ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("plan_card_${plan.name.lowercase()}"),
                shape = RoundedCornerShape(16.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 3.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (plan == InstituteListingPlanTier.GROWTH_PRO) MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f) else MaterialTheme.colorScheme.surface
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(plan.title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text(plan.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Surface(
                            color = MaterialTheme.colorScheme.primary,
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                plan.badge,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))
                    Text(
                        "₹${plan.price.toInt()} / ${if (plan.durationDays >= 365) "year" else if (plan.durationDays >= 90) "quarter" else "month"}",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 20.sp,
                        color = MaterialTheme.colorScheme.primary
                    )

                    Spacer(modifier = Modifier.height(8.dp))
                    plan.features.forEach { feat ->
                        Row(modifier = Modifier.padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(feat, fontSize = 12.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))
                    Button(
                        onClick = { onSelectPlan(plan) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("subscribe_plan_btn_${plan.name.lowercase()}")
                    ) {
                        Icon(Icons.Default.Payment, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Subscribe & Unlock (₹${plan.price.toInt()})")
                    }
                }
            }
        }
    }
}

/**
 * Single Class Item for Owner Management with Edit, Pause, Publish, Delete
 */
@Composable
fun OwnerClassManagementCard(
    classItem: InstituteClass,
    onEdit: () -> Unit,
    onTogglePause: () -> Unit,
    onTogglePublish: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("owner_class_card_${classItem.id}"),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Status Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = when (classItem.status) {
                        ClassPublishStatus.PUBLISHED -> Color(0xFF2E7D32).copy(alpha = 0.15f)
                        ClassPublishStatus.PAUSED -> Color(0xFFF57C00).copy(alpha = 0.15f)
                        ClassPublishStatus.DRAFT -> MaterialTheme.colorScheme.surfaceVariant
                    },
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = "● ${classItem.status.label}",
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = when (classItem.status) {
                            ClassPublishStatus.PUBLISHED -> Color(0xFF2E7D32)
                            ClassPublishStatus.PAUSED -> Color(0xFFF57C00)
                            ClassPublishStatus.DRAFT -> MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }

                Text(
                    "₹${classItem.feeAmount.toInt()} / ${classItem.feeBillingCycle}",
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.primary
                )
            }

            Spacer(modifier = Modifier.height(8.dp))
            Text(classItem.title, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(
                "Category: ${classItem.category} • Mode: ${classItem.deliveryMode.shortBadge}",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            if (classItem.facultyName.isNotBlank()) {
                Text("👨‍🏫 Faculty: ${classItem.facultyName}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            val daysStr = if (classItem.daysOfWeek.isNotEmpty()) classItem.daysOfWeek.joinToString(", ") else "Flexible"
            Text("⏰ $daysStr | ${classItem.startTime} - ${classItem.endTime}", fontSize = 12.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Medium)

            // Management Action Buttons: Edit, Pause, Publish, Delete
            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Edit Button
                FilledTonalButton(
                    onClick = onEdit,
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    modifier = Modifier.testTag("owner_edit_class_btn_${classItem.id}")
                ) {
                    Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(14.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Edit", fontSize = 11.sp)
                }

                // Pause / Unpause Button
                OutlinedButton(
                    onClick = onTogglePause,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                    modifier = Modifier.testTag("owner_pause_class_btn_${classItem.id}")
                ) {
                    Icon(
                        if (classItem.isPaused) Icons.Default.PlayArrow else Icons.Default.Pause,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(if (classItem.isPaused) "Unpause" else "Pause", fontSize = 11.sp)
                }

                // Delete Button
                IconButton(
                    onClick = onDelete,
                    modifier = Modifier
                        .size(36.dp)
                        .testTag("owner_delete_class_btn_${classItem.id}")
                ) {
                    Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

/**
 * Form for Add / Edit Class with strict required field validation
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditClassFormDialog(
    ownerId: String,
    instituteId: String,
    existingClass: InstituteClass?,
    facultyList: List<FacultyMember>,
    onDismiss: () -> Unit,
    onSave: (InstituteClass) -> Unit
) {
    var title by remember { mutableStateOf(existingClass?.title ?: "") }
    var category by remember { mutableStateOf(existingClass?.category ?: "Sports & Fitness") }
    var description by remember { mutableStateOf(existingClass?.description ?: "") }
    var imageUrlInput by remember { mutableStateOf(existingClass?.imageUrls?.firstOrNull() ?: "") }
    var selectedFacultyId by remember { mutableStateOf(existingClass?.facultyId ?: "") }
    var customFacultyName by remember { mutableStateOf(existingClass?.facultyName ?: "") }
    var startTime by remember { mutableStateOf(existingClass?.startTime ?: "06:00 PM") }
    var endTime by remember { mutableStateOf(existingClass?.endTime ?: "07:30 PM") }
    var durationText by remember { mutableStateOf(existingClass?.durationText ?: "90 mins") }
    var feeText by remember { mutableStateOf(if (existingClass != null) existingClass.feeAmount.toInt().toString() else "3000") }
    var feeCycle by remember { mutableStateOf(existingClass?.feeBillingCycle ?: "per month") }
    var deliveryMode by remember { mutableStateOf(existingClass?.deliveryMode ?: ClassDeliveryMode.OFFLINE) }
    var location by remember { mutableStateOf(existingClass?.location ?: "") }
    var contactPhone by remember { mutableStateOf(existingClass?.contactPhone ?: "+91 98765 43210") }
    var contactWhatsapp by remember { mutableStateOf(existingClass?.contactWhatsapp ?: "+91 98765 43210") }
    var selectedDays by remember {
        mutableStateOf(existingClass?.daysOfWeek?.toSet() ?: setOf("Mon", "Wed", "Fri"))
    }
    var customClassFieldValues by remember(existingClass?.id) {
        mutableStateOf(existingClass?.let { BookMySpaceRepository.getCustomValuesForListing(it.id) } ?: emptyMap())
    }

    var errorMessage by remember { mutableStateOf<String?>(null) }

    val daysOptions = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    val categoryOptions = listOf("Sports & Fitness", "Music & Arts", "Tech & Coding", "Dance", "Academics")

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("add_edit_class_dialog"),
        title = {
            Text(
                if (existingClass == null) "Post New Class / Batch" else "Edit Class: ${existingClass.title}",
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp
            )
        },
        text = {
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                if (errorMessage != null) {
                    item {
                        Surface(
                            color = MaterialTheme.colorScheme.errorContainer,
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                errorMessage!!,
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                fontSize = 12.sp,
                                modifier = Modifier.padding(8.dp),
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                // Title (Required)
                item {
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        label = { Text("Class Title *") },
                        placeholder = { Text("e.g. Pro Badminton Coaching Batch") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("class_form_title_input"),
                        singleLine = true
                    )
                }

                // Category (Required)
                item {
                    Text("Category / Subject *", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(categoryOptions) { cat ->
                            FilterChip(
                                selected = category == cat,
                                onClick = { category = cat },
                                label = { Text(cat, fontSize = 11.sp) }
                            )
                        }
                    }
                }

                // Delivery Mode (Required)
                item {
                    Text("Delivery Mode *", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        ClassDeliveryMode.values().forEach { mode ->
                            FilterChip(
                                selected = deliveryMode == mode,
                                onClick = { deliveryMode = mode },
                                label = { Text(mode.shortBadge, fontSize = 11.sp) }
                            )
                        }
                    }
                }

                // Faculty Assignment
                item {
                    Text("Assigned Faculty / Coach", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    if (facultyList.isNotEmpty()) {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            items(facultyList) { fac ->
                                FilterChip(
                                    selected = selectedFacultyId == fac.id,
                                    onClick = {
                                        selectedFacultyId = fac.id
                                        customFacultyName = fac.name
                                    },
                                    label = { Text(fac.name, fontSize = 11.sp) }
                                )
                            }
                        }
                    }
                    OutlinedTextField(
                        value = customFacultyName,
                        onValueChange = { customFacultyName = it },
                        label = { Text("Faculty / Coach Name") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("class_form_faculty_input"),
                        singleLine = true
                    )
                }

                // Days of Week
                item {
                    Text("Schedule Days", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        daysOptions.forEach { day ->
                            val isSelected = selectedDays.contains(day)
                            FilterChip(
                                selected = isSelected,
                                onClick = {
                                    selectedDays = if (isSelected) selectedDays - day else selectedDays + day
                                },
                                label = { Text(day, fontSize = 10.sp) }
                            )
                        }
                    }
                }

                // Timings (Required)
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = startTime,
                            onValueChange = { startTime = it },
                            label = { Text("Start Time *") },
                            placeholder = { Text("06:00 PM") },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("class_form_start_time"),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = endTime,
                            onValueChange = { endTime = it },
                            label = { Text("End Time *") },
                            placeholder = { Text("07:30 PM") },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("class_form_end_time"),
                            singleLine = true
                        )
                    }
                }

                // Fee (Required)
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = feeText,
                            onValueChange = { feeText = it },
                            label = { Text("Fee (₹) *") },
                            placeholder = { Text("3000") },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("class_form_fee_input"),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = feeCycle,
                            onValueChange = { feeCycle = it },
                            label = { Text("Billing Cycle") },
                            placeholder = { Text("per month") },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("class_form_billing_cycle"),
                            singleLine = true
                        )
                    }
                }

                // Location (Optional for Online)
                item {
                    OutlinedTextField(
                        value = location,
                        onValueChange = { location = it },
                        label = { Text("Class Location / Studio Address") },
                        placeholder = { Text("e.g. Apex Arena, Indiranagar") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("class_form_location_input"),
                        singleLine = true
                    )
                }

                // Contact Phone & WhatsApp (Required)
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = contactPhone,
                            onValueChange = { contactPhone = it },
                            label = { Text("Call Phone *") },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("class_form_phone_input"),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = contactWhatsapp,
                            onValueChange = { contactWhatsapp = it },
                            label = { Text("WhatsApp *") },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("class_form_whatsapp_input"),
                            singleLine = true
                        )
                    }
                }

                // Photo Image URL
                item {
                    OutlinedTextField(
                        value = imageUrlInput,
                        onValueChange = { imageUrlInput = it },
                        label = { Text("Photo URL (Optional)") },
                        placeholder = { Text("https://images.unsplash.com/...") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("class_form_image_input"),
                        singleLine = true
                    )
                }

                // Description
                item {
                    OutlinedTextField(
                        value = description,
                        onValueChange = { description = it },
                        label = { Text("Description (Optional)") },
                        placeholder = { Text("Describe syllabus, what students learn, requirements...") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("class_form_desc_input"),
                        minLines = 3,
                        maxLines = 5
                    )
                }

                // Dynamic Configurable Class Fields
                item {
                    DynamicConfigurableFieldsForm(
                        targetCategory = ListingTargetCategory.CLASS,
                        values = customClassFieldValues,
                        onValuesChange = { customClassFieldValues = it },
                        isOwner = true
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    // Validate required fields
                    if (title.isBlank()) {
                        errorMessage = "Class Title is required."
                        return@Button
                    }
                    if (startTime.isBlank() || endTime.isBlank()) {
                        errorMessage = "Start and End timings are required."
                        return@Button
                    }
                    val parsedFee = feeText.toDoubleOrNull()
                    if (parsedFee == null || parsedFee < 0) {
                        errorMessage = "Please enter a valid non-negative fee amount."
                        return@Button
                    }
                    if (contactPhone.isBlank() && contactWhatsapp.isBlank()) {
                        errorMessage = "At least one contact number (Phone or WhatsApp) is required."
                        return@Button
                    }

                    val photos = if (imageUrlInput.isNotBlank()) listOf(imageUrlInput) else emptyList()

                    val newOrUpdated = (existingClass ?: InstituteClass(
                        id = "",
                        instituteId = instituteId,
                        ownerId = ownerId,
                        title = title,
                        category = category,
                        description = description,
                        imageUrls = photos,
                        facultyId = selectedFacultyId.ifEmpty { null },
                        facultyName = customFacultyName,
                        daysOfWeek = selectedDays.toList(),
                        startTime = startTime,
                        endTime = endTime,
                        durationText = durationText,
                        feeAmount = parsedFee,
                        feeBillingCycle = feeCycle,
                        deliveryMode = deliveryMode,
                        location = location,
                        contactPhone = contactPhone,
                        contactWhatsapp = contactWhatsapp,
                        status = ClassPublishStatus.PUBLISHED
                    )).copy(
                        title = title,
                        category = category,
                        description = description,
                        imageUrls = photos,
                        facultyId = selectedFacultyId.ifEmpty { null },
                        facultyName = customFacultyName,
                        daysOfWeek = selectedDays.toList(),
                        startTime = startTime,
                        endTime = endTime,
                        durationText = durationText,
                        feeAmount = parsedFee,
                        feeBillingCycle = feeCycle,
                        deliveryMode = deliveryMode,
                        location = location,
                        contactPhone = contactPhone,
                        contactWhatsapp = contactWhatsapp
                    )

                    if (customClassFieldValues.isNotEmpty()) {
                        BookMySpaceRepository.saveCustomValuesForListing(newOrUpdated.id.ifBlank { "temp_class_${System.currentTimeMillis()}" }, customClassFieldValues)
                    }

                    onSave(newOrUpdated)
                },
                modifier = Modifier.testTag("save_class_form_btn")
            ) {
                Text(if (existingClass == null) "Publish Class" else "Save Changes")
            }
        },
        dismissButton = {
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.testTag("cancel_class_form_btn")
            ) {
                Text("Cancel")
            }
        }
    )
}

/**
 * Institute Profile Editor Form
 */
@Composable
fun OwnerInstituteProfileEditor(
    ownerId: String,
    initialProfile: InstituteProfile,
    onAddFacultyClick: () -> Unit,
    onDeleteFaculty: (String) -> Unit
) {
    val context = LocalContext.current
    var name by remember { mutableStateOf(initialProfile.name) }
    var logoUrl by remember { mutableStateOf(initialProfile.logoUrl) }
    var photoUrl by remember { mutableStateOf(initialProfile.imageUrls.firstOrNull() ?: "") }
    var description by remember { mutableStateOf(initialProfile.description) }
    var address by remember { mutableStateOf(initialProfile.address) }
    var city by remember { mutableStateOf(initialProfile.city) }
    var phone by remember { mutableStateOf(initialProfile.phone) }
    var whatsapp by remember { mutableStateOf(initialProfile.whatsapp) }
    var websiteUrl by remember { mutableStateOf(initialProfile.websiteUrl) }
    var customInstFieldValues by remember(initialProfile.id) {
        mutableStateOf(BookMySpaceRepository.getCustomValuesForListing(initialProfile.id))
    }
    var isSaving by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .testTag("owner_institute_profile_editor"),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Edit Academy Profile", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Text("Update your institute details, photos, contact & faculty roster.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        item {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Academy / Institute Name *") },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("institute_form_name_input"),
                singleLine = true
            )
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = phone,
                    onValueChange = { phone = it },
                    label = { Text("Phone Number *") },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("institute_form_phone_input"),
                    singleLine = true
                )
                OutlinedTextField(
                    value = whatsapp,
                    onValueChange = { whatsapp = it },
                    label = { Text("WhatsApp Number *") },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("institute_form_whatsapp_input"),
                    singleLine = true
                )
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = address,
                    onValueChange = { address = it },
                    label = { Text("Address") },
                    modifier = Modifier
                        .weight(2f)
                        .testTag("institute_form_address_input"),
                    singleLine = true
                )
                OutlinedTextField(
                    value = city,
                    onValueChange = { city = it },
                    label = { Text("City") },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("institute_form_city_input"),
                    singleLine = true
                )
            }
        }

        item {
            OutlinedTextField(
                value = logoUrl,
                onValueChange = { logoUrl = it },
                label = { Text("Logo Image URL") },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("institute_form_logo_input"),
                singleLine = true
            )
        }

        item {
            OutlinedTextField(
                value = photoUrl,
                onValueChange = { photoUrl = it },
                label = { Text("Cover / Campus Photo URL") },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("institute_form_cover_input"),
                singleLine = true
            )
        }

        item {
            OutlinedTextField(
                value = websiteUrl,
                onValueChange = { websiteUrl = it },
                label = { Text("Website / Social Link") },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("institute_form_website_input"),
                singleLine = true
            )
        }

        item {
            OutlinedTextField(
                value = description,
                onValueChange = { description = it },
                label = { Text("About Academy / Description") },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("institute_form_desc_input"),
                minLines = 3,
                maxLines = 5
            )
        }

        // Dynamic Configurable Institute Fields
        item {
            DynamicConfigurableFieldsForm(
                targetCategory = ListingTargetCategory.INSTITUTE,
                values = customInstFieldValues,
                onValuesChange = { customInstFieldValues = it },
                isOwner = true
            )
        }

        // Save Profile Button
        item {
            Button(
                onClick = {
                    val updated = initialProfile.copy(
                        name = name,
                        phone = phone,
                        whatsapp = whatsapp,
                        address = address,
                        city = city,
                        logoUrl = logoUrl,
                        imageUrls = if (photoUrl.isNotBlank()) listOf(photoUrl) else initialProfile.imageUrls,
                        websiteUrl = websiteUrl,
                        description = description
                    )
                    if (customInstFieldValues.isNotEmpty()) {
                        BookMySpaceRepository.saveCustomValuesForListing(initialProfile.id, customInstFieldValues)
                    }
                    val res = BookMySpaceRepository.saveInstituteProfile(ownerId, updated)
                    if (res.isSuccess) {
                        Toast.makeText(context, "Academy profile saved successfully!", Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(context, "Failed: ${res.exceptionOrNull()?.message}", Toast.LENGTH_LONG).show()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("save_institute_profile_btn")
            ) {
                Icon(Icons.Default.Save, contentDescription = null)
                Spacer(modifier = Modifier.width(6.dp))
                Text("Save Profile Changes")
            }
        }

        // Faculty Management Section
        item {
            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Faculty & Coaches (${initialProfile.facultyMembers.size})", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                FilledTonalButton(
                    onClick = onAddFacultyClick,
                    modifier = Modifier.testTag("add_faculty_btn"),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(14.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Add Faculty")
                }
            }
        }

        if (initialProfile.facultyMembers.isEmpty()) {
            item {
                Text("No faculty added yet. Add coaches or instructors to build trust with students.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            items(initialProfile.facultyMembers) { fac ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("👨‍🏫 ${fac.name}", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            if (fac.qualification.isNotBlank()) {
                                Text(fac.qualification, fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
                            }
                            if (fac.subjectOrSpecialization.isNotBlank()) {
                                Text("Specialization: ${fac.subjectOrSpecialization} (${fac.experienceYears} yrs exp)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        IconButton(
                            onClick = { onDeleteFaculty(fac.id) },
                            modifier = Modifier.testTag("delete_faculty_btn_${fac.id}")
                        ) {
                            Icon(Icons.Default.Delete, contentDescription = "Delete Faculty", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
        }
    }
}

/**
 * Add Faculty Dialog
 */
@Composable
fun AddFacultyDialog(
    onDismiss: () -> Unit,
    onSave: (FacultyMember) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var qualification by remember { mutableStateOf("") }
    var experienceYearsText by remember { mutableStateOf("5") }
    var specialization by remember { mutableStateOf("") }
    var bio by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("add_faculty_dialog"),
        title = { Text("Add Faculty / Coach", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Full Name *") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("faculty_name_input"),
                    singleLine = true
                )
                OutlinedTextField(
                    value = qualification,
                    onValueChange = { qualification = it },
                    label = { Text("Certifications / Qualification") },
                    placeholder = { Text("e.g. BWF Level 2, Trinity Grade 8") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("faculty_qual_input"),
                    singleLine = true
                )
                OutlinedTextField(
                    value = experienceYearsText,
                    onValueChange = { experienceYearsText = it },
                    label = { Text("Experience (Years)") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("faculty_exp_input"),
                    singleLine = true
                )
                OutlinedTextField(
                    value = specialization,
                    onValueChange = { specialization = it },
                    label = { Text("Specialization / Subject") },
                    placeholder = { Text("e.g. Advanced Footwork, Guitar Fingerstyle") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("faculty_spec_input"),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (name.isBlank()) return@Button
                    val exp = experienceYearsText.toIntOrNull() ?: 0
                    onSave(
                        FacultyMember(
                            id = "",
                            name = name,
                            qualification = qualification,
                            experienceYears = exp,
                            subjectOrSpecialization = specialization,
                            bio = bio
                        )
                    )
                },
                modifier = Modifier.testTag("save_faculty_btn")
            ) {
                Text("Add Faculty")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
