package com.bookmyspace.bookmyspace.ui.components

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.zIndex
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.SpeechHelper
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

enum class MessageSender { USER, ASSISTANT }

data class HelpChatMessage(
    val id: String = "msg_${System.currentTimeMillis()}",
    val sender: MessageSender,
    val text: String,
    val timestamp: String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date()),
    val actionType: String? = null, // e.g., "CALL", "WHATSAPP", "NAVIGATE"
    val actionData: String? = null
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContextAwareHelpFab(
    currentRoute: String?,
    onNavigateToRoute: ((String) -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    var showChatSheet by remember { mutableStateOf(false) }

    val coroutineScope = rememberCoroutineScope()
    val animX = remember { androidx.compose.animation.core.Animatable(0f) }
    val animY = remember { androidx.compose.animation.core.Animatable(0f) }

    // Auto-minimizes on venue details/booking/payment routes to avoid overlapping buttons/time slots
    val isBookingOrDetailRoute = remember(currentRoute) {
        currentRoute?.startsWith("venues/") == true ||
        currentRoute?.startsWith("bookings/") == true ||
        currentRoute?.contains("/book") == true ||
        currentRoute?.contains("/pay") == true
    }

    var isMinimized by remember(isBookingOrDetailRoute) { mutableStateOf(isBookingOrDetailRoute) }
    var isDismissed by remember { mutableStateOf(false) }
    var isLeftAligned by remember { mutableStateOf(false) }

    // Auto-minimize chat bot when user interacts with booking time selector
    val slotTrigger by com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository.slotInteractionTrigger.collectAsState()
    LaunchedEffect(slotTrigger) {
        if (slotTrigger > 0L) {
            showChatSheet = false
            isMinimized = true
            if (animY.value > -60f) {
                animY.animateTo(
                    targetValue = -120f,
                    animationSpec = androidx.compose.animation.core.spring(
                        dampingRatio = androidx.compose.animation.core.Spring.DampingRatioMediumBouncy,
                        stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow
                    )
                )
            }
        }
    }

    // Automatically minimize and elevate FAB if entering booking/detail screen to clear the bottom 'Book' CTA button
    LaunchedEffect(isBookingOrDetailRoute) {
        if (isBookingOrDetailRoute) {
            isMinimized = true
            if (animY.value > -40f) {
                animY.animateTo(
                    targetValue = -60f,
                    animationSpec = androidx.compose.animation.core.spring(
                        dampingRatio = androidx.compose.animation.core.Spring.DampingRatioMediumBouncy,
                        stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow
                    )
                )
            }
        } else {
            if (animY.value < -40f) {
                animY.animateTo(
                    targetValue = 0f,
                    animationSpec = androidx.compose.animation.core.spring(
                        dampingRatio = androidx.compose.animation.core.Spring.DampingRatioMediumBouncy,
                        stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow
                    )
                )
            }
        }
    }

    // Collision Prevention: detects overlap with bottom 'Book' CTA button area
    val isOverlappingBookingArea by remember(isBookingOrDetailRoute) {
        derivedStateOf { isBookingOrDetailRoute && animY.value > -75f }
    }

    val dynamicOpacity by animateFloatAsState(
        targetValue = if (isOverlappingBookingArea) 0.35f else 1.0f,
        label = "fab_collision_opacity"
    )

    val dynamicZIndex = if (isOverlappingBookingArea) 1f else 10f

    // Auto-minimize expanded FAB after 20 seconds of inactivity
    LaunchedEffect(isMinimized, showChatSheet) {
        if (!isMinimized && !showChatSheet) {
            delay(20000L)
            isMinimized = true
        }
    }

    if (isDismissed) return

    val selectedSection by BookMySpaceRepository.selectedCustomerSection.collectAsState()

    // Derive context title
    val contextLabel = remember(currentRoute, selectedSection) {
        val sectionPrefix = selectedSection?.let { "${it.title}: " } ?: ""
        when {
            currentRoute?.startsWith("venues/") == true && currentRoute.endsWith("/book") -> "${sectionPrefix}Booking Policy"
            currentRoute?.startsWith("venues/") == true -> "${sectionPrefix}Venue Policy & Rules"
            currentRoute?.startsWith("bookings/") == true && currentRoute.endsWith("/pay") -> "Payment Help"
            currentRoute == "search" || currentRoute?.startsWith("search?") == true -> "${sectionPrefix}Search & Filter Tips"
            currentRoute == "bookings" -> "Cancellation & Receipts"
            currentRoute == "profile" -> "Account & Support"
            selectedSection != null -> "${selectedSection!!.title} Help"
            else -> "Booking Assistance"
        }
    }

    Box(
        modifier = modifier
            .zIndex(dynamicZIndex)
            .graphicsLayer { alpha = dynamicOpacity }
            .offset { IntOffset(animX.value.roundToInt(), animY.value.roundToInt()) }
            .pointerInput(isBookingOrDetailRoute) {
                detectDragGestures(
                    onDragEnd = {
                        coroutineScope.launch {
                            // Snap horizontal: left edge vs right edge docking
                            val targetX = if (animX.value < -100f) -210f else 0f
                            isLeftAligned = (targetX == -210f)

                            // Avoid 'Book' button area & clamp vertical within screen boundaries
                            var targetY = animY.value
                            if (isBookingOrDetailRoute) {
                                // Bottom booking bar sits near bottom (offsetY >= -60f)
                                // If released near bottom, snap upwards to clear Book button
                                if (targetY > -60f) {
                                    targetY = -120f
                                }
                            }
                            targetY = targetY.coerceIn(-500f, 0f)

                            val springSpec = androidx.compose.animation.core.spring<Float>(
                                dampingRatio = androidx.compose.animation.core.Spring.DampingRatioMediumBouncy,
                                stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow
                            )

                            launch { animX.animateTo(targetX, springSpec) }
                            launch { animY.animateTo(targetY, springSpec) }
                        }
                    }
                ) { change, dragAmount ->
                    change.consume()
                    coroutineScope.launch {
                        animX.snapTo(animX.value + dragAmount.x)
                        animY.snapTo(animY.value + dragAmount.y)
                    }
                }
            }
    ) {
        if (isMinimized) {
            // Compact, non-intrusive floating bubble for booking time
            Surface(
                onClick = { showChatSheet = true },
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                shadowElevation = 6.dp,
                modifier = Modifier
                    .testTag("context_aware_help_fab_minimized")
                    .height(40.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.DragHandle,
                        contentDescription = "Drag to move",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Default.SmartToy,
                        contentDescription = "Context AI Help",
                        modifier = Modifier.size(18.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "AI Help",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    IconButton(
                        onClick = { isMinimized = false },
                        modifier = Modifier.size(22.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.UnfoldMore,
                            contentDescription = "Expand FAB",
                            modifier = Modifier.size(14.dp)
                        )
                    }
                    IconButton(
                        onClick = { isDismissed = true },
                        modifier = Modifier.size(22.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Dismiss Help FAB",
                            modifier = Modifier.size(12.dp)
                        )
                    }
                }
            }
        } else {
            // Expanded Movable Floating Action Button
            Surface(
                shape = RoundedCornerShape(26.dp),
                color = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                shadowElevation = 8.dp,
                modifier = Modifier
                    .testTag("context_aware_help_fab")
                    .height(52.dp)
            ) {
                Row(
                    modifier = Modifier.padding(start = 8.dp, end = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.OpenWith,
                        contentDescription = "Drag to move anywhere",
                        modifier = Modifier
                            .size(18.dp)
                            .padding(end = 2.dp),
                        tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f)
                    )

                    Row(
                        modifier = Modifier
                            .clickable { showChatSheet = true }
                            .padding(vertical = 6.dp, horizontal = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.SmartToy,
                            contentDescription = "Context AI Help Chat",
                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = "Help Chat",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Text(
                                text = contextLabel,
                                fontSize = 9.sp,
                                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(4.dp))

                    IconButton(
                        onClick = {
                            isLeftAligned = !isLeftAligned
                            val targetX = if (isLeftAligned) -210f else 0f
                            coroutineScope.launch {
                                animX.animateTo(
                                    targetX,
                                    androidx.compose.animation.core.spring(
                                        dampingRatio = androidx.compose.animation.core.Spring.DampingRatioMediumBouncy,
                                        stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow
                                    )
                                )
                            }
                        },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.SwapHoriz,
                            contentDescription = "Move Left/Right",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }

                    IconButton(
                        onClick = { isMinimized = true },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.UnfoldLess,
                            contentDescription = "Minimize FAB",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        }
    }

    if (showChatSheet) {
        ContextHelpChatSheet(
            currentRoute = currentRoute,
            onDismiss = { showChatSheet = false },
            onNavigateToRoute = onNavigateToRoute
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContextHelpChatSheet(
    currentRoute: String?,
    onDismiss: () -> Unit,
    onNavigateToRoute: ((String) -> Unit)? = null
) {
    val context = LocalContext.current
    val speechHelper = remember { SpeechHelper.getInstance(context) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    var inputText by remember { mutableStateOf("") }
    var isThinking by remember { mutableStateOf(false) }
    var lastUserInteractionTime by remember { mutableLongStateOf(System.currentTimeMillis()) }

    // Auto-minimize chatbot after 20 seconds of user inactivity
    LaunchedEffect(lastUserInteractionTime) {
        delay(20_000L)
        onDismiss()
    }

    // Extract venue details if on venue details screen
    val activeVenueId = remember(currentRoute) {
        if (currentRoute?.startsWith("venues/") == true) {
            val parts = currentRoute.split("/")
            if (parts.size >= 2 && parts[1] != "book") parts[1] else if (parts.size >= 3) parts[1] else null
        } else null
    }

    val activeVenue = remember(activeVenueId) {
        if (activeVenueId != null) BookMySpaceRepository.getVenueById(activeVenueId) else null
    }

    // Context description
    val contextDescription = remember(currentRoute, activeVenue) {
        when {
            activeVenue != null -> "📍 Active Space: ${activeVenue.name} (${activeVenue.city})"
            currentRoute?.contains("/book") == true -> "📍 Active Flow: Slot Selection & Policy Agreement"
            currentRoute?.contains("/pay") == true -> "📍 Active Flow: Payment Gateway & Refund Terms"
            currentRoute == "search" || currentRoute?.startsWith("search?") == true -> "📍 Active Screen: Venue & PG Search Catalog"
            currentRoute == "bookings" -> "📍 Active Screen: My Bookings & Pass History"
            else -> "📍 Active Context: General BookMySpace Help"
        }
    }

    // Quick suggestions based on screen context
    val quickQuestions = remember(currentRoute, activeVenue) {
        when {
            activeVenue != null -> listOf(
                "What is the cancellation policy for ${activeVenue.name}?",
                "Is outside food and catering allowed?",
                "What are the operational hours and alcohol policy?",
                "How do I contact venue manager directly?",
                "What amenities are included in base rent?"
            )
            currentRoute?.contains("/book") == true -> listOf(
                "Can I reschedule or edit my slot after booking?",
                "Is full advance payment mandatory?",
                "What happens if I cancel 24 hours prior?",
                "Are taxes & GST included in slot price?"
            )
            currentRoute?.contains("/pay") == true -> listOf(
                "Is UPI & Credit Card payment safe here?",
                "What if payment fails but amount is deducted?",
                "When will I get my payment receipt?",
                "How do instant refunds work for failed transactions?"
            )
            currentRoute == "search" || currentRoute?.startsWith("search?") == true -> listOf(
                "How do PG sharing options and deposit work?",
                "How to filter by maximum capacity & budget?",
                "What is the difference between hourly and daily booking?"
            )
            currentRoute == "bookings" -> listOf(
                "How to get my entry QR pass for the venue?",
                "How do I request a cancellation or refund?",
                "Who to call if venue manager is unresponsive?"
            )
            else -> listOf(
                "How does 1-Tap Quick Book mode work?",
                "What is the refund & cancellation policy?",
                "How do I list my venue or PG as an owner?",
                "Is Bol-ke-Book voice search free?"
            )
        }
    }

    // Default welcome message
    val messages = remember {
        mutableStateListOf(
            HelpChatMessage(
                sender = MessageSender.ASSISTANT,
                text = "Hello! I am your AI Context Help Assistant. I see you are currently on: $contextDescription.\n\nAsk me any question about venue policies, cancellation rules, PG terms, or booking help!"
            )
        )
    }

    fun handleSend(question: String) {
        if (question.isBlank()) return
        val userMsg = HelpChatMessage(sender = MessageSender.USER, text = question)
        messages.add(userMsg)
        inputText = ""
        isThinking = true

        scope.launch {
            listState.animateScrollToItem(messages.size - 1)
            delay(600) // Realistic instant thinking simulation

            val response = generateContextualAnswer(question, currentRoute, activeVenue)
            messages.add(response)
            isThinking = false
            delay(100)
            listState.animateScrollToItem(messages.size - 1)
            speechHelper.speak(response.text.take(150)) // Speak key answer snippet
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.85f)
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 16.dp)
        ) {
            // Sheet Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier.size(38.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.SmartToy,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Context AI Assistant",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                        Text(
                            text = contextDescription,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            maxLines = 1
                        )
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "Close Help Chat")
                }
            }

            Divider(modifier = Modifier.padding(vertical = 10.dp))

            // Quick Question Chips Row
            Text(
                text = "💡 Tap a quick question for instant policy answers:",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(6.dp))

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(quickQuestions) { q ->
                    SuggestionChip(
                        onClick = { handleSend(q) },
                        label = { Text(q, fontSize = 11.sp, maxLines = 1) },
                        shape = RoundedCornerShape(12.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Chat Messages List
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(messages) { msg ->
                    HelpChatMessageBubble(
                        message = msg,
                        onSpeak = { text -> speechHelper.speak(text) },
                        onAction = { actionType, actionData ->
                            when (actionType) {
                                "CALL" -> {
                                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${actionData ?: "9876543210"}"))
                                    context.startActivity(intent)
                                }
                                "WHATSAPP" -> {
                                    val url = "https://api.whatsapp.com/send?phone=91${(actionData ?: "9876543210").replace("-", "")}&text=Hello%20Manager%2C%20I%20have%20a%20query%20about%20booking"
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                    context.startActivity(intent)
                                }
                            }
                        }
                    )
                }

                if (isThinking) {
                    item {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(start = 8.dp)
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Checking venue policy knowledge base...",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Message Input Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    placeholder = { Text("Ask about policies, rules, refunds...", fontSize = 12.sp) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("help_chat_input_field"),
                    shape = RoundedCornerShape(20.dp),
                    maxLines = 2
                )
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = { handleSend(inputText) },
                    modifier = Modifier
                        .size(48.dp)
                        .background(MaterialTheme.colorScheme.primary, CircleShape)
                        .testTag("help_chat_send_button"),
                    enabled = inputText.isNotBlank()
                ) {
                    Icon(
                        imageVector = Icons.Default.Send,
                        contentDescription = "Send Message",
                        tint = MaterialTheme.colorScheme.onPrimary
                    )
                }
            }
        }
    }
}

@Composable
fun HelpChatMessageBubble(
    message: HelpChatMessage,
    onSpeak: (String) -> Unit,
    onAction: (String, String?) -> Unit
) {
    val isUser = message.sender == MessageSender.USER

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start
    ) {
        Surface(
            shape = RoundedCornerShape(
                topStart = 16.dp,
                topEnd = 16.dp,
                bottomStart = if (isUser) 16.dp else 4.dp,
                bottomEnd = if (isUser) 4.dp else 16.dp
            ),
            color = if (isUser) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
            contentColor = if (isUser) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
            shadowElevation = 1.dp,
            modifier = Modifier.widthIn(max = 310.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(
                    text = message.text,
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )

                if (!isUser) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = message.timestamp,
                            fontSize = 9.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                        )

                        IconButton(
                            onClick = { onSpeak(message.text) },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.VolumeUp,
                                contentDescription = "Read Aloud",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }

                    if (message.actionType != null) {
                        Spacer(modifier = Modifier.height(6.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            if (message.actionType == "CALL") {
                                Button(
                                    onClick = { onAction("CALL", message.actionData) },
                                    shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                                    modifier = Modifier.height(32.dp),
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp)
                                ) {
                                    Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(12.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Call Manager", fontSize = 10.sp)
                                }
                            }
                            if (message.actionType == "WHATSAPP") {
                                Button(
                                    onClick = { onAction("WHATSAPP", message.actionData) },
                                    shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF00897B)),
                                    modifier = Modifier.height(32.dp),
                                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp)
                                ) {
                                    Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(12.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("WhatsApp", fontSize = 10.sp)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// Smart context knowledge base generator
fun generateContextualAnswer(
    q: String,
    currentRoute: String?,
    activeVenue: com.bookmyspace.bookmyspace.data.model.Venue?
): HelpChatMessage {
    val query = q.lowercase(Locale.ROOT)

    // Context check for Active Venue
    if (activeVenue != null) {
        if (query.contains("cancellation") || query.contains("cancel") || query.contains("refund")) {
            return HelpChatMessage(
                sender = MessageSender.ASSISTANT,
                text = "📋 Cancellation Policy for ${activeVenue.name}:\n\n" +
                        "• Full 100% refund if cancelled at least 48 hours prior to booking slot.\n" +
                        "• 50% refund if cancelled between 24 and 48 hours prior.\n" +
                        "• Non-refundable if cancelled within 24 hours of event start.\n\n" +
                        "Refunds are processed automatically to your original UPI/Card payment method within 24 hours."
            )
        }
        if (query.contains("food") || query.contains("catering") || query.contains("outside")) {
            val allowed = activeVenue.facilities.any { it.facility.contains("Catering", ignoreCase = true) || it.facility.contains("Food", ignoreCase = true) } || activeVenue.foodOptions.contains("Outside", ignoreCase = true)
            return HelpChatMessage(
                sender = MessageSender.ASSISTANT,
                text = "🍱 Catering & Food Policy:\n\n" +
                        (if (allowed) "Yes! Outside catering and food services are permitted at ${activeVenue.name}."
                        else "In-house catering packages are recommended. ${activeVenue.foodOptions}") +
                        "\n\nContact the manager directly to finalize custom menu arrangements."
            )
        }
        if (query.contains("manager") || query.contains("contact") || query.contains("phone") || query.contains("call") || query.contains("whatsapp")) {
            return HelpChatMessage(
                sender = MessageSender.ASSISTANT,
                text = "📞 Direct Contact for ${activeVenue.name}:\n\n" +
                        "Manager Phone: ${activeVenue.contactPhone}\n" +
                        "Operational Hours: 08:00 AM - 11:00 PM\n" +
                        "Address: ${activeVenue.addressLine1}, ${activeVenue.city}",
                actionType = "CALL",
                actionData = activeVenue.contactPhone
            )
        }
    }

    // Booking Flow Context
    if (currentRoute?.contains("/book") == true) {
        if (query.contains("reschedule") || query.contains("edit") || query.contains("change")) {
            return HelpChatMessage(
                sender = MessageSender.ASSISTANT,
                text = "🗓️ Slot Rescheduling Policy:\n\n" +
                        "You can reschedule your slot up to 12 hours before start time free of charge from the 'My Bookings' tab! Date changes depend on slot availability."
            )
        }
        if (query.contains("gst") || query.contains("tax") || query.contains("price")) {
            return HelpChatMessage(
                sender = MessageSender.ASSISTANT,
                text = "💵 Pricing Breakdown:\n\n" +
                        "Base slot prices include venue access and standard amenities. GST (18%) and refundable security deposit (if applicable) are shown transparently before final payment."
            )
        }
    }

    // Payment Gateway Context
    if (currentRoute?.contains("/pay") == true || query.contains("pay") || query.contains("upi") || query.contains("card")) {
        return HelpChatMessage(
            sender = MessageSender.ASSISTANT,
            text = "🔒 Payment Gateway & Safety:\n\n" +
                    "• Supported methods: GPay, PhonePe, Paytm, All Bank UPIs, Credit/Debit Cards, and Net Banking.\n" +
                    "• Transactions are 256-bit SSL encrypted.\n" +
                    "• If payment is deducted but status stays pending, our auto-reconciliation engine resolves or refunds it within 15 minutes."
        )
    }

    // Search or General PG Policy
    if (query.contains("pg") || query.contains("hostel") || query.contains("sharing") || query.contains("deposit")) {
        return HelpChatMessage(
            sender = MessageSender.ASSISTANT,
            text = "🏠 PG & Hostel Policy Summary:\n\n" +
                    "• Rent includes Wi-Fi, 3-time meals (North & South Indian), biometric entry, and daily room cleaning.\n" +
                    "• Security deposit is equivalent to 1 month's rent and 100% refundable upon 15-day notice checkout.\n" +
                    "• Both Boys and Girls PG options feature separate 24/7 security wardens."
        )
    }

    // Default Fallback Policy Answer
    return HelpChatMessage(
        sender = MessageSender.ASSISTANT,
        text = "ℹ️ BookMySpace Instant Guidance:\n\n" +
                "• All bookings generate a verified digital QR pass.\n" +
                "• Emergency cancellation or date modification is supported via 'My Bookings'.\n" +
                "• 24/7 Customer Support is accessible via support@bookmyspace.app or calling support."
    )
}
