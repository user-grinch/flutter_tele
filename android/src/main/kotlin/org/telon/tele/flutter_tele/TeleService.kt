package org.telon.tele.flutter_tele

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.telecom.Call
import android.telecom.InCallService
import android.telecom.TelecomManager
import android.telecom.PhoneAccountHandle
import android.telephony.TelephonyManager
import android.telephony.SubscriptionManager
import android.util.Log
import android.content.Context
import android.media.AudioManager
import android.os.PowerManager
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import java.util.*

class TeleService : InCallService() {
    companion object {
        private const val TAG = "TeleService"
        private var instance: TeleService? = null
        
        fun getInstance(): TeleService? {
            return instance
        }
    }

    private var mInitialized = false
    private var mHandler: Handler? = null
    private var mAudioManager: AudioManager? = null
    private var mPowerManager: PowerManager? = null
    private var mTelephonyManager: TelephonyManager? = null
    private val mCalls = mutableListOf<TeleCall>()
    private var currentCall: Call? = null
    private var teleCallIds = 0
    private val callMapping = mutableMapOf<Int, Call>()

    override fun onCreate() {
        super.onCreate()
        instance = this
        mHandler = Handler(Looper.getMainLooper())
        mAudioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        mPowerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        mTelephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let { handleIntent(it) }
        return START_STICKY
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            "START_TELEPHONY_SERVICE" -> {
                val configuration = intent.getStringExtra("configuration")
                Log.d(TAG, "Starting telephony service with config: $configuration")
                initializeService()
            }
            "MAKE_CALL" -> {
                val sim = intent.getIntExtra("sim", 1)
                val destination = intent.getStringExtra("destination") ?: ""
                val callSettings = intent.getStringExtra("callSettings")
                val msgData = intent.getStringExtra("msgData")
                makeCall(sim, destination, callSettings, msgData)
            }
            "ANSWER_CALL" -> answerCall(intent.getIntExtra("callId", -1))
            "HANGUP_CALL" -> hangupCall(intent.getIntExtra("callId", -1))
            "DECLINE_CALL" -> declineCall(intent.getIntExtra("callId", -1))
            "HOLD_CALL" -> holdCall(intent.getIntExtra("callId", -1))
            "UNHOLD_CALL" -> unholdCall(intent.getIntExtra("callId", -1))
            "MUTE_CALL" -> muteCall(intent.getIntExtra("callId", -1))
            "UNMUTE_CALL" -> unMuteCall(intent.getIntExtra("callId", -1))
            "USE_SPEAKER" -> useSpeaker(intent.getIntExtra("callId", -1))
            "USE_EARPIECE" -> useEarpiece(intent.getIntExtra("callId", -1))
        }
    }

    private fun initializeService() {
        if (!mInitialized) {
            mInitialized = true
            Log.d(TAG, "Telephony service initialized")
            FlutterTelePlugin.getInstance()?.sendEvent("service_started", mapOf(
                "status" to "initialized"
            ))
        }
    }

    private fun makeCall(sim: Int, destination: String, callSettings: String?, msgData: String?) {
        try {
            Log.d(TAG, "Making call to $destination on SIM slot $sim (0-indexed)")
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            
            val uri = Uri.parse("tel:$destination")
            val extras = Bundle()
            
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
                val phoneAccounts = telecomManager.callCapablePhoneAccounts
                val activeSubscriptions = subscriptionManager.activeSubscriptionInfoList
                
                var selectedAccount: PhoneAccountHandle? = null
                
                if (activeSubscriptions != null) {
                    // Find the subscription for the requested slot
                    val targetSub = activeSubscriptions.find { it.simSlotIndex == sim }
                    if (targetSub != null) {
                        val subId = targetSub.subscriptionId.toString()
                        Log.d(TAG, "Target subscription ID: $subId for slot $sim")
                        
                        // Try to find the PhoneAccountHandle that corresponds to this subId
                        for (handle in phoneAccounts) {
                            val account = telecomManager.getPhoneAccount(handle)
                            // On many devices, the handle ID is the subId.
                            // On others, we might need to check more deeply or use the account label.
                            if (handle.id.contains(subId)) {
                                selectedAccount = handle
                                break
                            }
                        }
                    }
                }
                
                // Fallback to indexing if mapping failed
                if (selectedAccount == null && phoneAccounts.isNotEmpty()) {
                    Log.d(TAG, "Mapping by subId failed, falling back to index $sim")
                    selectedAccount = phoneAccounts.getOrNull(sim) ?: phoneAccounts.first()
                }
                
                if (selectedAccount != null) {
                    Log.d(TAG, "Final Selected PhoneAccountHandle: $selectedAccount")
                    extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, selectedAccount)
                }
            }

            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                telecomManager.placeCall(uri, extras)
                Log.d(TAG, "Call placed via TelecomManager")
            } else {
                Log.e(TAG, "CALL_PHONE permission not granted")
                FlutterTelePlugin.getInstance()?.sendEvent("call_error", mapOf(
                    "error" to "CALL_PHONE permission not granted",
                    "destination" to destination,
                    "sim" to sim
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error making call", e)
            FlutterTelePlugin.getInstance()?.sendEvent("call_error", mapOf(
                "error" to e.message,
                "destination" to destination,
                "sim" to sim
            ))
        }
    }

    private fun answerCall(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                val androidCall = callMapping[callId] ?: currentCall
                if (androidCall != null) {
                    androidCall.answer(0)
                    Log.d(TAG, "Answered Android call for TeleCall ID: $callId")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error answering call", e)
        }
    }

    private fun hangupCall(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                val androidCall = callMapping[callId] ?: currentCall
                if (androidCall != null) {
                    androidCall.disconnect()
                    Log.d(TAG, "Disconnected Android call for TeleCall ID: $callId")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error hanging up call", e)
        }
    }

    private fun declineCall(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                val androidCall = callMapping[callId] ?: currentCall
                if (androidCall != null) {
                    androidCall.reject(false, null)
                    Log.d(TAG, "Rejected Android call for TeleCall ID: $callId")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error declining call", e)
        }
    }

    private fun holdCall(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                val androidCall = callMapping[callId] ?: currentCall
                if (androidCall != null) {
                    androidCall.hold()
                    teleCall.held = true
                    FlutterTelePlugin.getInstance()?.sendEvent("call_changed", teleCall.toMap() as Map<String, Any>)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error holding call", e)
        }
    }

    private fun unholdCall(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                val androidCall = callMapping[callId] ?: currentCall
                if (androidCall != null) {
                    androidCall.unhold()
                    teleCall.held = false
                    FlutterTelePlugin.getInstance()?.sendEvent("call_changed", teleCall.toMap() as Map<String, Any>)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error unholding call", e)
        }
    }

    private fun muteCall(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                mAudioManager?.isMicrophoneMute = true
                teleCall.muted = true
                FlutterTelePlugin.getInstance()?.sendEvent("call_changed", teleCall.toMap() as Map<String, Any>)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error muting call", e)
        }
    }

    private fun unMuteCall(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                mAudioManager?.isMicrophoneMute = false
                teleCall.muted = false
                FlutterTelePlugin.getInstance()?.sendEvent("call_changed", teleCall.toMap() as Map<String, Any>)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error unmuting call", e)
        }
    }

    private fun useSpeaker(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                setAudioRoute(android.telecom.CallAudioState.ROUTE_SPEAKER)
                
                teleCall.speaker = true
                FlutterTelePlugin.getInstance()?.sendEvent("call_changed", teleCall.toMap())
                Log.d(TAG, "Audio route changed to SPEAKER for call: $callId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error switching to speaker", e)
        }
    }

    private fun useEarpiece(callId: Int) {
        try {
            val teleCall = findCall(callId)
            if (teleCall != null) {
                setAudioRoute(android.telecom.CallAudioState.ROUTE_WIRED_OR_EARPIECE)
                
                teleCall.speaker = false
                FlutterTelePlugin.getInstance()?.sendEvent("call_changed", teleCall.toMap())
                Log.d(TAG, "Audio route changed to EARPIECE for call: $callId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error switching to earpiece", e)
        }
    }

    private fun findCall(callId: Int): TeleCall? {
        return mCalls.find { it.id == callId }
    }

    private fun findCallByCall(call: Call): TeleCall? {
        return mCalls.lastOrNull()
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "Call added by Telecom framework")
        
        currentCall = call
        val callDetails = call.details
        val handle = callDetails.handle
        val remoteNumber = handle?.schemeSpecificPart ?: ""
        val remoteName = callDetails.callerDisplayName ?: remoteNumber
        
        teleCallIds++
        
        val isIncoming = call.state == Call.STATE_RINGING || call.details.state == Call.STATE_RINGING
        val direction = if (isIncoming) "DIRECTION_INCOMING" else "DIRECTION_OUTGOING"
        
        val stateStr = when (call.state) {
            Call.STATE_RINGING -> "RINGING"
            Call.STATE_DIALING -> "DIALING"
            Call.STATE_CONNECTING -> "CONNECTING"
            Call.STATE_ACTIVE -> "ACTIVE"
            else -> "INITIATING"
        }
        
        // Try to determine which SIM this call is on
        var simSlot = 0
        val accountHandle = call.details.accountHandle
        if (accountHandle != null && ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
            try {
                val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                val activeSubscriptions = subscriptionManager.activeSubscriptionInfoList
                if (activeSubscriptions != null) {
                    val sub = activeSubscriptions.find { accountHandle.id.contains(it.subscriptionId.toString()) }
                    if (sub != null) {
                        simSlot = sub.simSlotIndex
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error determining SIM slot: ${e.message}")
            }
        }

        val teleCall = TeleCall(
            id = teleCallIds,
            destination = remoteNumber,
            sim = simSlot, 
            state = stateStr,
            direction = direction,
            remoteNumber = remoteNumber,
            remoteName = remoteName
        )
        
        if (call.state == Call.STATE_ACTIVE) {
            teleCall.connectTimeMillis = if (call.details.connectTimeMillis > 0) call.details.connectTimeMillis else System.currentTimeMillis()
        }
        
        mCalls.add(teleCall)
        callMapping[teleCall.id] = call
        
        // This is what completes the Future on the Dart side!
        FlutterTelePlugin.getInstance()?.sendEvent("call_received", teleCall.toMap() as Map<String, Any>)
        
        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call, state: Int) {
                super.onStateChanged(call, state)
                
                teleCall.state = when (state) {
                    Call.STATE_RINGING -> "RINGING"
                    Call.STATE_DISCONNECTED -> {
                        "DISCONNECTED"
                    }
                    Call.STATE_ACTIVE -> {
                        if (teleCall.connectTimeMillis == null || teleCall.connectTimeMillis == 0L) {
                            teleCall.connectTimeMillis = if (call.details.connectTimeMillis > 0) call.details.connectTimeMillis else System.currentTimeMillis()
                        }
                        "ACTIVE"
                    }
                    Call.STATE_HOLDING -> "HOLDING"
                    Call.STATE_DIALING -> "DIALING"
                    Call.STATE_CONNECTING -> "CONNECTING"
                    else -> "UNKNOWN"
                }
                
                FlutterTelePlugin.getInstance()?.sendEvent("call_changed", teleCall.toMap() as Map<String, Any>)
            }

            override fun onCallDestroyed(call: Call) {
                super.onCallDestroyed(call)
                teleCall.state = "DISCONNECTED"
                FlutterTelePlugin.getInstance()?.sendEvent("call_terminated", teleCall.toMap() as Map<String, Any>)
                mCalls.remove(teleCall)
                callMapping.remove(teleCall.id)
            }
        })
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        
        val teleCallId = callMapping.entries.find { it.value == call }?.key
        val teleCall = if (teleCallId != null) findCall(teleCallId) else findCallByCall(call)
        
        if (teleCall != null) {
            teleCall.state = "DISCONNECTED"
            FlutterTelePlugin.getInstance()?.sendEvent("call_terminated", teleCall.toMap() as Map<String, Any>)
            mCalls.remove(teleCall)
            callMapping.remove(teleCall.id)
        }
        
        if (currentCall == call) {
            currentCall = null
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return super.onBind(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }
}

data class TeleCall(
    val id: Int,
    val destination: String? = null,
    val sim: Int? = null,
    var state: String? = null,
    var held: Boolean? = null,
    var muted: Boolean? = null,
    var speaker: Boolean? = null,
    val direction: String? = null,
    var remoteNumber: String? = null,
    var remoteName: String? = null,
    var connectTimeMillis: Long? = null
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "id" to id,
            "destination" to (destination ?: ""),
            "sim" to (sim ?: 0),
            "state" to (state ?: "UNKNOWN"),
            "held" to (held ?: false),
            "muted" to (muted ?: false),
            "speaker" to (speaker ?: false),
            "direction" to (direction ?: "UNKNOWN"),
            "remoteNumber" to (remoteNumber ?: ""),
            "remoteName" to (remoteName ?: ""),
            "connectTimeMillis" to (connectTimeMillis ?: 0L)
        )
    }
}