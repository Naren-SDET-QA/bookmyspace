package com.bookmyspace.bookmyspace.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [
        RecentSearchEntity::class,
        ReviewEntity::class,
        MapTileEntity::class,
        VenueMarkerEntity::class
    ],
    version = 7,
    exportSchema = false
)
abstract class BookMySpaceRoomDatabase : RoomDatabase() {
    abstract fun recentSearchDao(): RecentSearchDao
    abstract fun reviewDao(): ReviewDao
    abstract fun mapTileDao(): MapTileDao
    abstract fun venueMarkerDao(): VenueMarkerDao

    companion object {
        @Volatile
        private var INSTANCE: BookMySpaceRoomDatabase? = null

        fun getDatabase(context: Context): BookMySpaceRoomDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    BookMySpaceRoomDatabase::class.java,
                    "bookmyspace_room_db"
                )
                .fallbackToDestructiveMigration()
                .build()
                INSTANCE = instance
                instance
            }
        }

        fun setDatabaseForTesting(database: BookMySpaceRoomDatabase?) {
            INSTANCE = database
        }
    }
}
