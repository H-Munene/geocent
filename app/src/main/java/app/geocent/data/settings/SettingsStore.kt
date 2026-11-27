package app.geocent.data.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.LocalDateTime
import javax.inject.Inject
import javax.inject.Singleton

/** How far back to import SMS from the inbox; chosen during onboarding. */
enum class ImportRange(val days: Long?) {
    NONE(0),
    LAST_7_DAYS(7),
    LAST_30_DAYS(30),
    LAST_3_MONTHS(91),
    EVERYTHING(null);

    /** Oldest message time to import, or null for no lower bound. */
    fun since(now: LocalDateTime): LocalDateTime? = days?.let { now.minusDays(it) }
}

private val Context.dataStore by preferencesDataStore(name = "settings")

@Singleton
class SettingsStore @Inject constructor(@ApplicationContext private val context: Context) {

    private object Keys {
        val onboardingDone = booleanPreferencesKey("onboarding_done")
        val importRange = stringPreferencesKey("import_range")
        val lastImportAt = longPreferencesKey("last_import_at")
        val mapStyle = stringPreferencesKey("map_style")
    }

    val onboardingDone: Flow<Boolean> = context.dataStore.data.map { it[Keys.onboardingDone] ?: false }

    val importRange: Flow<ImportRange?> = context.dataStore.data.map { prefs ->
        prefs[Keys.importRange]?.let { runCatching { ImportRange.valueOf(it) }.getOrNull() }
    }

    val lastImportAt: Flow<Long?> = context.dataStore.data.map { it[Keys.lastImportAt] }

    val mapStyle: Flow<String?> = context.dataStore.data.map { it[Keys.mapStyle] }

    suspend fun completeOnboarding(range: ImportRange) {
        context.dataStore.edit {
            it[Keys.importRange] = range.name
            it[Keys.onboardingDone] = true
        }
    }

    suspend fun setImportRange(range: ImportRange) {
        context.dataStore.edit { it[Keys.importRange] = range.name }
    }

    suspend fun markImported(at: Long) {
        context.dataStore.edit { it[Keys.lastImportAt] = at }
    }

    suspend fun setMapStyle(url: String) {
        context.dataStore.edit { it[Keys.mapStyle] = url }
    }

    suspend fun isOnboardingDone(): Boolean = onboardingDone.first()
}
