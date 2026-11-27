package app.geocent.di

import android.content.Context
import androidx.room.Room
import app.geocent.data.db.GeocentDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun database(@ApplicationContext context: Context): GeocentDatabase =
        Room.databaseBuilder(context, GeocentDatabase::class.java, GeocentDatabase.NAME)
            .addCallback(GeocentDatabase.seedCallback)
            .build()

    @Provides fun transactionDao(db: GeocentDatabase) = db.transactions()
    @Provides fun merchantCategoryDao(db: GeocentDatabase) = db.merchantCategories()
    @Provides fun categoryDao(db: GeocentDatabase) = db.categories()
    @Provides fun budgetDao(db: GeocentDatabase) = db.budgets()
    @Provides fun hotspotDao(db: GeocentDatabase) = db.hotspots()
}
