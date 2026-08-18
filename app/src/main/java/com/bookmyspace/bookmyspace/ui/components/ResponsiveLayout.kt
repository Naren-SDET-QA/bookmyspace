package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Material 3 Window Width Size Classes for adaptive layouts
 */
enum class ResponsiveWindowWidthClass {
    COMPACT,   // < 600dp (standard portrait phones)
    MEDIUM,    // 600dp - 839dp (foldables unfolded, small tablets, landscape phones)
    EXPANDED   // >= 840dp (large tablets, desktop, ChromeOS)
}

/**
 * Data class holding responsive sizing metrics and layout configurations
 */
data class ResponsiveDimensions(
    val windowWidthClass: ResponsiveWindowWidthClass,
    val availableWidth: Dp,
    val isCompact: Boolean,
    val isMedium: Boolean,
    val isExpanded: Boolean,
    val isTabletOrWide: Boolean,
    val categoryGridColumns: Int,
    val resultsGridColumns: Int,
    val horizontalPadding: Dp,
    val gridSpacing: Dp,
    val maxContentWidth: Dp
)

/**
 * Calculates ResponsiveDimensions based on current available width
 */
fun calculateResponsiveDimensions(width: Dp): ResponsiveDimensions {
    val windowClass = when {
        width < 600.dp -> ResponsiveWindowWidthClass.COMPACT
        width < 840.dp -> ResponsiveWindowWidthClass.MEDIUM
        else -> ResponsiveWindowWidthClass.EXPANDED
    }

    val isCompact = windowClass == ResponsiveWindowWidthClass.COMPACT
    val isMedium = windowClass == ResponsiveWindowWidthClass.MEDIUM
    val isExpanded = windowClass == ResponsiveWindowWidthClass.EXPANDED
    val isTabletOrWide = !isCompact

    return ResponsiveDimensions(
        windowWidthClass = windowClass,
        availableWidth = width,
        isCompact = isCompact,
        isMedium = isMedium,
        isExpanded = isExpanded,
        isTabletOrWide = isTabletOrWide,
        categoryGridColumns = if (isCompact) 1 else 2,
        resultsGridColumns = if (isCompact) 1 else if (isMedium) 2 else 2,
        horizontalPadding = if (isCompact) 20.dp else if (isMedium) 28.dp else 36.dp,
        gridSpacing = if (isCompact) 12.dp else 16.dp,
        maxContentWidth = 1100.dp
    )
}

/**
 * Composable builder that measures available constraints and provides [ResponsiveDimensions]
 */
@Composable
fun ResponsiveLayout(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.(ResponsiveDimensions) -> Unit
) {
    BoxWithConstraints(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.TopCenter
    ) {
        val responsiveInfo = remember(maxWidth) {
            calculateResponsiveDimensions(maxWidth)
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .widthIn(max = responsiveInfo.maxContentWidth)
        ) {
            content(responsiveInfo)
        }
    }
}

/**
 * Extension for LazyListScope to render items in a responsive grid across rows
 */
fun <T> LazyListScope.responsiveGridItems(
    items: List<T>,
    columns: Int,
    key: ((T) -> Any)? = null,
    horizontalSpacing: Dp = 12.dp,
    verticalSpacing: Dp = 12.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 20.dp),
    itemContent: @Composable (item: T, index: Int) -> Unit
) {
    if (columns <= 1) {
        // Single column layout
        items(
            count = items.size,
            key = if (key != null) { index -> key(items[index]) } else null
        ) { index ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(contentPadding)
                    .padding(vertical = verticalSpacing / 2)
            ) {
                itemContent(items[index], index)
            }
        }
    } else {
        // Multi-column grid chunked into rows
        val chunkedItems = items.chunked(columns)
        items(
            count = chunkedItems.size,
            key = if (key != null) { rowIndex ->
                chunkedItems[rowIndex].joinToString("-") { key(it).toString() }
            } else null
        ) { rowIndex ->
            val rowItems = chunkedItems[rowIndex]
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(contentPadding)
                    .padding(vertical = verticalSpacing / 2),
                horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
                verticalAlignment = Alignment.CenterVertically
            ) {
                rowItems.forEachIndexed { itemIndex, item ->
                    val globalIndex = rowIndex * columns + itemIndex
                    Box(modifier = Modifier.weight(1f)) {
                        itemContent(item, globalIndex)
                    }
                }
                // Fill remainder of row with empty spaces for balanced alignment
                val remainder = columns - rowItems.size
                if (remainder > 0) {
                    repeat(remainder) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}
