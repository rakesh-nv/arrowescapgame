package com.arrowescape.arrowescapegame

import android.app.Application
import com.google.android.gms.games.PlayGamesSdk

/**
 * Starts Google Play Games Services v2 in Application.onCreate, as Google's
 * setup guide asks; the SDK then signs returning players in automatically.
 *
 * It starts only when res/values/play_games.xml holds the numeric Play Games
 * project ID. Without one the SDK cannot work, so the game simply runs
 * without Play Games (the welcome banner stays hidden).
 */
class ArrowEscapeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        playGamesReady = initPlayGames()
    }

    private fun initPlayGames(): Boolean {
        val projectId = getString(R.string.game_services_project_id).trim()
        if (projectId.isEmpty() || !projectId.all { it.isDigit() }) return false
        return try {
            PlayGamesSdk.initialize(this)
            true
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        /** True once the Play Games SDK was initialised with a real project ID. */
        var playGamesReady = false
            private set
    }
}
