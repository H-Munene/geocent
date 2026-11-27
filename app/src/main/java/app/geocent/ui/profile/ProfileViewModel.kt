package app.geocent.ui.profile

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.geocent.data.CategoryRepository
import app.geocent.data.HotspotRepository
import app.geocent.data.db.CategoryEntity
import app.geocent.data.settings.ImportRange
import app.geocent.data.settings.SettingsStore
import app.geocent.ingest.ImportInboxWorker
import app.geocent.location.GeofenceManager
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settings: SettingsStore,
    private val categories: CategoryRepository,
    hotspots: HotspotRepository,
    private val geofences: GeofenceManager,
) : ViewModel() {
    private val sharing = SharingStarted.WhileSubscribed(5_000)

    val lastImportAt: StateFlow<Long?> = settings.lastImportAt.stateIn(viewModelScope, sharing, null)
    val importRange: StateFlow<ImportRange?> = settings.importRange.stateIn(viewModelScope, sharing, null)
    val hotspotCount: StateFlow<Int> = hotspots.observeAll().map { it.size }.stateIn(viewModelScope, sharing, 0)
    val categoryList: StateFlow<List<CategoryEntity>> = categories.observeAll().stateIn(viewModelScope, sharing, emptyList())

    private val _toasts = MutableSharedFlow<String>(extraBufferCapacity = 2)
    val toasts = _toasts.asSharedFlow()

    /** Hotspot alerts need precise location all the time; re-checked when the screen resumes. */
    fun canMonitorHotspots() = geofences.canMonitor()

    /** Imports SMS back to [range]; already-stored or forgotten messages are skipped. */
    fun importAgain(range: ImportRange) = viewModelScope.launch {
        settings.setImportRange(range)
        ImportInboxWorker.enqueue(context)
        _toasts.tryEmit("Importing messages in the background")
    }

    suspend fun usage(category: String) = categories.usage(category)

    fun deleteCategory(name: String) = viewModelScope.launch {
        categories.delete(name)
        _toasts.tryEmit("Deleted $name")
    }

    fun addCategory(name: String, iconKey: Int, colorArgb: Long) = viewModelScope.launch {
        categories.add(name, iconKey, colorArgb)
    }
}
