package org.telon.tele.flutter_tele

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import android.content.Context
import android.content.Intent
import android.util.Log
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/** FlutterTelePlugin */
class FlutterTelePlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var context: Context
  private var eventSink: EventChannel.EventSink? = null

  companion object {
    private const val TAG = "FlutterTelePlugin"
    private var instance: FlutterTelePlugin? = null
    
    fun getInstance(): FlutterTelePlugin? {
      return instance
    }
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    instance = this
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_tele")
    channel.setMethodCallHandler(this)
    
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_tele_events")
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
      }

      override fun onCancel(arguments: Any?) {
        eventSink = null
      }
    })
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "requestPermissions" -> requestPermissions(result)
      "hasPermissions" -> hasPermissions(result)
      "start" -> {
        val configuration = call.arguments as? Map<String, Any>
        startTelephonyService(configuration, result)
      }
      "makeCall" -> {
        val args = call.arguments as? Map<String, Any>
        if (args != null) {
          val sim = args["sim"] as? Int ?: 1
          val destination = args["destination"] as? String ?: ""
          val callSettings = args["callSettings"] as? Map<String, Any>
          val msgData = args["msgData"] as? Map<String, Any>
          makeCall(sim, destination, callSettings, msgData, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Invalid arguments for makeCall", null)
        }
      }
      "answerCall" -> handleCallAction(call, "ANSWER_CALL", result)
      "hangupCall" -> handleCallAction(call, "HANGUP_CALL", result)
      "declineCall" -> handleCallAction(call, "DECLINE_CALL", result)
      "holdCall" -> handleCallAction(call, "HOLD_CALL", result)
      "unholdCall" -> handleCallAction(call, "UNHOLD_CALL", result)
      "muteCall" -> handleCallAction(call, "MUTE_CALL", result)
      "unMuteCall" -> handleCallAction(call, "UNMUTE_CALL", result)
      "useSpeaker" -> handleCallAction(call, "USE_SPEAKER", result)
      "useEarpiece" -> handleCallAction(call, "USE_EARPIECE", result)
      "sendEnvelope" -> {
        val callId = call.arguments as? Int
        if (callId != null) {
          sendEnvelope(callId, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Invalid call ID", null)
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun handleCallAction(call: MethodCall, actionName: String, result: Result) {
      val callId = call.arguments as? Int
      if (callId != null) {
          try {
              val intent = Intent(context, TeleService::class.java).apply {
                  action = actionName
                  putExtra("callId", callId)
              }
              context.startService(intent)
              result.success(true)
          } catch (e: Exception) {
              Log.e(TAG, "Error performing $actionName", e)
              result.error("${actionName}_ERROR", "Failed to execute action", e.message)
          }
      } else {
          result.error("INVALID_ARGUMENTS", "Invalid call ID", null)
      }
  }

  private fun startTelephonyService(configuration: Map<String, Any>?, result: Result) {
    try {
      val intent = Intent(context, TeleService::class.java).apply {
        action = "START_TELEPHONY_SERVICE"
        putExtra("configuration", configuration?.toString())
      }
      context.startService(intent)
      
      val initialState = mapOf(
        "accounts" to emptyList<Map<String, Any>>(),
        "calls" to emptyList<Map<String, Any>>(),
        "status" to "started"
      )
      result.success(initialState)
    } catch (e: Exception) {
      Log.e(TAG, "Error starting telephony service", e)
      result.error("START_ERROR", "Failed to start telephony service", e.message)
    }
  }

  private fun makeCall(sim: Int, destination: String, callSettings: Map<String, Any>?, msgData: Map<String, Any>?, result: Result) {
    try {
      Log.d(TAG, "makeCall called with sim=$sim, destination=$destination")
      
      val intent = Intent(context, TeleService::class.java).apply {
        action = "MAKE_CALL"
        putExtra("sim", sim)
        putExtra("destination", destination)
        putExtra("callSettings", callSettings?.toString())
        putExtra("msgData", msgData?.toString())
      }
      context.startService(intent)
      
      // Return true immediately, the Dart code will await the Stream event containing the real Call ID
      result.success(true) 
    } catch (e: Exception) {
      Log.e(TAG, "Error making call", e)
      result.error("MAKE_CALL_ERROR", "Failed to dispatch call intent", e.message)
    }
  }

  private fun sendEnvelope(callId: Int, result: Result) {
    try {
      result.success("TESTTEST")
    } catch (e: Exception) {
      Log.e(TAG, "Error sending envelope", e)
      result.error("SEND_ENVELOPE_ERROR", "Failed to send envelope", e.message)
    }
  }

  private fun requestPermissions(result: Result) {
    try {
      val permissions = arrayOf(
        Manifest.permission.READ_PHONE_STATE,
        Manifest.permission.CALL_PHONE,
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.ANSWER_PHONE_CALLS,
        Manifest.permission.MANAGE_OWN_CALLS
      )
      
      val missingPermissions = permissions.filter {
        ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
      }
      
      if (missingPermissions.isEmpty()) {
        result.success(true)
      } else {
        result.success(false)
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error requesting permissions", e)
      result.error("PERMISSION_ERROR", "Failed to request permissions", e.message)
    }
  }

  private fun hasPermissions(result: Result) {
    try {
      val permissions = arrayOf(
        Manifest.permission.READ_PHONE_STATE,
        Manifest.permission.CALL_PHONE,
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.ANSWER_PHONE_CALLS,
        Manifest.permission.MANAGE_OWN_CALLS
      )
      
      val allGranted = permissions.all {
        ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
      }
      
      result.success(allGranted)
    } catch (e: Exception) {
      Log.e(TAG, "Error checking permissions", e)
      result.error("PERMISSION_ERROR", "Failed to check permissions", e.message)
    }
  }

  fun sendEvent(eventType: String, eventData: Map<String, Any?>) {
    val event = mapOf(
      "type" to eventType,
      "data" to eventData
    )
    Log.d(TAG, "Sending event to Flutter: $event")
    eventSink?.success(event)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    instance = null
  }
}