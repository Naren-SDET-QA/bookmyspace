package com.bookmyspace.bookmyspace.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "recent_searches")
data class RecentSearchEntity(
    @PrimaryKey
    val query: String,
    val categoryFilter: String = "All",
    val timestamp: Long = System.currentTimeMillis()
)
