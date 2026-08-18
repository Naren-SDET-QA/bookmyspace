package com.bookmyspace.bookmyspace.util

import com.bookmyspace.bookmyspace.data.model.PgDetails
import com.bookmyspace.bookmyspace.data.model.PgSharingOption
import com.bookmyspace.bookmyspace.data.model.Venue

data class PgRentBreakdown(
    val monthlyBaseRent: Double,
    val securityDeposit: Double,
    val monthlyMaintenanceFee: Double,
    val tenureMonths: Int = 1
) {
    val monthlyPayable: Double
        get() = monthlyBaseRent + monthlyMaintenanceFee

    val totalMoveInCost: Double
        get() = monthlyBaseRent + securityDeposit + monthlyMaintenanceFee

    val totalTenureCost: Double
        get() = (monthlyBaseRent * tenureMonths) + securityDeposit + (monthlyMaintenanceFee * tenureMonths)
}

object PgRentCalculator {

    fun calculate(
        venue: Venue,
        selectedOptionIndex: Int = 0,
        tenureMonths: Int = 1
    ): PgRentBreakdown {
        val pg = venue.pgDetails
        if (pg == null) {
            val base = venue.pricingBaseAmount
            return PgRentBreakdown(
                monthlyBaseRent = base,
                securityDeposit = base,
                monthlyMaintenanceFee = 0.0,
                tenureMonths = tenureMonths
            )
        }

        val selectedOption: PgSharingOption? = pg.sharingOptions.getOrNull(selectedOptionIndex)
            ?: pg.sharingOptions.firstOrNull()

        val baseRent = selectedOption?.monthlyRent ?: venue.pricingBaseAmount
        val deposit = selectedOption?.depositAmount
            ?: (baseRent * pg.securityDepositMonths.coerceAtLeast(1.0))
        val maint = pg.maintenanceFee

        return PgRentBreakdown(
            monthlyBaseRent = baseRent,
            securityDeposit = deposit,
            monthlyMaintenanceFee = maint,
            tenureMonths = tenureMonths.coerceAtLeast(1)
        )
    }

    fun calculateFromDetails(
        pgDetails: PgDetails,
        selectedOption: PgSharingOption? = null,
        fallbackBase: Double = 0.0,
        tenureMonths: Int = 1
    ): PgRentBreakdown {
        val option = selectedOption ?: pgDetails.sharingOptions.firstOrNull()
        val baseRent = option?.monthlyRent ?: fallbackBase
        val deposit = option?.depositAmount ?: (baseRent * pgDetails.securityDepositMonths.coerceAtLeast(1.0))
        val maint = pgDetails.maintenanceFee

        return PgRentBreakdown(
            monthlyBaseRent = baseRent,
            securityDeposit = deposit,
            monthlyMaintenanceFee = maint,
            tenureMonths = tenureMonths.coerceAtLeast(1)
        )
    }
}
