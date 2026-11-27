package app.geocent.ui.messages

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.geocent.data.MessageAge
import app.geocent.data.MessageFilter
import app.geocent.data.TransactionRepository
import app.geocent.data.db.TransactionEntity
import app.geocent.notify.Notifier
import app.geocent.ui.components.SurfaceCard
import app.geocent.ui.theme.GeocentTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import javax.inject.Inject

@HiltViewModel
class MessagesPreviewViewModel @Inject constructor(repository: TransactionRepository) : ViewModel() {
    val transactions = repository
        .observeMessages(MessageFilter.ALL, search = null, age = MessageAge.ANY, limit = 200)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
}

private val timeFormat = DateTimeFormatter.ofPattern("d MMM, HH:mm")

/**
 * Temporary Messages tab: a plain list of stored transactions so SMS ingestion
 * can be checked on a device. Replaced by the full Messages screen in phase 3.
 */
@Composable
fun MessagesPreviewScreen(viewModel: MessagesPreviewViewModel = hiltViewModel()) {
    val transactions by viewModel.transactions.collectAsStateWithLifecycle()
    Column(
        Modifier
            .fillMaxSize()
            .background(GeocentTheme.colors.background)
            .windowInsetsPadding(WindowInsets.statusBars),
    ) {
        Text(
            "Messages",
            style = GeocentTheme.typography.largeTitle,
            color = GeocentTheme.colors.textPrimary,
            modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 12.dp),
        )
        if (transactions.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    "No transactions yet.\nThey appear here as M-PESA or bank SMS arrive.",
                    style = GeocentTheme.typography.body,
                    color = GeocentTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(transactions, key = { it.id }) { TransactionRow(it) }
            }
        }
    }
}

@Composable
private fun TransactionRow(tx: TransactionEntity) {
    val colors = GeocentTheme.colors
    SurfaceCard(Modifier.fillMaxWidth(), contentPadding = PaddingValues(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(tx.merchant, style = GeocentTheme.typography.headline, color = colors.textPrimary)
                val time = Instant.ofEpochMilli(tx.timestamp).atZone(ZoneId.systemDefault()).format(timeFormat)
                val status = listOfNotNull(
                    tx.category ?: "No category",
                    if (tx.hasLocation) "Mapped" else "No location",
                ).joinToString(" · ")
                Text("$time · $status", style = GeocentTheme.typography.caption, color = colors.textSecondary)
            }
            val amount = if (tx.currency == "KES") Notifier.formatKes(tx.amount) else "${tx.currency} ${tx.amount}"
            Text(amount, style = GeocentTheme.typography.amount, color = colors.textPrimary)
        }
    }
}
