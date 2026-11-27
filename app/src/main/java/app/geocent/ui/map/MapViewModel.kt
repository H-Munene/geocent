package app.geocent.ui.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.geocent.data.AreaSummary
import app.geocent.data.CategoryRepository
import app.geocent.data.TransactionRepository
import app.geocent.data.db.CategoryEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.data.settings.SettingsStore
import app.geocent.domain.Place
import app.geocent.domain.groupByLocation
import app.geocent.domain.thisMonth
import app.geocent.domain.thisWeek
import app.geocent.domain.toEpochMillis
import app.geocent.domain.today
import app.geocent.location.LocationProvider
import app.geocent.notify.BudgetChecker
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import javax.inject.Inject

/** Time window for the "spending around here" card. */
enum class AreaPeriod(val label: String) { WEEK("This week"), MONTH("This month"), ALL("All time") }

/** The point the user is inspecting, and how far around it to look. */
data class AreaSelection(
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Double = 300.0,
    val period: AreaPeriod = AreaPeriod.MONTH,
)

/** Spending totals for the header pill. */
data class PeriodTotals(val today: Double = 0.0, val week: Double = 0.0, val month: Double = 0.0)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class MapViewModel @Inject constructor(
    private val transactions: TransactionRepository,
    private val categoryRepository: CategoryRepository,
    private val settings: SettingsStore,
    private val location: LocationProvider,
    private val budgetChecker: BudgetChecker,
) : ViewModel() {

    private val zone = ZoneId.systemDefault()
    private val sharing = SharingStarted.WhileSubscribed(5_000)

    /** Every geotagged transaction, newest first. */
    val mapped: StateFlow<List<TransactionEntity>> = transactions.observeMapped()
        .stateIn(viewModelScope, sharing, emptyList())

    /** Today's spending grouped by spot: these get callouts, as in the Flutter app. */
    val todayPlaces: StateFlow<List<Place<TransactionEntity>>> = mapped.map { all ->
        val start = today(LocalDateTime.now(zone)).startMillis(zone)
        groupByLocation(all.filter { it.timestamp >= start }, { it.latitude }, { it.longitude })
    }.stateIn(viewModelScope, sharing, emptyList())

    val categories: StateFlow<Map<String, CategoryEntity>> = categoryRepository.observeAll()
        .map { list -> list.associateBy { it.name } }
        .stateIn(viewModelScope, sharing, emptyMap())

    val categoryList: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, sharing, emptyList())

    val style: StateFlow<String> = settings.mapStyle.map { MapStyles.normalize(it) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, MapStyles.STANDARD)

    fun setStyle(url: String) = viewModelScope.launch { settings.setMapStyle(url) }

    // Spending around a point

    private val _area = MutableStateFlow<AreaSelection?>(null)
    val area = _area.asStateFlow()

    val areaSummary: StateFlow<AreaSummary?> = _area.flatMapLatest { a ->
        if (a == null) flowOf(null)
        else transactions.observeAreaSpending(a.latitude, a.longitude, a.radiusMeters, since(a.period))
    }.stateIn(viewModelScope, sharing, null)

    private fun since(period: AreaPeriod): Long {
        val now = LocalDateTime.now(zone)
        return when (period) {
            AreaPeriod.WEEK -> thisWeek(now).startMillis(zone)
            AreaPeriod.MONTH -> thisMonth(now).startMillis(zone)
            AreaPeriod.ALL -> 0L
        }
    }

    fun inspectArea(lat: Double, lng: Double) = _area.update {
        it?.copy(latitude = lat, longitude = lng) ?: AreaSelection(lat, lng)
    }
    fun setAreaRadius(meters: Double) = _area.update { it?.copy(radiusMeters = meters) }
    fun setAreaPeriod(period: AreaPeriod) = _area.update { it?.copy(period = period) }
    fun closeArea() { _area.value = null }

    // Header pill: today / this week / this month

    val periodTotals: StateFlow<PeriodTotals> = run {
        val now = LocalDateTime.now(zone)
        val week = thisWeek(now)
        val month = thisMonth(now)
        val start = minOf(week.start, month.start)
        val end = maxOf(week.end, month.end)
        transactions.observeBetween(start.toEpochMillis(zone), end.toEpochMillis(zone)).map { txs ->
            val spending = txs.filter { it.type.isSpending && it.currency == "KES" }
            fun sumFrom(from: LocalDateTime) = spending.filter { it.timestamp >= from.toEpochMillis(zone) }.sumOf { it.amount }
            PeriodTotals(today = sumFrom(today(now).start), week = sumFrom(week.start), month = sumFrom(month.start))
        }
    }.stateIn(viewModelScope, sharing, PeriodTotals())

    // "Just mapped" banner: transactions that gain a location while the app is open.

    private val _justMapped = MutableSharedFlow<TransactionEntity>(extraBufferCapacity = 4)
    val justMapped = _justMapped.asSharedFlow()

    init {
        viewModelScope.launch {
            var seen: Set<String>? = null
            transactions.observeMapped().collect { list ->
                val ids = list.map { it.id }.toSet()
                val previous = seen
                if (previous != null) {
                    val tenMinutesAgo = System.currentTimeMillis() - 10 * 60_000
                    list.filter { it.id !in previous && it.timestamp >= tenMinutesAgo }.forEach { _justMapped.tryEmit(it) }
                }
                seen = ids
            }
        }
    }

    // Search, popups and actions

    private val _query = MutableStateFlow("")
    val query = _query.asStateFlow()
    fun setQuery(q: String) { _query.value = q }

    val searchResults: StateFlow<List<TransactionEntity>> = combine(mapped, _query) { all, q ->
        val needle = q.trim()
        if (needle.isEmpty()) emptyList()
        else all.filter { it.merchant.contains(needle, true) || it.rawMessage.contains(needle, true) }.take(20)
    }.stateIn(viewModelScope, sharing, emptyList())

    fun transactionsInCategory(category: String): Flow<List<TransactionEntity>> = transactions.observeByCategory(category)

    fun categorize(id: String, category: String) = viewModelScope.launch {
        transactions.setCategory(listOf(id), category)
        budgetChecker.check(category)
    }

    fun createCategory(name: String, iconKey: Int, colorArgb: Long, assignTo: String) = viewModelScope.launch {
        categoryRepository.add(name, iconKey, colorArgb)
        categorize(assignTo, name)
    }

    /** Device location, else the latest mapped transaction, else Nairobi. */
    suspend fun startPoint(): Pair<Double, Double> =
        location.currentLocation()?.let { it.latitude to it.longitude }
            ?: transactions.observeMapped().first().firstOrNull()?.let { it.latitude!! to it.longitude!! }
            ?: (DEFAULT_LAT to DEFAULT_LNG)

    suspend fun myLocation(): Pair<Double, Double>? = location.currentLocation()?.let { it.latitude to it.longitude }

    fun localTime(tx: TransactionEntity): LocalDateTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(tx.timestamp), zone)
}
