package com.example.quran_assistant

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import vn.hunghd.flutterdownloader.DownloadWorker

class MainActivity : AudioServiceActivity() {
	private val channelName = "quran_assistant/download_notification"
	private var notificationChannel: MethodChannel? = null
	private var pendingNotificationData: Map<String, Any?>? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
		flushPendingNotification()
		deliverNotificationIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		deliverNotificationIntent(intent)
	}

	override fun onDestroy() {
		notificationChannel = null
		pendingNotificationData = null
		super.onDestroy()
	}

	private fun deliverNotificationIntent(intent: Intent?) {
		if (intent == null) return
		val status = intent.getIntExtra(DownloadWorker.EXTRA_NOTIFICATION_STATUS, -1)
		if (status == -1) return
		val taskId = intent.getStringExtra(DownloadWorker.EXTRA_NOTIFICATION_TASK_ID)
		val payload = HashMap<String, Any?>()
		payload["status"] = status
		if (taskId != null) {
			payload["taskId"] = taskId
		}
		// Clear extras to avoid re-processing when activity resumes
		intent.removeExtra(DownloadWorker.EXTRA_NOTIFICATION_STATUS)
		intent.removeExtra(DownloadWorker.EXTRA_NOTIFICATION_TASK_ID)
		sendNotificationPayload(payload)
	}

	private fun sendNotificationPayload(payload: Map<String, Any?>) {
		val channel = notificationChannel
		if (channel == null) {
			pendingNotificationData = payload
		} else {
			channel.invokeMethod("downloadNotificationTap", payload)
		}
	}

	private fun flushPendingNotification() {
		val payload = pendingNotificationData ?: return
		notificationChannel?.invokeMethod("downloadNotificationTap", payload)
		pendingNotificationData = null
	}
}
