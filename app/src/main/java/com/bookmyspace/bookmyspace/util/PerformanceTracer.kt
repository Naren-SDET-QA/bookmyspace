package com.bookmyspace.bookmyspace.util

import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.tracing.Trace
import androidx.tracing.trace
import java.util.concurrent.ConcurrentHashMap

/**
 * Categories of trace operations to isolate specific application performance domains.
 */
enum class TraceCategory(val label: String, val thresholdMs: Long) {
    MAP_RENDER("MAP_RENDER", 16L),
    DATA_FETCH("DATA_FETCH", 100L),
    ROOM_QUERY("ROOM_QUERY", 50L),
    NETWORK("NETWORK", 200L),
    COMPOSE_RENDER("COMPOSE_RENDER", 16L),
    GENERAL("GENERAL", 30L)
}

/**
 * Metric summary tracking aggregate execution statistics for an operation.
 */
data class TraceMetricSummary(
    val name: String,
    val category: TraceCategory,
    var callCount: Long = 0L,
    var totalDurationNs: Long = 0L,
    var maxDurationMs: Double = 0.0,
    var minDurationMs: Double = Double.MAX_VALUE,
    var slowCallCount: Long = 0L
) {
    val averageDurationMs: Double
        get() = if (callCount > 0) (totalDurationNs / 1_000_000.0) / callCount else 0.0
}

/**
 * Custom Performance Tracer utility wrapping androidx.tracing.
 * Measures execution time for Map Rendering, Data Fetching, Room Queries, and UI compositions,
 * logging metrics to Logcat and recording statistics to identify system bottlenecks.
 */
object PerformanceTracer {

    private const val TAG = "BookMySpaceTracer"
    private val metricsMap = ConcurrentHashMap<String, TraceMetricSummary>()

    data class ActiveTrace(
        val name: String,
        val startTimeMs: Long = System.currentTimeMillis(),
        val attributes: MutableMap<String, String> = mutableMapOf(),
        val metrics: MutableMap<String, Long> = mutableMapOf()
    )

    private val activeTraces = ConcurrentHashMap<String, ActiveTrace>()

    fun startTrace(traceName: String): ActiveTrace {
        val active = ActiveTrace(traceName)
        activeTraces[traceName] = active
        Log.i(TAG, "⚡ [PerfTrace Started] $traceName")
        return active
    }

    fun stopTrace(traceName: String, extraAttributes: Map<String, String> = emptyMap()): Long {
        val active = activeTraces.remove(traceName)
        val duration = if (active != null) System.currentTimeMillis() - active.startTimeMs else 0L
        Log.i(TAG, "⏱️ [PerfTrace Completed] $traceName took ${duration}ms | attrs: $extraAttributes")
        return duration
    }

    /**
     * Executes a synchronous block inside an androidx.tracing slice,
     * timing the execution and recording metrics under the specified TraceCategory.
     */
    inline fun <T> traceSection(
        sectionName: String,
        category: TraceCategory = TraceCategory.GENERAL,
        crossinline block: () -> T
    ): T {
        val traceLabel = "${category.label}_$sectionName"
        val startNs = System.nanoTime()
        return try {
            trace(traceLabel) {
                block()
            }
        } finally {
            val durationNs = System.nanoTime() - startNs
            recordMetric(sectionName, category, durationNs)
        }
    }

    /**
     * Executes a suspend block inside an androidx.tracing section,
     * timing the asynchronous execution (e.g. data fetching or repository queries)
     * and recording metrics.
     */
    suspend inline fun <T> traceAsyncSection(
        sectionName: String,
        category: TraceCategory = TraceCategory.DATA_FETCH,
        crossinline block: suspend () -> T
    ): T {
        val traceLabel = "${category.label}_$sectionName"
        val startNs = System.nanoTime()
        Trace.beginSection(traceLabel)
        return try {
            block()
        } finally {
            Trace.endSection()
            val durationNs = System.nanoTime() - startNs
            recordMetric(sectionName, category, durationNs)
        }
    }

    /**
     * Specialized utility to trace Map Rendering operations (e.g. tile updates, overlay generation, marker creation).
     */
    suspend inline fun <T> traceMapRender(
        operationName: String,
        crossinline block: suspend () -> T
    ): T {
        return traceAsyncSection(
            sectionName = operationName,
            category = TraceCategory.MAP_RENDER,
            block = block
        )
    }

    /**
     * Specialized utility to trace asynchronous Data Fetching operations (e.g. network requests, repository queries).
     */
    suspend inline fun <T> traceDataFetch(
        operationName: String,
        crossinline block: suspend () -> T
    ): T {
        return traceAsyncSection(
            sectionName = operationName,
            category = TraceCategory.DATA_FETCH,
            block = block
        )
    }

    /**
     * Generic sync trace block compatible with legacy code.
     */
    fun <T> traceBlock(traceName: String, block: () -> T): T {
        return traceSection(sectionName = traceName, category = TraceCategory.COMPOSE_RENDER) {
            block()
        }
    }

    /**
     * Records an execution sample into the internal metrics map and logs potential performance bottlenecks.
     */
    fun recordMetric(sectionName: String, category: TraceCategory, durationNs: Long) {
        val durationMs = durationNs / 1_000_000.0
        val isSlow = durationMs > category.thresholdMs

        val key = "${category.label}:$sectionName"
        val summary = metricsMap.getOrPut(key) {
            TraceMetricSummary(name = sectionName, category = category)
        }

        synchronized(summary) {
            summary.callCount++
            summary.totalDurationNs += durationNs
            if (durationMs > summary.maxDurationMs) summary.maxDurationMs = durationMs
            if (durationMs < summary.minDurationMs) summary.minDurationMs = durationMs
            if (isSlow) summary.slowCallCount++
        }

        if (isSlow) {
            Log.w(
                TAG,
                "⚠️ [BOTTLENECK DETECTED] [${category.label}] '$sectionName' took ${"%.2f".format(durationMs)}ms (threshold: ${category.thresholdMs}ms)"
            )
        } else {
            Log.d(
                TAG,
                "✅ [PERF METRIC] [${category.label}] '$sectionName' took ${"%.2f".format(durationMs)}ms"
            )
        }
    }

    /**
     * Retrieves a snapshot of all accumulated metrics.
     */
    fun getMetricsSnapshot(): Map<String, TraceMetricSummary> {
        return metricsMap.toMap()
    }

    /**
     * Clears recorded performance metrics.
     */
    fun resetMetrics() {
        metricsMap.clear()
        Log.i(TAG, "🧹 Metrics log cleared.")
    }

    /**
     * Generates and logs a complete summary report of all tracked operations,
     * highlighting identified bottlenecks sorted by average execution duration.
     */
    fun logBottleneckReport() {
        if (metricsMap.isEmpty()) {
            Log.i(TAG, "📊 [Bottleneck Report] No trace metrics recorded yet.")
            return
        }

        val sortedSummaries = metricsMap.values.sortedByDescending { it.averageDurationMs }
        val sb = StringBuilder()
        sb.appendLine("==========================================================================")
        sb.appendLine("📊 PERFORMANCE & BOTTLENECK METRICS REPORT (androidx.tracing)")
        sb.appendLine("==========================================================================")

        sortedSummaries.forEach { summary ->
            val status = if (summary.slowCallCount > 0) "⚠️ BOTTLENECK" else "✅ OPTIMAL"
            sb.appendLine(
                "[$status] [${summary.category.label}] ${summary.name}\n" +
                "  • Calls: ${summary.callCount} | Slow Calls: ${summary.slowCallCount}\n" +
                "  • Avg: ${"%.2f".format(summary.averageDurationMs)}ms | Max: ${"%.2f".format(summary.maxDurationMs)}ms | Min: ${"%.2f".format(summary.minDurationMs)}ms"
            )
        }
        sb.appendLine("==========================================================================")

        Log.i(TAG, sb.toString())
    }
}

/**
 * Composable helper to trace Composition time and detect recomposition jank.
 */
@Composable
fun TraceComposition(name: String) {
    SideEffect {
        PerformanceTracer.traceSection("Composition_$name", category = TraceCategory.COMPOSE_RENDER) {}
    }
}

