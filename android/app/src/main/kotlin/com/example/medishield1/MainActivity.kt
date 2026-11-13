package in.medishield.app

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "medishield/reminders"
    private val notificationPermissionRequest = 7401
    private var permissionResult: MethodChannel.Result? = null
    private var refreshAlarmsOnResume = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermissions" -> requestReminderPermissions(result)
                    "sync" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val rawItems = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                        val items = rawItems.mapNotNull { item ->
                            val id = (item["id"] as? Number)?.toInt() ?: return@mapNotNull null
                            val hour = (item["hour"] as? Number)?.toInt() ?: return@mapNotNull null
                            val minute = (item["minute"] as? Number)?.toInt() ?: return@mapNotNull null
                            MedicineAlarmItem(
                                id = id,
                                name = item["name"]?.toString().orEmpty(),
                                strength = item["strength"]?.toString().orEmpty(),
                                hour = hour,
                                minute = minute,
                            )
                        }
                        MedicineReminderAlarms.sync(applicationContext, enabled, items)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestReminderPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            permissionResult = result
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequest)
            return
        }

        openExactAlarmAccessIfNeeded()
        result.success(true)
    }

    private fun openExactAlarmAccessIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val alarmManager = getSystemService(AlarmManager::class.java)
        if (alarmManager.canScheduleExactAlarms()) return

        refreshAlarmsOnResume = true
        startActivity(
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            },
        )
    }

    @Deprecated("Permission callback is required for Android 13 notification access")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequest) return

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        val pending = permissionResult
        permissionResult = null
        if (granted) openExactAlarmAccessIfNeeded()
        pending?.success(granted)
    }

    override fun onResume() {
        super.onResume()
        if (refreshAlarmsOnResume) {
            refreshAlarmsOnResume = false
            MedicineReminderAlarms.reschedule(applicationContext)
        }
    }
}
