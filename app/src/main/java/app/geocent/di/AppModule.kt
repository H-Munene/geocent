package app.geocent.di

import app.geocent.ingest.HotspotRefresher
import app.geocent.ingest.WorkManagerHotspotRefresher
import app.geocent.location.FusedLocationProvider
import app.geocent.location.LocationProvider
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
abstract class AppModule {
    @Binds
    abstract fun locationProvider(impl: FusedLocationProvider): LocationProvider

    @Binds
    abstract fun hotspotRefresher(impl: WorkManagerHotspotRefresher): HotspotRefresher
}
