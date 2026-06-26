package com.vacantaurora.pricemonitor

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.vacantaurora.pricemonitor.ui.DashboardScreen
import com.vacantaurora.pricemonitor.ui.ItemDetailScreen
import com.vacantaurora.pricemonitor.ui.LoginScreen
import com.vacantaurora.pricemonitor.ui.theme.PriceMonitorTheme

class MainActivity : ComponentActivity() {

    private val viewModel: PriceViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ask for notification permission (Android 13+), mirroring the iOS request on launch.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerForActivityResult(ActivityResultContracts.RequestPermission()) {}
                .launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            PriceMonitorTheme {
                val nav = rememberNavController()
                val state by viewModel.state.collectAsStateWithLifecycle()

                NavHost(navController = nav, startDestination = "dashboard") {
                    composable("dashboard") {
                        DashboardScreen(
                            state = state,
                            sortedItems = viewModel.sortedItems,
                            onRefresh = viewModel::refreshCart,
                            onSortChange = viewModel::setSort,
                            onOpenLogin = { nav.navigate("login") },
                            onOpenItem = { nav.navigate("detail/$it") },
                        )
                    }
                    composable("login") {
                        LoginScreen(
                            onDone = {
                                viewModel.refreshLoginState()
                                nav.popBackStack()
                            },
                        )
                    }
                    composable("detail/{asin}") { entry ->
                        val asin = entry.arguments?.getString("asin")
                        val item = state.items.firstOrNull { it.id == asin }
                        ItemDetailScreen(item = item, onBack = { nav.popBackStack() })
                    }
                }
            }
        }
    }
}
