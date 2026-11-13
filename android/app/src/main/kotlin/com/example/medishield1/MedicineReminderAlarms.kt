package in.medishield.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

internal data class MedicineAlarmItem(
    val id: Int,
    val name: String,
    val strength: String,
    val hour: Int,
    val minute: Int,
)

internal object MedicineReminderAlarms {
    private const val preferencesName = "medishield_medicine_alarms"
    private const val itemsKey = "scheduled_items"
    private const val channelId = "medicine_time_buzzer_v1"
    private const val alarmActionSuffix = ".MEDICINE_REMINDER"
    private val vibrationPattern = longArrayOf(0, 650, 250, 650, 700, 650)

    fun sync(context: Context, enabled: Boolean, items: List<MedicineAlarmItem>) {
        cancelSavedAlarms(context)
        if (!enabled) {
            preferences(context).edit().remove(itemsKey).apply()
            return
        }

        val uniqueItems = items.distinctBy { it.id }
        preferences(context).edit().putString(itemsKey, encode(uniqueItems)).apply()
        createNotificationChannel(context)
        uniqueItems.forEach { schedule(context, it) }
    }

    fun reschedule(context: Context) {
        val items = readSavedItems(context)
        cancelSavedAlarms(context)
        if (items.isEmpty()) return
        createNotificationChannel(context)
        items.forEach { schedule(context, it) }
    }

    @Suppress("DEPRECATION")
    fun fire(context: Context, item: MedicineAlarmItem) {
        createNotificationChannel(context)
        try {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val contentIntent = PendingIntent.getActivity(
                context,
                item.id,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channelId)
            } else {
                Notification.Builder(context)
            }
            builder
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Time to take your medicine")
                .setContentText(listOf(item.name, item.strength).filter { it.isNotBlank() }.joinToString(" · "))
                .setCategory(Notification.CATEGORY_ALARM)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setPriority(Notification.PRIORITY_MAX)
                .setAutoCancel(true)
                .setOnlyAlertOnce(false)
                .setContentIntent(contentIntent)

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                builder
                    .setSound(soundUri(context))
                    .setVibrate(vibrationPattern)
            }
            context.getSystemService(NotificationManager::class.java)
                .notify(item.id, builder.build())
        } catch (_: SecurityException) {
            // Android 13+ can revoke notification permission after alarms were set.
        }

        schedule(context, item)
    }

    private fun schedule(context: Context, item: MedicineAlarmItem) {
        if (item.hour !in 0..23 || item.minute !in 0..59) return
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val pendingIntent = pendingIntent(context, item, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, item.hour)
            set(Calendar.MINUTE, item.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }

        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent,
                )
            }
        } catch (_: SecurityException) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent,
            )
        }
    }

    private fun cancelSavedAlarms(context: Context) {
        readSavedItems(context).forEach { item ->
            val pending = pendingIntent(context, item, PendingIntent.FLAG_NO_CREATE)
            if (pending != null) {
                context.getSystemService(AlarmManager::class.java).cancel(pending)
                pending.cancel()
            }
        }
    }

    private fun pendingIntent(context: Context, item: MedicineAlarmItem, flag: Int): PendingIntent? {
        val intent = Intent(context, MedicineReminderReceiver::class.java).apply {
            action = context.packageName + alarmActionSuffix
            putExtra("id", item.id)
            putExtra("name", item.name)
            putExtra("strength", item.strength)
            putExtra("hour", item.hour)
            putExtra("minute", item.minute)
        }
        val flags = flag or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.getBroadcast(context, item.id, intent, flags)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            channelId,
            "Medicine time reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Sounds and vibrates when it is time to take a saved medicine"
            enableVibration(true)
            vibrationPattern = this@MedicineReminderAlarms.vibrationPattern
            setSound(soundUri(context), audioAttributes)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun soundUri(context: Context): Uri =
        Uri.parse("android.resource://${context.packageName}/raw/medicine_buzzer")

    private fun preferences(context: Context) =
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)

    private fun readSavedItems(context: Context): List<MedicineAlarmItem> {
        val raw = preferences(context).getString(itemsKey, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                MedicineAlarmItem(
                    id = item.optInt("id", -1),
                    name = item.optString("name"),
                    strength = item.optString("strength"),
                    hour = item.optInt("hour", -1),
                    minute = item.optInt("minute", -1),
                ).takeIf { it.id >= 0 }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun encode(items: List<MedicineAlarmItem>): String {
        val array = JSONArray()
        items.forEach { item ->
            array.put(
                JSONObject()
                    .put("id", item.id)
                    .put("name", item.name)
                    .put("strength", item.strength)
                    .put("hour", item.hour)
                    .put("minute", item.minute),
            )
        }
        return array.toString()
    }
}

class MedicineReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val item = MedicineAlarmItem(
            id = intent.getIntExtra("id", -1),
            name = intent.getStringExtra("name").orEmpty(),
            strength = intent.getStringExtra("strength").orEmpty(),
            hour = intent.getIntExtra("hour", -1),
            minute = intent.getIntExtra("minute", -1),
        )
        if (item.id >= 0) MedicineReminderAlarms.fire(context, item)
    }
}

class MedicineReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == Intent.ACTION_TIME_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED ||
            intent.action == AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED
        ) {
            MedicineReminderAlarms.reschedule(context)
        }
    }
}
