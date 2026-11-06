package com.arrowescape.arrowescapegame

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallException
import com.google.android.play.core.install.model.ActivityResult
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play In-App Updates, IMMEDIATE flow only
 * (com.google.android.play:app-update). Play shows its own full-screen update
 * UI and progress, installs the update and restarts the app; this app shows
 * no update UI of its own.
 *
 * Method (MethodChannel [METHOD_CHANNEL]):
 *  - startImmediateUpdate(args: {allowNewUpdate: Boolean})
 *      Fetches a fresh AppUpdateInfo (one instance is never used for two
 *      flows), then:
 *        - DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS → resumes that immediate flow
 *        - UPDATE_AVAILABLE + IMMEDIATE allowed + allowNewUpdate → starts it
 *        - anything else → starts nothing
 *      Returns {outcome, resumed, availableVersionCode} where outcome is one of
 *      "noUpdate" | "notAllowed" | "busy" | "notStarted" |
 *      "accepted" | "canceled" | "failed".
 *      Fails with error code "CHECK_FAILED" (details: Play InstallErrorCode)
 *      when Play cannot be asked.
 */
class InAppUpdateHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val manager: AppUpdateManager = AppUpdateManagerFactory.create(activity)

    /** The Dart call waiting for Play's update screen to close. */
    private var pendingFlow: MethodChannel.Result? = null
    private var pendingResumed = false
    private var pendingVersionCode = 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startImmediateUpdate" ->
                startImmediateUpdate(call.argument<Boolean>("allowNewUpdate") ?: true, result)
            else -> result.notImplemented()
        }
    }

    private fun startImmediateUpdate(allowNewUpdate: Boolean, result: MethodChannel.Result) {
        // Only one update screen at a time.
        if (pendingFlow != null) {
            result.success(outcome("busy"))
            return
        }
        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                if (pendingFlow != null) {
                    result.success(outcome("busy"))
                    return@addOnSuccessListener
                }
                val versionCode = info.availableVersionCode()
                val availability = info.updateAvailability()
                val resuming =
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                val available = availability == UpdateAvailability.UPDATE_AVAILABLE
                when {
                    resuming -> Unit
                    !available -> {
                        result.success(outcome("noUpdate", versionCode = versionCode))
                        return@addOnSuccessListener
                    }
                    !allowNewUpdate || !info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE) -> {
                        result.success(outcome("notAllowed", versionCode = versionCode))
                        return@addOnSuccessListener
                    }
                }
                pendingFlow = result
                pendingResumed = resuming
                pendingVersionCode = versionCode
                val started = try {
                    manager.startUpdateFlowForResult(
                        info,
                        activity,
                        AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE),
                        REQUEST_CODE,
                    )
                } catch (e: Exception) {
                    false
                }
                if (!started && pendingFlow === result) {
                    pendingFlow = null
                    result.success(outcome("notStarted", resuming, versionCode))
                }
            }
            .addOnFailureListener { e ->
                result.error("CHECK_FAILED", e.message, (e as? InstallException)?.errorCode)
            }
    }

    /** Returns true when [requestCode] belonged to the update flow. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val name = when (resultCode) {
            // For IMMEDIATE, Play usually restarts the app before this arrives.
            Activity.RESULT_OK -> "accepted"
            Activity.RESULT_CANCELED -> "canceled"
            ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> "failed"
            else -> "failed"
        }
        finishPending(name)
        return true
    }

    fun dispose() {
        finishPending("canceled")
    }

    private fun finishPending(name: String) {
        val flow = pendingFlow ?: return
        pendingFlow = null
        flow.success(outcome(name, pendingResumed, pendingVersionCode))
    }

    private fun outcome(name: String, resumed: Boolean = false, versionCode: Int = 0) =
        mapOf(
            "outcome" to name,
            "resumed" to resumed,
            "availableVersionCode" to versionCode,
        )

    companion object {
        const val METHOD_CHANNEL = "com.arrowescape.arrowescapegame/update"
        private const val REQUEST_CODE = 0x5EED
    }
}
