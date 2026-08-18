package com.bookmyspace.bookmyspace.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface ReviewDao {
    @Query("SELECT * FROM reviews ORDER BY date DESC")
    fun getAllReviews(): Flow<List<ReviewEntity>>

    @Query("SELECT * FROM reviews WHERE venueId = :venueId ORDER BY date DESC")
    fun getReviewsByVenue(venueId: String): Flow<List<ReviewEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReview(review: ReviewEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(reviews: List<ReviewEntity>)

    @Query("DELETE FROM reviews WHERE id = :reviewId")
    suspend fun deleteReview(reviewId: String)
}
