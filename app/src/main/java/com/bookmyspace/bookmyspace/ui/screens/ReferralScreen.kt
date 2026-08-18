package com.bookmyspace.bookmyspace.ui.screens

import android.content.Context
import android.content.Intent
import androidx.compose.animation.*
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.ReferralItem
import com.bookmyspace.bookmyspace.data.model.ReferralStatus
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReferralScreen(
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    val userReferralCode by BookMySpaceRepository.userReferralCode.collectAsState()
    val referralList by BookMySpaceRepository.referrals.collectAsState()
    val totalReferralCreditsEarned by BookMySpaceRepository.totalReferralCreditsEarned.collectAsState()
    val walletBalance by BookMySpaceRepository.walletBalance.collectAsState()

    var inputClaimCode by remember { mutableStateOf("") }
    var friendNameInput by remember { mutableStateOf("") }
    var friendContactInput by remember { mutableStateOf("") }
    var showQrCode by remember { mutableStateOf(false) }
    var isSendingInvite by remember { mutableStateOf(false) }

    val completedCount = referralList.count { it.status == ReferralStatus.COMPLETED }
    val pendingCount = referralList.count { it.status == ReferralStatus.PENDING }

    val shareText = "Hey! Join BookMySpace to book sports courts, event venues & party halls near you. Use my referral code *$userReferralCode* to get ₹500 instant credits on your 1st booking! Download now: https://bookmyspace.app/invite?ref=$userReferralCode"

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Refer & Earn Credits", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = {
                            scope.launch {
                                snackbarHostState.showSnackbar("Give ₹500, Get ₹500! Referral credits apply automatically at venue checkout.")
                            }
                        }
                    ) {
                        Icon(Icons.Default.HelpOutline, contentDescription = "Referral Info")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .testTag("referral_screen"),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Hero Banner: Earnings & Wallet Summary Card
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("referral_hero_card"),
                    shape = RoundedCornerShape(24.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.Transparent)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Brush.linearGradient(
                                    colors = listOf(
                                        MaterialTheme.colorScheme.primary,
                                        MaterialTheme.colorScheme.tertiary
                                    )
                                )
                            )
                            .padding(20.dp)
                    ) {
                        Column {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Surface(
                                    color = Color.White.copy(alpha = 0.2f),
                                    shape = RoundedCornerShape(12.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text("🎁 REFERRAL PROGRAM", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
                                    }
                                }

                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.AccountBalanceWallet, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Wallet: ₹${walletBalance.toInt()}", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            Text("Give ₹500, Get ₹500! 💰", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                "Invite friends to BookMySpace. They receive ₹500 welcome credit, and you earn ₹500 when they complete their first booking!",
                                fontSize = 13.sp,
                                color = Color.White.copy(alpha = 0.9f)
                            )

                            Spacer(modifier = Modifier.height(20.dp))

                            HorizontalDivider(color = Color.White.copy(alpha = 0.3f))

                            Spacer(modifier = Modifier.height(16.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column {
                                    Text("TOTAL REWARDED", fontSize = 11.sp, color = Color.White.copy(alpha = 0.8f))
                                    Text("₹${totalReferralCreditsEarned.toInt()}", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                }
                                Column {
                                    Text("SUCCESSFUL REFERS", fontSize = 11.sp, color = Color.White.copy(alpha = 0.8f))
                                    Text("$completedCount Friends", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                }
                                Column {
                                    Text("PENDING", fontSize = 11.sp, color = Color.White.copy(alpha = 0.8f))
                                    Text("$pendingCount Friends", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                }
                            }
                        }
                    }
                }
            }

            // Your Unique Referral Code Box
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f))
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "YOUR UNIQUE REFERRAL CODE",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            letterSpacing = 1.sp
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        Surface(
                            color = MaterialTheme.colorScheme.surface,
                            shape = RoundedCornerShape(16.dp),
                            border = androidx.compose.foundation.BorderStroke(2.dp, MaterialTheme.colorScheme.primary),
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("referral_code_display_box")
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = userReferralCode,
                                    fontSize = 24.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    letterSpacing = 2.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )

                                Button(
                                    onClick = {
                                        haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                                        val clip = android.content.ClipData.newPlainText("Referral Code", userReferralCode)
                                        clipboard.setPrimaryClip(clip)
                                        scope.launch {
                                            snackbarHostState.showSnackbar("Copied '$userReferralCode' to clipboard!")
                                        }
                                    },
                                    shape = RoundedCornerShape(12.dp),
                                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                                    modifier = Modifier.testTag("copy_referral_code_btn")
                                ) {
                                    Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Copy", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            // Native Android Share Button
                            Button(
                                onClick = {
                                    haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                                    val sendIntent = Intent().apply {
                                        action = Intent.ACTION_SEND
                                        putExtra(Intent.EXTRA_TEXT, shareText)
                                        type = "text/plain"
                                    }
                                    val shareIntent = Intent.createChooser(sendIntent, "Share BookMySpace Referral Code")
                                    context.startActivity(shareIntent)
                                },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("share_referral_btn"),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Share Code", fontWeight = FontWeight.Bold)
                            }

                            // Show QR Code Button
                            OutlinedButton(
                                onClick = {
                                    haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                                    showQrCode = !showQrCode
                                },
                                modifier = Modifier.testTag("toggle_qr_code_btn"),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(Icons.Default.QrCode2, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(if (showQrCode) "Hide QR" else "QR Code")
                            }
                        }

                        // Animated QR Code Card Display
                        AnimatedVisibility(
                            visible = showQrCode,
                            enter = expandVertically() + fadeIn(),
                            exit = shrinkVertically() + fadeOut()
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.padding(top = 16.dp)
                            ) {
                                Surface(
                                    color = Color.White,
                                    shape = RoundedCornerShape(16.dp),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color.LightGray),
                                    modifier = Modifier.padding(8.dp)
                                ) {
                                    Column(
                                        modifier = Modifier.padding(16.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        // Visual Canvas Simulated QR Code
                                        Canvas(modifier = Modifier.size(140.dp)) {
                                            val cellSize = size.width / 7f
                                            val darkColor = Color.Black
                                            val primaryColor = Color(0xFF1E88E5)

                                            // Draw outer frame
                                            drawRect(color = darkColor, size = size, style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4f))

                                            // Draw corner squares
                                            drawRect(color = primaryColor, topLeft = Offset(0f, 0f), size = androidx.compose.ui.geometry.Size(cellSize * 2.2f, cellSize * 2.2f))
                                            drawRect(color = primaryColor, topLeft = Offset(size.width - cellSize * 2.2f, 0f), size = androidx.compose.ui.geometry.Size(cellSize * 2.2f, cellSize * 2.2f))
                                            drawRect(color = primaryColor, topLeft = Offset(0f, size.height - cellSize * 2.2f), size = androidx.compose.ui.geometry.Size(cellSize * 2.2f, cellSize * 2.2f))

                                            // Random QR pattern
                                            for (r in 1..5) {
                                                for (c in 1..5) {
                                                    if ((r + c) % 2 == 0 || (r * c) % 3 == 0) {
                                                        drawRect(
                                                            color = if ((r + c) % 3 == 0) primaryColor else darkColor,
                                                            topLeft = Offset(c * cellSize, r * cellSize),
                                                            size = androidx.compose.ui.geometry.Size(cellSize * 0.85f, cellSize * 0.85f)
                                                        )
                                                    }
                                                }
                                            }
                                        }

                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text(userReferralCode, fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color.Black)
                                        Text("Scan to join BookMySpace", fontSize = 10.sp, color = Color.Gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Redeem / Enter Friend's Code Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.4f))
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.CardGiftcard, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Have a Friend's Referral Code?", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        }

                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            "Enter a referral code to instantly claim ₹500 welcome credit added to your wallet!",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            OutlinedTextField(
                                value = inputClaimCode,
                                onValueChange = { inputClaimCode = it.uppercase() },
                                placeholder = { Text("e.g. BMS-ANKIT01") },
                                singleLine = true,
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("claim_referral_input"),
                                shape = RoundedCornerShape(12.dp)
                            )

                            Button(
                                onClick = {
                                    haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                                    val result = BookMySpaceRepository.claimReferralCode(inputClaimCode)
                                    result.fold(
                                        onSuccess = { msg ->
                                            scope.launch { snackbarHostState.showSnackbar(msg) }
                                            inputClaimCode = ""
                                        },
                                        onFailure = { err ->
                                            scope.launch { snackbarHostState.showSnackbar("❌ ${err.message}") }
                                        }
                                    )
                                },
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.testTag("apply_referral_claim_btn")
                            ) {
                                Text("Claim ₹500", fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            // How It Works Timeline Steps
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp)
                ) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Text("How Referral Program Works", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Spacer(modifier = Modifier.height(14.dp))

                        val steps = listOf(
                            Triple("1", "Share Your Code", "Send your unique code '$userReferralCode' or direct invite link to friends & colleagues."),
                            Triple("2", "Friend Gets ₹500 Welcome Bonus", "When your friend signs up with your code, they receive ₹500 instant wallet credits."),
                            Triple("3", "Earn ₹500 on First Booking", "As soon as your friend completes their 1st venue booking, you automatically get ₹500 credited!")
                        )

                        steps.forEachIndexed { idx, step ->
                            val (num, title, desc) = step
                            Row(verticalAlignment = Alignment.Top) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.primary),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(num, fontWeight = FontWeight.Bold, color = Color.White, fontSize = 14.sp)
                                }
                                Spacer(modifier = Modifier.width(14.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(title, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(desc, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                            if (idx < steps.size - 1) {
                                Spacer(modifier = Modifier.height(12.dp))
                            }
                        }
                    }
                }
            }

            // Send Direct Invite Form
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp)
                ) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Send, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Send Direct Invitation", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Send an SMS / Email invitation directly to your friend:", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                        Spacer(modifier = Modifier.height(12.dp))

                        OutlinedTextField(
                            value = friendNameInput,
                            onValueChange = { friendNameInput = it },
                            label = { Text("Friend's Full Name") },
                            leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("invite_friend_name_input"),
                            shape = RoundedCornerShape(12.dp)
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = friendContactInput,
                            onValueChange = { friendContactInput = it },
                            label = { Text("Friend's Email or Mobile Number") },
                            leadingIcon = { Icon(Icons.Default.ContactPhone, contentDescription = null) },
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("invite_friend_contact_input"),
                            shape = RoundedCornerShape(12.dp)
                        )

                        Spacer(modifier = Modifier.height(14.dp))

                        Button(
                            onClick = {
                                if (friendNameInput.isBlank() || friendContactInput.isBlank()) {
                                    scope.launch { snackbarHostState.showSnackbar("Please enter friend's name and email or phone.") }
                                    return@Button
                                }
                                haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                                isSendingInvite = true
                                BookMySpaceRepository.inviteFriendByEmailOrPhone(friendNameInput, friendContactInput)
                                scope.launch {
                                    snackbarHostState.showSnackbar("✉️ Referral invitation sent to $friendNameInput!")
                                }
                                friendNameInput = ""
                                friendContactInput = ""
                                isSendingInvite = false
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("send_direct_invite_btn"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            if (isSendingInvite) {
                                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = MaterialTheme.colorScheme.onPrimary)
                            } else {
                                Icon(Icons.Default.Send, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Send Invite & Earn ₹500", fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            // Referral History & Status Tracker
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Your Referral History", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Text("${referralList.size} Total", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            if (referralList.isEmpty()) {
                item {
                    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Default.GroupAdd, contentDescription = null, modifier = Modifier.size(40.dp), tint = MaterialTheme.colorScheme.primary)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text("No referrals yet", fontWeight = FontWeight.Bold)
                            Text("Share your code with friends to start earning credits!", fontSize = 12.sp, textAlign = TextAlign.Center)
                        }
                    }
                }
            } else {
                items(referralList, key = { it.id }) { item ->
                    ReferralHistoryCard(
                        item = item,
                        onSimulateBooking = {
                            BookMySpaceRepository.simulateFriendCompletedBooking(item.id)
                            scope.launch {
                                snackbarHostState.showSnackbar("🎉 ${item.friendName} completed 1st booking! ₹500 credited to your wallet.")
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun ReferralHistoryCard(
    item: ReferralItem,
    onSimulateBooking: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("referral_history_item_${item.id}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(42.dp)
                            .clip(CircleShape)
                            .background(
                                if (item.status == ReferralStatus.COMPLETED)
                                    MaterialTheme.colorScheme.primaryContainer
                                else
                                    MaterialTheme.colorScheme.surfaceVariant
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = item.friendName.take(1).uppercase(),
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            fontSize = 18.sp
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(item.friendName, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        Text(item.friendEmail, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("Invited: ${item.dateInvited}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f))
                    }
                }

                Column(horizontalAlignment = Alignment.End) {
                    if (item.status == ReferralStatus.COMPLETED) {
                        Surface(
                            color = Color(0xFFE8F5E9),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "✓ COMPLETED",
                                color = Color(0xFF2E7D32),
                                fontSize = 10.sp,
                                fontWeight = FontWeight.ExtraBold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "+₹${item.creditEarned.toInt()}",
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 15.sp,
                            color = Color(0xFF2E7D32)
                        )
                    } else {
                        Surface(
                            color = MaterialTheme.colorScheme.secondaryContainer,
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "⏳ PENDING 1st BOOKING",
                                color = MaterialTheme.colorScheme.onSecondaryContainer,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "₹500 Pending",
                            fontWeight = FontWeight.Medium,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            if (item.status == ReferralStatus.PENDING) {
                Spacer(modifier = Modifier.height(10.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("DEV Simulation Test:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    TextButton(
                        onClick = onSimulateBooking,
                        modifier = Modifier.testTag("simulate_booking_ref_${item.id}")
                    ) {
                        Text("Simulate 1st Booking → Claim ₹500", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
