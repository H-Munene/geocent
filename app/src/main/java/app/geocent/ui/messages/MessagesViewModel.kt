package app.geocent.ui.messages

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.geocent.data.CategoryRepository
import app.geocent.data.MessageAge
import app.geocent.data.MessageFilter
import app.geocent.data.TransactionRepository
import app.geocent.data.db.CategoryEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.notify.BudgetChecker
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val PAGE_SIZE = 50

@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
@HiltViewModel
class MessagesViewModel @Inject constructor(
    private val transactions: TransactionRepository,
    private val categoryRepository: CategoryRepository,
    private val budgetChecker: BudgetChecker,
) : ViewModel() {

    private val _filter = MutableStateFlow(MessageFilter.NEEDS_ACTION)
    val filter = _filter.asStateFlow()

    private val _age = MutableStateFlow(MessageAge.ANY)
    val age = _age.asStateFlow()

    private val _search = MutableStateFlow("")
    val search = _search.asStateFlow()

    private val limit = MutableStateFlow(PAGE_SIZE)

    private val _selection = MutableStateFlow<Set<String>>(emptySet())
    val selection = _selection.asStateFlow()

    private val _toasts = MutableSharedFlow<String>(extraBufferCapacity = 4)
    /** One-off confirmations ("3 messages categorised"). */
    val toasts = _toasts.asSharedFlow()

    /** null until the first query returns, so the empty state doesn't flash. */
    val messages: StateFlow<List<TransactionEntity>?> = combine(
        _filter,
        _age,
        _search.debounce { if (it.isEmpty()) 0 else 300 }.distinctUntilChanged(),
        limit,
    ) { filter, age, search, limit -> Query(filter, age, search, limit) }
        .flatMapLatest { q -> transactions.observeMessages(q.filter, q.search, q.age, q.limit) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private data class Query(val filter: MessageFilter, val age: MessageAge, val search: String, val limit: Int)

    fun setFilter(value: MessageFilter) {
        _filter.value = value
        limit.value = PAGE_SIZE
        clearSelection()
    }

    fun setAge(value: MessageAge) {
        _age.value = value
        limit.value = PAGE_SIZE
    }

    fun setSearch(value: String) {
        _search.value = value
        limit.value = PAGE_SIZE
    }

    /** Called when the list nears its end; only grows if the last page was full. */
    fun loadMore(loaded: Int) {
        if (loaded >= limit.value) limit.update { it + PAGE_SIZE }
    }

    fun toggle(id: String) = _selection.update { if (id in it) it - id else it + id }
    fun select(ids: Collection<String>) = _selection.update { it + ids }
    fun deselect(ids: Collection<String>) = _selection.update { it - ids.toSet() }
    fun clearSelection() { _selection.value = emptySet() }

    fun categorize(ids: List<String>, category: String) = viewModelScope.launch {
        transactions.setCategory(ids, category)
        budgetChecker.check(category)
        clearSelection()
        _toasts.tryEmit(if (ids.size == 1) "Categorised as $category" else "${ids.size} messages categorised as $category")
    }

    fun createCategory(name: String, iconKey: Int, colorArgb: Long, assignTo: List<String>) = viewModelScope.launch {
        categoryRepository.add(name, iconKey, colorArgb)
        if (assignTo.isNotEmpty()) categorize(assignTo, name)
    }

    fun forget(ids: List<String>) = viewModelScope.launch {
        transactions.forget(ids)
        clearSelection()
        _toasts.tryEmit(if (ids.size == 1) "Message forgotten" else "${ids.size} messages forgotten")
    }
}
