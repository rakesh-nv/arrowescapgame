package com.arrowescape.arrowescapegame

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallException
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.ActivityResult
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Google Play In-App Updates (com.google.android.play:app-update) to
 * Dart. All decisions (when to check, which flow, when to prompt) live in
 * Dart's UpdateService; this class only forwards Play's answers.
 *
 * Methods (MethodChannel [METHOD_CHANNEL]):
 *  - packageName     → String, this install's application id
 *  - checkForUpdate  → Map describing AppUpdateInfo
 *  - startUpdate     → "accepted" | "canceled" | "failed" from the Play dialog
 *                      (args: {type: "flexible" | "immediate"})
 *  - completeUpdate  → installs a downloaded flexible update (restarts the app)
 *
 * Events (EventChannel [EVENT_CHANNEL]): InstallState maps for flexible
 * downloads (status, bytes downloaded, total bytes, error code).
 */
class InAppUpdateHandler(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val manager: AppUpdateManager = AppUpdateManagerFactory.create(activity)
    private var events: EventChannel.EventSink? = null
    private var pendingFlow: MethodChannel.Result? = null

    private val installListener = InstallStateUpdatedListener { state ->
        events?.success(
            mapOf(
                "installStatus" to state.installStatus(),
                "bytesDownloaded" to state.bytesDownloaded(),
                "totalBytesToDownload" to state.totalBytesToDownload(),
                "installErrorCode" to state.installErrorCode(),
            ),
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "packageName" -> result.success(activity.packageName)
            "checkForUpdate" -> checkForUpdate(result)
            "startUpdate" -> startUpdate(call.argument<String>("type"), result)
            "completeUpdate" -> completeUpdate(result)
            else -> result.notImplemented()
        }
    }

    private fun checkForUpdate(result: MethodChannel.Result) {
        manager.appUpdateInfo
            .addOnSuccessListener { info -> result.success(info.toMap()) }
            .addOnFailureListener { e ->
                result.error("CHECK_FAILED", e.message, errorCodeOf(e))
            }
    }

    private fun startUpdate(type: String?, result: MethodChannel.Result) {
        val updateType =
            if (type == "immediate") AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
        // Always start from fresh info: a stale AppUpdateInfo cannot start a flow.
        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                val availability = info.updateAvailability()
                // A flow the app already started is resumed as-is (Play's
                // documented recovery for an interrupted immediate update).
                val resuming =
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                val startable = resuming ||
                    (availability == UpdateAvailability.UPDATE_AVAILABLE &&
                        info.isUpdateTypeAllowed(updateType))
                if (!startable) {
                    result.error("UPDATE_NOT_ALLOWED", "No update of this type is available", null)
                    return@addOnSuccessListener
                }
                pendingFlow?.success("canceled")
                pendingFlow = result
                val started = try {
                    manager.startUpdateFlowForResult(
                        info,
                        activity,
                        AppUpdateOptions.newBuilder(updateType).build(),
                        REQUEST_CODE,
                    )
                } catch (e: Exception) {
                    false
                }
                if (!started && pendingFlow === result) {
                    pendingFlow = null
                    result.error("FLOW_NOT_STARTED", "Play could not show the update flow", null)
                }
            }
            .addOnFailureListener { e ->
                result.error("CHECK_FAILED", e.message, errorCodeOf(e))
            }
    }

    private fun completeUpdate(result: MethodChannel.Result) {
        manager.completeUpdate()
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { e ->
                result.error("COMPLETE_FAILED", e.message, errorCodeOf(e))
            }
    }

    /** Returns true when [requestCode] belonged to the update flow. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val outcome = when (resultCode) {
            Activity.RESULT_OK -> "accepted"
            Activity.RESULT_CANCELED -> "canceled"
            ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> "failed"
            else -> "failed"
        }
        pendingFlow?.success(outcome)
        pendingFlow = null
        return true
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
        manager.registerListener(installListener)
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(installListener)
        events = null
    }

    fun dispose() {
        manager.unregisterListener(installListener)
        events = null
        pendingFlow?.success("canceled")
        pendingFlow = null
    }

    private fun errorCodeOf(e: Exception): Int? = (e as? InstallException)?.errorCode

    private fun AppUpdateInfo.toMap(): Map<String, Any?> = mapOf(
        "updateAvailability" to updateAvailability(),
        "installStatus" to installStatus(),
        "availableVersionCode" to availableVersionCode(),
        "updatePriority" to updatePriority(),
        "clientVersionStalenessDays" to clientVersionStalenessDays(),
        "immediateAllowed" to isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
        "flexibleAllowed" to isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
        "bytesDownloaded" to bytesDownloaded(),
        "totalBytesToDownload" to totalBytesToDownload(),
        "packageName" to packageName(),
    )

    companion object {
        const val METHOD_CHANNEL = "com.arrowescape.arrowescapegame/update"
        const val EVENT_CHANNEL = "com.arrowescape.arrowescapegame/update_events"
        private const val REQUEST_CODE = 0x5EED
    }
}
