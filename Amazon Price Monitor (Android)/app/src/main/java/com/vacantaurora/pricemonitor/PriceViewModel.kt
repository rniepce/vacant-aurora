package com.vacantaurora.pricemonitor

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.vacantaurora.pricemonitor.data.AmazonAuth
import com.vacantaurora.pricemonitor.data.CartParser
import com.vacantaurora.pricemonitor.data.CartParserException
import com.vacantaurora.pricemonitor.data.PriceStore
import com.vacantaurora.pricemonitor.model.CartItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant

enum class SortOption(val labelRes: Int) {
    BIGGEST_DROP(R.string.sort_biggest_drop),
    LOWEST_PRICE(R.string.sort_lowest_price),
}

data class DashboardState(
    val items: List<CartItem> = emptyList(),
    val isLoading: Boolean = false,
    val lastUpdated: Instant? = null,
    val errorMessage: String? = null,
    val isLoggedIn: Boolean = false,
    val sort: SortOption = SortOption.BIGGEST_DROP,
)

class PriceViewModel(app: Application) : AndroidViewModel(app) {

    private val store = PriceStore(app)

    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state.asStateFlow()

    init {
        _state.value = _state.value.copy(
            items = store.loadItems(),
            lastUpdated = store.lastUpdated(),
            isLoggedIn = AmazonAuth.isLoggedIn(),
        )
    }

    val sortedItems: List<CartItem>
        get() = when (_state.value.sort) {
            SortOption.BIGGEST_DROP -> _state.value.items.sortedBy { it.priceChangePercent ?: 0.0 }
            SortOption.LOWEST_PRICE -> _state.value.items.sortedBy { it.currentPrice ?: Double.MAX_VALUE }
        }

    fun setSort(option: SortOption) {
        _state.value = _state.value.copy(sort = option)
    }

    fun refreshLoginState() {
        _state.value = _state.value.copy(isLoggedIn = AmazonAuth.isLoggedIn())
    }

    fun enableDemoData() {
        _state.value = _state.value.copy(items = store.populateWithDemoData(), lastUpdated = Instant.now())
    }

    fun refreshCart() {
        if (_state.value.isLoading) return
        _state.value = _state.value.copy(isLoading = true, errorMessage = null)
        viewModelScope.launch {
            val ctx = getApplication<Application>()
            try {
                val scraped = CartParser.fetchCart(ctx)
                val updated = store.processNewItems(scraped)
                _state.value = _state.value.copy(
                    items = updated,
                    lastUpdated = store.lastUpdated(),
                    isLoading = false,
                    errorMessage = null,
                    isLoggedIn = true,
                )
            } catch (e: CartParserException) {
                _state.value = _state.value.copy(
                    isLoading = false,
                    errorMessage = ctx.messageFor(e),
                    isLoggedIn = if (e is CartParserException.LoginRequired) false else _state.value.isLoggedIn,
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(isLoading = false, errorMessage = e.message)
            }
        }
    }
}

private fun Application.messageFor(e: CartParserException): String = when (e) {
    is CartParserException.LoginRequired -> getString(R.string.err_login_required)
    is CartParserException.NoItems -> getString(R.string.err_no_items)
    is CartParserException.Timeout -> getString(R.string.err_timeout)
    is CartParserException.ParseError -> getString(R.string.err_parse, e.reason)
}
