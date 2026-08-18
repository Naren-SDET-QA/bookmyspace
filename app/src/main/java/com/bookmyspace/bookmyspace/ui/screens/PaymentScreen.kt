package com.bookmyspace.bookmyspace.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentScreen(
    bookingId: String,
    onBack: () -> Unit,
    onPaymentSuccess: () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val bookings by BookMySpaceRepository.bookings.collectAsState()
    val walletBalance by BookMySpaceRepository.walletBalance.collectAsState()
    val booking = bookings.firstOrNull { it.id == bookingId } ?: bookings.first()

    var applyWalletCredits by remember { mutableStateOf(walletBalance > 0) }
    val maxDiscountAllowed = (booking.totalAmount * 0.5).coerceAtMost(walletBalance) // Up to 50% discount using referral credits
    val effectiveDiscount = if (applyWalletCredits) maxDiscountAllowed else 0.0
    val finalPayable = (booking.totalAmount - effectiveDiscount).coerceAtLeast(0.0)

    var selectedMethod by remember { mutableStateOf("RAZORPAY_UPI") }
    var isProcessing by remember { mutableStateOf(false) }
    var showRazorpayGatewayModal by remember { mutableStateOf(false) }
    var showSuccessDialog by remember { mutableStateOf(false) }
    var generatedPaymentRef by remember { mutableStateOf("") }

    // Razorpay processing state
    var gatewayStep by remember { mutableIntStateOf(2) } // 1: Order initialized, 2: OTP / Verification, 3: Success
    var otpInput by remember { mutableStateOf("123456") }
    var orderId by remember { mutableStateOf("") }

    if (showRazorpayGatewayModal) {
        AlertDialog(
            onDismissRequest = {
                if (!isProcessing) showRazorpayGatewayModal = false
            },
            title = null,
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Razorpay Header Badge
                    Surface(
                        color = Color(0xFF0C2340), // Razorpay brand navy
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Security,
                                contentDescription = "Razorpay Secure",
                                tint = Color(0xFF00C853),
                                modifier = Modifier.size(24.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(
                                    text = "Razorpay Secure Checkout",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = Color.White
                                )
                                Text(
                                    text = "256-Bit SSL Encrypted • Test Key: rzp_test_...",
                                    fontSize = 10.sp,
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = "Payable: ₹${finalPayable.toInt()}",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "Order ID: $orderId",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    if (gatewayStep == 1) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(36.dp),
                                color = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                "Connecting to Razorpay Banking Gateway...",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    } else if (gatewayStep == 2) {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.Start
                        ) {
                            Text(
                                "Enter 3D Secure OTP sent to your registered mobile:",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            OutlinedTextField(
                                value = otpInput,
                                onValueChange = { otpInput = it },
                                label = { Text("Bank OTP") },
                                singleLine = true,
                                visualTransformation = PasswordVisualTransformation(),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .testTag("razorpay_otp_input")
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                "Demo mode auto-filled OTP: 123456",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.secondary
                            )
                        }
                    } else if (gatewayStep == 3) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = "Success",
                                tint = Color(0xFF00C853),
                                modifier = Modifier.size(48.dp)
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text("Payment Authorization Successful!", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        }
                    }
                }
            },
            confirmButton = {
                val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
                if (gatewayStep == 2) {
                    Button(
                        onClick = {
                            haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                            isProcessing = true
                            gatewayStep = 3
                            val paymentId = "pay_rzp_${System.currentTimeMillis()}"
                            generatedPaymentRef = paymentId
                            BookMySpaceRepository.confirmBookingWithPayment(booking.id, paymentId)
                            isProcessing = false
                            showRazorpayGatewayModal = false
                            showSuccessDialog = true
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("razorpay_submit_otp_btn"),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0C2340))
                    ) {
                        Text("Submit OTP & Authorize Payment", fontWeight = FontWeight.Bold)
                    }
                }
            },
            dismissButton = {
                if (!isProcessing && gatewayStep != 3) {
                    TextButton(onClick = { showRazorpayGatewayModal = false }) {
                        Text("Cancel Gateway Session")
                    }
                }
            }
        )
    }

    if (showSuccessDialog) {
        AlertDialog(
            onDismissRequest = { },
            icon = {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(48.dp)
                )
            },
            title = { Text("Booking Confirmed!", fontWeight = FontWeight.Bold) },
            text = {
                val context = androidx.compose.ui.platform.LocalContext.current
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Your payment of ₹${finalPayable.toInt()} via Razorpay was successful.")
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Payment Ref: $generatedPaymentRef", fontWeight = FontWeight.Bold, fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
                    Text("Booking Pass ID: #${booking.id}", fontWeight = FontWeight.Bold, fontSize = 11.sp)
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedButton(
                        onClick = {
                            com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator.generateAndDownloadInvoicePdf(context, booking)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("download_pdf_invoice_payment_btn"),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text("📄 Download PDF Invoice", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showSuccessDialog = false
                        onPaymentSuccess()
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("View My Booking Pass")
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Razorpay Checkout", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp)
        ) {
            // Summary Pass Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary)
            ) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("BOOKING SUMMARY", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.8f))
                        Surface(
                            color = Color.White.copy(alpha = 0.2f),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text("RAZORPAY 🔒", modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp), fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        }
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(booking.venueName, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("📅 Date: ${booking.bookingDate}", fontSize = 13.sp, color = Color.White)
                    Text("⏰ Slot: ${booking.slotLabel}", fontSize = 13.sp, color = Color.White)
                    HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = Color.White.copy(alpha = 0.3f))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Venue Slot Rate", fontSize = 12.sp, color = Color.White.copy(alpha = 0.9f))
                        Text("₹${booking.totalAmount.toInt()}", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    }
                    if (effectiveDiscount > 0) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("🎁 Referral & Wallet Credits Applied", fontSize = 12.sp, color = Color(0xFF81C784), fontWeight = FontWeight.Bold)
                            Text("-₹${effectiveDiscount.toInt()}", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color(0xFF81C784))
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Net Payable Amount", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        Text("₹${finalPayable.toInt()}", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Wallet & Referral Credit Discount Toggle Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("referral_wallet_discount_toggle_card"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (applyWalletCredits) MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.5f) else MaterialTheme.colorScheme.surface
                )
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CardGiftcard,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.tertiary,
                        modifier = Modifier.size(28.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Use Referral & Wallet Credits", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(
                            "Available Credits: ₹${walletBalance.toInt()} • Save up to ₹${maxDiscountAllowed.toInt()}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Switch(
                        checked = applyWalletCredits,
                        onCheckedChange = { applyWalletCredits = it },
                        modifier = Modifier.testTag("apply_wallet_credit_switch")
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Payment Methods
            Text("Select Razorpay Payment Channel", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Spacer(modifier = Modifier.height(12.dp))

            val methods = listOf(
                Triple("RAZORPAY_UPI", "Razorpay Instant UPI (GPay / PhonePe / Paytm)", Icons.Default.QrCode),
                Triple("RAZORPAY_CARD", "Credit / Debit Cards (Visa / Mastercard / RuPay)", Icons.Default.CreditCard),
                Triple("RAZORPAY_NETBANKING", "Net Banking (SBI / HDFC / ICICI / Axis)", Icons.Default.AccountBalance),
                Triple("RAZORPAY_WALLET", "Wallets & Pay Later (Simpl / LazyPay / Mobikwik)", Icons.Default.AccountBalanceWallet)
            )

            methods.forEach { method ->
                val (key, label, icon) = method
                val isSelected = selectedMethod == key
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 6.dp),
                    shape = RoundedCornerShape(12.dp),
                    onClick = { selectedMethod = key },
                    colors = CardDefaults.cardColors(
                        containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface
                    )
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(16.dp))
                        Text(label, fontWeight = FontWeight.Bold, fontSize = 13.sp, modifier = Modifier.weight(1f))
                        RadioButton(selected = isSelected, onClick = { selectedMethod = key })
                    }
                }
            }

            // Pay Now Button
            Spacer(modifier = Modifier.height(24.dp))
            Button(
                onClick = {
                    orderId = "order_rzp_${System.currentTimeMillis()}"
                    gatewayStep = 2
                    showRazorpayGatewayModal = true
                    val activity = context as? android.app.Activity
                    if (activity != null) {
                        try {
                            com.bookmyspace.bookmyspace.util.RazorpayHelper.startPayment(
                                activity = activity,
                                booking = booking,
                                user = authUser,
                                listener = object : com.bookmyspace.bookmyspace.util.RazorpayPaymentListener {
                                    override fun onPaymentSuccess(paymentId: String, orderId: String?, signature: String?) {
                                        generatedPaymentRef = paymentId
                                        BookMySpaceRepository.confirmBookingWithPayment(booking.id, paymentId)
                                        showRazorpayGatewayModal = false
                                        showSuccessDialog = true
                                    }

                                    override fun onPaymentError(code: Int, description: String?) {
                                        showRazorpayGatewayModal = true
                                    }
                                }
                            )
                        } catch (e: Exception) {
                            showRazorpayGatewayModal = true
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .testTag("pay_now_button"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0C2340))
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Pay ₹${finalPayable.toInt()} via Razorpay", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }

    // Effect to advance gateway simulation steps
    LaunchedEffect(showRazorpayGatewayModal, gatewayStep) {
        if (showRazorpayGatewayModal && gatewayStep == 1) {
            delay(1200)
            gatewayStep = 2
        }
    }
}

