package app.geocent.ui.budgets

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.geocent.data.BudgetProgress
import app.geocent.data.BudgetRepository
import app.geocent.data.BudgetTracker
import app.geocent.data.CategoryRepository
import app.geocent.data.db.CategoryEntity
import app.geocent.domain.model.BudgetPeriod
import app.geocent.notify.BudgetChecker
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class BudgetsViewModel @Inject constructor(
    tracker: BudgetTracker,
    categoryRepository: CategoryRepository,
    private val budgets: BudgetRepository,
    private val budgetChecker: BudgetChecker,
) : ViewModel() {

    private val sharing = SharingStarted.WhileSubscribed(5_000)

    /** null until loaded, so the empty state doesn't flash. */
    val progress: StateFlow<List<BudgetProgress>?> = tracker.observeProgress().stateIn(viewModelScope, sharing, null)

    val categories: StateFlow<List<CategoryEntity>> = categoryRepository.observeAll().stateIn(viewModelScope, sharing, emptyList())

    private val _period = MutableStateFlow(BudgetPeriod.WEEKLY)
    val period = _period.asStateFlow()
    fun setPeriod(value: BudgetPeriod) { _period.value = value }

    /** Creates or updates the category's budget, then alerts if it's already past a threshold. */
    fun save(category: String, limit: Double, period: BudgetPeriod) = viewModelScope.launch {
        budgets.save(category, limit, period)
        _period.value = period
        budgetChecker.check(category)
    }

    fun delete(id: String) = viewModelScope.launch { budgets.delete(id) }
}
