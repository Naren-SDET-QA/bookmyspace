package com.bookmyspace.bookmyspace.util

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import androidx.core.content.FileProvider
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PdfInvoiceGenerator {

    /**
     * Generates a professional booking confirmation PDF invoice and saves it to device storage.
     */
    fun generateAndDownloadInvoicePdf(context: Context, booking: Booking): File? {
        val pdfDocument = PdfDocument()

        // Page setup: A4 size at 72 dpi is 595 x 842 points
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas

        val paint = Paint()
        val titlePaint = Paint()

        // 1. White Background
        canvas.drawColor(Color.WHITE)

        // 2. Header Emerald Banner
        paint.color = Color.parseColor("#1B5E20") // Dark Emerald Green
        canvas.drawRect(0f, 0f, 595f, 100f, paint)

        // App Logo & Title
        titlePaint.color = Color.WHITE
        titlePaint.textSize = 24f
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("BookMySpace", 40f, 48f, titlePaint)

        titlePaint.textSize = 11f
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        canvas.drawText("OFFICIAL BOOKING RECEIPT & ENTRY PASS", 40f, 72f, titlePaint)

        // Invoice ID & Date on Right Header
        titlePaint.textSize = 11f
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        titlePaint.textAlign = Paint.Align.RIGHT
        canvas.drawText("INVOICE #${booking.id.uppercase()}", 555f, 48f, titlePaint)
        val dateToday = SimpleDateFormat("dd MMM yyyy", Locale.getDefault()).format(Date())
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        canvas.drawText("Issued: $dateToday", 555f, 68f, titlePaint)

        titlePaint.textAlign = Paint.Align.LEFT // reset alignment

        // 3. Venue & Booking Details
        var y = 140f

        paint.color = Color.parseColor("#111111")
        paint.textSize = 18f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText(booking.venueName, 40f, y, paint)

        y += 24f
        paint.textSize = 12f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        paint.color = Color.parseColor("#555555")
        canvas.drawText("Slot Timing: ${booking.slotLabel}", 40f, y, paint)

        y += 20f
        canvas.drawText("Booking Date: ${booking.bookingDate}", 40f, y, paint)

        y += 20f
        canvas.drawText("Booking Status: ${booking.status.name} (${if (booking.isPaid) "PAID IN FULL" else "PAYMENT PENDING"})", 40f, y, paint)

        y += 20f
        val refCode = booking.bookingRef.ifEmpty { "BMS-REF-${booking.id.takeLast(6).uppercase()}" }
        canvas.drawText("Booking Reference: $refCode", 40f, y, paint)

        // Divider Line
        y += 25f
        paint.color = Color.parseColor("#CCCCCC")
        paint.strokeWidth = 1.5f
        canvas.drawLine(40f, y, 555f, y, paint)

        // 4. Payment Table Header
        y += 30f
        paint.color = Color.parseColor("#F5F5F5")
        canvas.drawRect(40f, y - 18f, 555f, y + 12f, paint)

        paint.color = Color.parseColor("#111111")
        paint.textSize = 12f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("Item Description", 50f, y, paint)
        canvas.drawText("Amount (₹)", 450f, y, paint)

        // Table Rows
        y += 35f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        paint.color = Color.parseColor("#333333")
        canvas.drawText("Venue Slot Booking Fee (${booking.slotLabel})", 50f, y, paint)
        canvas.drawText("₹${String.format(Locale.US, "%.2f", booking.baseAmount)}", 450f, y, paint)

        y += 25f
        canvas.drawText("GSTA & Service Platform Tax (18%)", 50f, y, paint)
        canvas.drawText("₹${String.format(Locale.US, "%.2f", booking.taxAmount)}", 450f, y, paint)

        y += 25f
        paint.color = Color.parseColor("#E0E0E0")
        paint.strokeWidth = 1f
        canvas.drawLine(40f, y, 555f, y, paint)

        // Total Row
        y += 25f
        paint.color = Color.parseColor("#1B5E20")
        paint.textSize = 15f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("Total Paid Amount", 50f, y, paint)
        canvas.drawText("₹${String.format(Locale.US, "%.2f", booking.totalAmount)}", 450f, y, paint)

        // 5. Entry Pass & Security Stamp Box
        y += 60f
        val stampPaint = Paint().apply {
            color = Color.parseColor("#E8F5E9")
            style = Paint.Style.FILL
        }
        val borderPaint = Paint().apply {
            color = Color.parseColor("#2E7D32")
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        canvas.drawRoundRect(40f, y, 555f, y + 105f, 16f, 16f, stampPaint)
        canvas.drawRoundRect(40f, y, 555f, y + 105f, 16f, 16f, borderPaint)

        paint.color = Color.parseColor("#1B5E20")
        paint.textSize = 13f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("✓ VERIFIED ENTRY PASS • PRESENT AT VENUE", 60f, y + 35f, paint)

        paint.color = Color.parseColor("#333333")
        paint.textSize = 10f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        val securityToken = "BMS-SEC-${Math.abs(booking.id.hashCode()) % 899999 + 100000}"
        canvas.drawText("Security Check Token: $securityToken", 60f, y + 60f, paint)
        canvas.drawText("Verification: Show this PDF invoice or app QR pass at venue desk for entry.", 60f, y + 80f, paint)

        // 6. Footer Notice
        paint.color = Color.parseColor("#888888")
        paint.textSize = 9f
        canvas.drawText("BookMySpace Technologies Ltd. • Official Digital Confirmation Invoice", 140f, 805f, paint)

        pdfDocument.finishPage(page)

        // Save PDF
        var outputFile: File? = null
        val fileName = "BookMySpace_Invoice_${booking.id}.pdf"

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/BookMySpace")
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { outputStream ->
                        pdfDocument.writeTo(outputStream)
                    }
                }
            }

            // Also write to local app storage for instant preview/sharing
            val downloadsDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: context.cacheDir
            outputFile = File(downloadsDir, fileName)
            FileOutputStream(outputFile).use { fos ->
                pdfDocument.writeTo(fos)
            }

            pdfDocument.close()

            Toast.makeText(context, "Invoice PDF saved to Downloads: $fileName", Toast.LENGTH_LONG).show()

            BookMySpaceRepository.logAnalyticsEvent("pdf_invoice_downloaded", mapOf("booking_id" to booking.id, "amount" to booking.totalAmount.toString()), "invoice")

            // Trigger file open/share intent
            openOrSharePdf(context, outputFile)

        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(context, "Error saving PDF: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
            pdfDocument.close()
        }

        return outputFile
    }

    /**
     * Generates a comprehensive PDF document exporting all past booking history records from local Room DB.
     */
    fun exportBookingHistoryPdf(context: Context, bookings: List<Booking>): File? {
        val pdfDocument = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas

        val paint = Paint()
        val titlePaint = Paint()

        // 1. White Background
        canvas.drawColor(Color.WHITE)

        // 2. Header Banner
        paint.color = Color.parseColor("#1B5E20") // Emerald Green
        canvas.drawRect(0f, 0f, 595f, 100f, paint)

        titlePaint.color = Color.WHITE
        titlePaint.textSize = 22f
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("BookMySpace", 40f, 45f, titlePaint)

        titlePaint.textSize = 11f
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        canvas.drawText("COMPLETE BOOKING HISTORY STATEMENT", 40f, 70f, titlePaint)

        titlePaint.textAlign = Paint.Align.RIGHT
        val dateToday = SimpleDateFormat("dd MMM yyyy", Locale.getDefault()).format(Date())
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("STATEMENT DATE", 555f, 45f, titlePaint)
        titlePaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        canvas.drawText(dateToday, 555f, 65f, titlePaint)
        titlePaint.textAlign = Paint.Align.LEFT

        var y = 130f

        // 3. Summary Stats Banner
        val totalSpent = bookings.sumOf { it.totalAmount }
        val confirmedCount = bookings.count { it.status == com.bookmyspace.bookmyspace.data.model.BookingStatus.CONFIRMED || it.status == com.bookmyspace.bookmyspace.data.model.BookingStatus.COMPLETED }

        paint.color = Color.parseColor("#F1F8E9")
        canvas.drawRoundRect(40f, y, 555f, y + 60f, 12f, 12f, paint)

        paint.color = Color.parseColor("#1B5E20")
        paint.textSize = 12f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("Total Recorded Bookings: ${bookings.size}", 55f, y + 26f, paint)
        canvas.drawText("Confirmed: $confirmedCount", 250f, y + 26f, paint)

        paint.color = Color.parseColor("#2E7D32")
        canvas.drawText("Total Expenditure: ₹${String.format(Locale.US, "%.2f", totalSpent)}", 55f, y + 48f, paint)

        y += 80f

        // 4. Table Header
        paint.color = Color.parseColor("#1B5E20")
        canvas.drawRect(40f, y - 18f, 555f, y + 12f, paint)

        paint.color = Color.WHITE
        paint.textSize = 10f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        canvas.drawText("Booking ID", 50f, y, paint)
        canvas.drawText("Venue Name", 130f, y, paint)
        canvas.drawText("Date", 320f, y, paint)
        canvas.drawText("Status", 410f, y, paint)
        canvas.drawText("Amount", 480f, y, paint)

        y += 24f

        // 5. Table Rows
        paint.textSize = 9f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)

        bookings.forEachIndexed { index, b ->
            if (y > 780f) {
                return@forEachIndexed
            }

            paint.color = if (index % 2 == 0) Color.parseColor("#FAFAFA") else Color.WHITE
            canvas.drawRect(40f, y - 14f, 555f, y + 10f, paint)

            paint.color = Color.parseColor("#222222")
            canvas.drawText(b.id.takeLast(8).uppercase(), 50f, y, paint)

            val truncatedVenue = if (b.venueName.length > 26) b.venueName.take(24) + ".." else b.venueName
            canvas.drawText(truncatedVenue, 130f, y, paint)

            canvas.drawText(b.bookingDate, 320f, y, paint)

            paint.color = when (b.status) {
                com.bookmyspace.bookmyspace.data.model.BookingStatus.CONFIRMED -> Color.parseColor("#2E7D32")
                com.bookmyspace.bookmyspace.data.model.BookingStatus.COMPLETED -> Color.parseColor("#1565C0")
                com.bookmyspace.bookmyspace.data.model.BookingStatus.CANCELLED -> Color.parseColor("#C62828")
                else -> Color.parseColor("#EF6C00")
            }
            canvas.drawText(b.status.name, 410f, y, paint)

            paint.color = Color.parseColor("#111111")
            canvas.drawText("₹${String.format(Locale.US, "%.0f", b.totalAmount)}", 480f, y, paint)

            y += 22f
        }

        // Footer
        paint.color = Color.parseColor("#888888")
        paint.textSize = 8f
        canvas.drawText("Exported from BookMySpace Room Local Storage • Verified Record", 150f, 815f, paint)

        pdfDocument.finishPage(page)

        var outputFile: File? = null
        val fileName = "BookMySpace_Booking_History_${System.currentTimeMillis()}.pdf"

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/BookMySpace")
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { outputStream ->
                        pdfDocument.writeTo(outputStream)
                    }
                }
            }

            val downloadsDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: context.cacheDir
            outputFile = File(downloadsDir, fileName)
            FileOutputStream(outputFile).use { fos ->
                pdfDocument.writeTo(fos)
            }

            pdfDocument.close()
            Toast.makeText(context, "Booking History PDF exported to Downloads!", Toast.LENGTH_LONG).show()

            BookMySpaceRepository.addAuditLog("PDF_HISTORY_EXPORTED", "Exported ${bookings.size} booking records to PDF document.")
            openOrSharePdf(context, outputFile)
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(context, "Error exporting PDF: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
            pdfDocument.close()
        }

        return outputFile
    }

    private fun openOrSharePdf(context: Context, file: File) {
        try {
            val uri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.provider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(intent, "Open Booking PDF Invoice")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(chooser)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
