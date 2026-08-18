package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.util.PgRentCalculator
import com.bookmyspace.bookmyspace.util.SpeechHelper

@Composable
fun VoiceReadoutButton(
    venue: Venue,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val speechHelper = SpeechHelper.getInstance(context)

    FilledTonalButton(
        onClick = {
            val spokenDetails = if (venue.pgDetails != null) {
                val bd = PgRentCalculator.calculate(venue)
                "${venue.name} in ${venue.city}. Monthly rent is ${bd.monthlyBaseRent.toInt()} rupees. Security deposit is ${bd.securityDeposit.toInt()} rupees. Call ${venue.contactPhone} to book."
            } else {
                "${venue.name} in ${venue.city}. Price is ${venue.pricingBaseAmount.toInt()} rupees. Accommodates up to ${venue.maxGuests} guests. Call manager at ${venue.contactPhone}."
            }
            speechHelper.speak(spokenDetails)
        },
        modifier = modifier.testTag("voice_readout_button"),
        shape = RoundedCornerShape(12.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 8.dp, vertical = 2.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Default.VolumeUp,
                contentDescription = "Read Aloud",
                modifier = Modifier.size(14.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = "🔊 Listen",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}
