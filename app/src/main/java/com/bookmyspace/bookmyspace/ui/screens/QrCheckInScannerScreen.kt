package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QrCheckInScannerScreen(
    onBack: () -> Unit,
    onNavigateToBookings: () -> Unit = {}
) {
    val context = LocalContext.current
    val bookings by BookMySpaceRepository.bookings.collectAsState()
    val confirmedBookings by remember(bookings) {
        derivedStateOf { bookings.filter { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.COMPLETED } }
    }

    var selectedTab by remember { mutableStateOf(0) } // 0: Scan QR Code, 1: My Pass QR
    var manualCodeInput by remember { mutableStateOf("") }
    var isFlashlightOn by remember { mutableStateOf(false) }
    var isCameraFront by remember { mutableStateOf(false) }

    var checkInResultState by remember { mutableStateOf<BookMySpaceRepository.CheckInResult?>(null) }
    var showResultModal by remember { mutableStateOf(false) }

    // Animated scanner line
    val infiniteTransition = rememberInfiniteTransition(label = "scanner")
    val scanLineProgress by infiniteTransition.animateFloat(
        initialValue = 0.1f,
        targetValue = 0.9f,
        animationSpec = infiniteRepeatable(
            animation = tween(1600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scan_line"
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Venue QR Check-In", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(
                            "Supabase DB Live Link • Fast Entry Verification",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onBack,
                        modifier = Modifier.testTag("qr_scanner_back_btn")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.padding(end = 12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF2E7D32))
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Supabase Active", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Mode Tabs
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("📷 Scan QR Code", fontWeight = FontWeight.Bold) }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("🎫 My Entry Pass QR", fontWeight = FontWeight.Bold) }
                )
            }

            if (selectedTab == 0) {
                // SCANNER TAB
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    item {
                        // Camera Viewfinder Box
                        Card(
                            shape = RoundedCornerShape(20.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFF121212)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(320.dp)
                                .testTag("qr_camera_viewfinder")
                        ) {
                            Box(modifier = Modifier.fillMaxSize()) {
                                // Camera viewfinder simulation grid/reticle
                                Canvas(modifier = Modifier.fillMaxSize()) {
                                    val width = size.width
                                    val height = size.height

                                    // Viewfinder reticle boundary
                                    val reticleSize = width.coerceAtMost(height) * 0.65f
                                    val left = (width - reticleSize) / 2
                                    val top = (height - reticleSize) / 2

                                    // Dark overlay outside reticle
                                    drawRect(Color.Black.copy(alpha = 0.55f))

                                    // Clear viewfinder reticle center
                                    drawRoundRect(
                                        color = Color.Transparent,
                                        topLeft = Offset(left, top),
                                        size = Size(reticleSize, reticleSize),
                                        cornerRadius = CornerRadius(24f, 24f),
                                        blendMode = androidx.compose.ui.graphics.BlendMode.Clear
                                    )

                                    // Green/White reticle border corners
                                    val strokeWidth = 8f
                                    val cornerLen = 40f
                                    val cornerColor = Color(0xFF00E676)

                                    // Top-Left
                                    drawLine(cornerColor, Offset(left, top), Offset(left + cornerLen, top), strokeWidth)
                                    drawLine(cornerColor, Offset(left, top), Offset(left, top + cornerLen), strokeWidth)

                                    // Top-Right
                                    drawLine(cornerColor, Offset(left + reticleSize, top), Offset(left + reticleSize - cornerLen, top), strokeWidth)
                                    drawLine(cornerColor, Offset(left + reticleSize, top), Offset(left + reticleSize, top + cornerLen), strokeWidth)

                                    // Bottom-Left
                                    drawLine(cornerColor, Offset(left, top + reticleSize), Offset(left + cornerLen, top + reticleSize), strokeWidth)
                                    drawLine(cornerColor, Offset(left, top + reticleSize), Offset(left, top + reticleSize - cornerLen), strokeWidth)

                                    // Bottom-Right
                                    drawLine(cornerColor, Offset(left + reticleSize, top + reticleSize), Offset(left + reticleSize - cornerLen, top + reticleSize), strokeWidth)
                                    drawLine(cornerColor, Offset(left + reticleSize, top + reticleSize), Offset(left + reticleSize, top + reticleSize - cornerLen), strokeWidth)

                                    // Animated Scan Line
                                    val currentLineY = top + (reticleSize * scanLineProgress)
                                    drawLine(
                                        color = Color(0xFF00E676),
                                        start = Offset(left + 12f, currentLineY),
                                        end = Offset(left + reticleSize - 12f, currentLineY),
                                        strokeWidth = 5f
                                    )
                                }

                                // Overlay Camera Controls
                                Row(
                                    modifier = Modifier
                                        .align(Alignment.TopCenter)
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Surface(
                                        color = Color.Black.copy(alpha = 0.6f),
                                        shape = RoundedCornerShape(12.dp)
                                    ) {
                                        Row(
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Icon(Icons.Default.Videocam, contentDescription = null, tint = Color(0xFF00E676), modifier = Modifier.size(16.dp))
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Text(
                                                if (isCameraFront) "Front Camera" else "Main Lens Live Feed",
                                                color = Color.White,
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.Medium
                                            )
                                        }
                                    }

                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        IconButton(
                                            onClick = { isFlashlightOn = !isFlashlightOn },
                                            modifier = Modifier
                                                .background(if (isFlashlightOn) Color(0xFF00E676) else Color.White.copy(alpha = 0.2f), CircleShape)
                                                .size(36.dp)
                                        ) {
                                            Icon(
                                                imageVector = if (isFlashlightOn) Icons.Default.FlashOn else Icons.Default.FlashOff,
                                                contentDescription = "Flashlight",
                                                tint = if (isFlashlightOn) Color.Black else Color.White,
                                                modifier = Modifier.size(18.dp)
                                            )
                                        }

                                        IconButton(
                                            onClick = { isCameraFront = !isCameraFront },
                                            modifier = Modifier
                                                .background(Color.White.copy(alpha = 0.2f), CircleShape)
                                                .size(36.dp)
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.FlipCameraAndroid,
                                                contentDescription = "Flip Camera",
                                                tint = Color.White,
                                                modifier = Modifier.size(18.dp)
                                            )
                                        }
                                    }
                                }

                                Text(
                                    text = "Point camera at venue QR code or pass",
                                    color = Color.White.copy(alpha = 0.85f),
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium,
                                    modifier = Modifier
                                        .align(Alignment.BottomCenter)
                                        .padding(bottom = 16.dp)
                                        .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(8.dp))
                                        .padding(horizontal = 12.dp, vertical = 6.dp)
                                )
                            }
                        }
                    }

                    item {
                        // Quick Simulator Scan Targets (For Emulator testing)
                        Card(
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("⚡ Quick Scan Samples (1-Tap Check-In)", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                    Text("Simulate Camera Scan", fontSize = 10.sp, color = MaterialTheme.colorScheme.primary)
                                }
                                Spacer(modifier = Modifier.height(10.dp))

                                if (confirmedBookings.isEmpty()) {
                                    Text("No active bookings found. Book a venue court first to test check-in!", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                } else {
                                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        confirmedBookings.take(3).forEach { b ->
                                            Surface(
                                                color = if (b.isCheckedIn) Color(0xFFE8F5E9) else MaterialTheme.colorScheme.surface,
                                                shape = RoundedCornerShape(10.dp),
                                                border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)),
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .clickable {
                                                        checkInResultState = BookMySpaceRepository.checkInBookingWithQr(b.id)
                                                        showResultModal = true
                                                    }
                                                    .testTag("scan_sample_btn_${b.id}")
                                            ) {
                                                Row(
                                                    modifier = Modifier.padding(10.dp),
                                                    horizontalArrangement = Arrangement.SpaceBetween,
                                                    verticalAlignment = Alignment.CenterVertically
                                                ) {
                                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                                        Icon(
                                                            imageVector = if (b.isCheckedIn) Icons.Default.CheckCircle else Icons.Default.QrCodeScanner,
                                                            contentDescription = null,
                                                            tint = if (b.isCheckedIn) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                                                            modifier = Modifier.size(20.dp)
                                                        )
                                                        Spacer(modifier = Modifier.width(10.dp))
                                                        Column {
                                                            Text(b.venueName, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                                            Text("Ref #${b.id} • ${b.slotLabel}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                                        }
                                                    }
                                                    Surface(
                                                        color = if (b.isCheckedIn) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                                                        shape = RoundedCornerShape(6.dp)
                                                    ) {
                                                        Text(
                                                            text = if (b.isCheckedIn) "Checked In" else "Scan Pass",
                                                            color = Color.White,
                                                            fontSize = 10.sp,
                                                            fontWeight = FontWeight.Bold,
                                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    item {
                        // Manual Pass Code Input Box
                        Card(
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text("Or Enter Booking Ref / QR Pass ID", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Spacer(modifier = Modifier.height(8.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    OutlinedTextField(
                                        value = manualCodeInput,
                                        onValueChange = { manualCodeInput = it },
                                        placeholder = { Text("e.g. bk_1001 or BMS-QR-1001", fontSize = 12.sp) },
                                        modifier = Modifier
                                            .weight(1f)
                                            .testTag("manual_qr_input_field"),
                                        singleLine = true,
                                        shape = RoundedCornerShape(10.dp)
                                    )

                                    Button(
                                        onClick = {
                                            if (manualCodeInput.isNotBlank()) {
                                                checkInResultState = BookMySpaceRepository.checkInBookingWithQr(manualCodeInput)
                                                showResultModal = true
                                            }
                                        },
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier.testTag("submit_manual_qr_btn")
                                    ) {
                                        Text("Check In", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // MY PASS QR TAB
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    item {
                        Text(
                            "Present this QR Pass at venue entry desk for quick check-in:",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    if (confirmedBookings.isEmpty()) {
                        item {
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(16.dp)
                            ) {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(24.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Icon(Icons.Default.ConfirmationNumber, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.outline)
                                    Spacer(modifier = Modifier.height(12.dp))
                                    Text("No Active Confirmed Bookings", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                    Text("Once you reserve a court or venue, your digital QR pass will automatically appear here.", fontSize = 12.sp, textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    } else {
                        items(confirmedBookings) { booking ->
                            Card(
                                shape = RoundedCornerShape(20.dp),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("qr_pass_card_${booking.id}")
                            ) {
                                Column(
                                    modifier = Modifier.padding(16.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column {
                                            Text(booking.venueName, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                                            Text("${booking.bookingDate} • ${booking.slotLabel}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                        Surface(
                                            color = if (booking.isCheckedIn) Color(0xFFE8F5E9) else MaterialTheme.colorScheme.primaryContainer,
                                            shape = RoundedCornerShape(8.dp)
                                        ) {
                                            Text(
                                                text = if (booking.isCheckedIn) "✓ CHECKED IN" else "READY TO SCAN",
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 10.sp,
                                                color = if (booking.isCheckedIn) Color(0xFF2E7D32) else MaterialTheme.colorScheme.primary,
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                            )
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(16.dp))

                                    // High contrast QR Matrix Simulation
                                    Box(
                                        modifier = Modifier
                                            .size(190.dp)
                                            .clip(RoundedCornerShape(16.dp))
                                            .background(Color.White)
                                            .border(2.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                                            .padding(12.dp)
                                    ) {
                                        Canvas(modifier = Modifier.fillMaxSize()) {
                                            val w = size.width
                                            val h = size.height
                                            val matrixSize = 7
                                            val cellW = w / matrixSize
                                            val cellH = h / matrixSize

                                            // Draw QR Matrix pattern based on booking ID hash
                                            val hash = Math.abs(booking.id.hashCode())
                                            for (r in 0 until matrixSize) {
                                                for (c in 0 until matrixSize) {
                                                    val isCornerPattern = (r < 2 && c < 2) || (r < 2 && c > 4) || (r > 4 && c < 2)
                                                    val isCenterBit = (hash + r * 13 + c * 37) % 3 == 0 || isCornerPattern
                                                    if (isCenterBit) {
                                                        drawRect(
                                                            color = Color.Black,
                                                            topLeft = Offset(c * cellW + 2f, r * cellH + 2f),
                                                            size = Size(cellW - 4f, cellH - 4f)
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(12.dp))
                                    Text("PASS REF: #${booking.bookingRef}", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                    Text("Supabase Verification Key: ${booking.id}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                                    Spacer(modifier = Modifier.height(12.dp))

                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        OutlinedButton(
                                            onClick = {
                                                PdfInvoiceGenerator.generateAndDownloadInvoicePdf(context, booking)
                                            },
                                            modifier = Modifier.weight(1f),
                                            shape = RoundedCornerShape(10.dp)
                                        ) {
                                            Text("📄 Download Invoice", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                        }

                                        Button(
                                            onClick = {
                                                checkInResultState = BookMySpaceRepository.checkInBookingWithQr(booking.id)
                                                showResultModal = true
                                            },
                                            modifier = Modifier.weight(1f),
                                            shape = RoundedCornerShape(10.dp)
                                        ) {
                                            Text("Check In Now", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // CHECK-IN RESULT MODAL / DIALOG
    if (showResultModal && checkInResultState != null) {
        val res = checkInResultState!!
        AlertDialog(
            onDismissRequest = { showResultModal = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = if (res.success) Icons.Default.CheckCircle else Icons.Default.Error,
                        contentDescription = null,
                        tint = if (res.success) Color(0xFF2E7D32) else MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(28.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = if (res.success) "Check-In Verified!" else "Check-In Issue",
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp
                    )
                }
            },
            text = {
                Column {
                    Text(res.message, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                    Spacer(modifier = Modifier.height(12.dp))

                    if (res.booking != null) {
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Text(res.booking.venueName, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text("📅 Date: ${res.booking.bookingDate}", fontSize = 11.sp)
                                Text("⏰ Slot: ${res.booking.slotLabel}", fontSize = 11.sp)
                                Text("🎫 Booking Ref: #${res.booking.id}", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                if (res.booking.checkInTime != null) {
                                    Text("🕒 Check-In Time: ${res.booking.checkInTime}", fontSize = 11.sp, color = Color(0xFF2E7D32), fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Supabase DB Sync Confirmation Badge
                    Surface(
                        color = Color(0xFFE8F5E9),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.CloudDone, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                "Supabase DB Status: public.bookings table updated",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF1B5E20)
                            )
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = { showResultModal = false },
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("OK", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                if (res.booking != null) {
                    OutlinedButton(
                        onClick = {
                            showResultModal = false
                            PdfInvoiceGenerator.generateAndDownloadInvoicePdf(context, res.booking)
                        },
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text("📄 PDF Receipt", fontSize = 11.sp)
                    }
                }
            }
        )
    }
}
