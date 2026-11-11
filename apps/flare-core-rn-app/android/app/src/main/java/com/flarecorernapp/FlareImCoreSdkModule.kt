package com.flarecorernapp

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.flare.im.bridge.FlareSdkException
import com.flare.im.bridge.JniNativeBridge
import com.flare.im.contract.NativeCallDescriptor
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine

class FlareImCoreSdkModule(
  reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {
  private val bridge = JniNativeBridge()

  override fun getName(): String = "FlareImCoreSdk"

  @ReactMethod
  fun invoke(operation: String, requestJson: String, descriptorJson: String, promise: Promise) {
    val descriptor = try {
      descriptorFromJson(operation, descriptorJson)
    } catch (error: Throwable) {
      promise.reject("native.invalid_descriptor", error.message ?: "Invalid native call descriptor.", error)
      return
    }

    if (descriptor.operation != operation) {
      promise.reject(
        "native.operation_mismatch",
        "Native descriptor operation ${descriptor.operation} does not match requested operation $operation.",
      )
      return
    }

    val request = try {
      decodeJson(requestJson)
    } catch (error: Throwable) {
      promise.reject("native.invalid_request", error.message ?: "Invalid native request JSON.", error)
      return
    }

    suspend {
      bridge.invoke<Any?>(descriptor, request)
    }.startCoroutine(
      object : Continuation<Any?> {
        override val context = EmptyCoroutineContext

        override fun resumeWith(result: Result<Any?>) {
          result
            .onSuccess { value -> promise.resolve(encodeJson(value)) }
            .onFailure { error -> reject(operation, error, promise) }
        }
      },
    )
  }

  private fun reject(operation: String, error: Throwable, promise: Promise) {
    if (error is FlareSdkException) {
      promise.reject(error.code, error.message, error)
      return
    }
    promise.reject("native.invoke_failed", error.message ?: "Native invoke failed for $operation.", error)
  }

  private fun descriptorFromJson(operation: String, descriptorJson: String): NativeCallDescriptor {
    val json = JSONObject(descriptorJson)
    return NativeCallDescriptor(
      module = json.getString("module"),
      method = json.getString("method"),
      operation = json.optString("operation", operation),
      transport = json.getString("transport"),
      cApi = json.getString("cApi"),
      requestEncoding = json.getString("requestEncoding"),
      responseEncoding = json.getString("responseEncoding"),
      returnMode = json.getString("returnMode"),
      handlePolicy = json.getString("handlePolicy"),
      dispatchOp = json.optNullableString("dispatchOp"),
      callback = json.optNullableString("callback"),
    )
  }

  private fun decodeJson(json: String): Any? {
    if (json.isBlank()) {
      return emptyMap<String, Any?>()
    }
    return fromJsonValue(JSONTokener(json).nextValue())
  }

  private fun fromJsonObject(value: JSONObject): Map<String, Any?> = buildMap {
    val keys = value.keys()
    while (keys.hasNext()) {
      val key = keys.next()
      put(key, fromJsonValue(value.get(key)))
    }
  }

  private fun fromJsonArray(value: JSONArray): List<Any?> =
    List(value.length()) { index -> fromJsonValue(value.get(index)) }

  private fun fromJsonValue(value: Any?): Any? = when (value) {
    null, JSONObject.NULL -> null
    is JSONObject -> fromJsonObject(value)
    is JSONArray -> fromJsonArray(value)
    else -> value
  }

  private fun encodeJson(value: Any?): String {
    val jsonValue = toJsonValue(value)
    return when (jsonValue) {
      JSONObject.NULL -> "null"
      is JSONObject, is JSONArray -> jsonValue.toString()
      is String -> JSONObject.quote(jsonValue)
      else -> jsonValue.toString()
    }
  }

  private fun toJsonObject(value: Map<*, *>): JSONObject {
    val out = JSONObject()
    value.forEach { (key, item) ->
      if (key != null) {
        out.put(key.toString(), toJsonValue(item))
      }
    }
    return out
  }

  private fun toJsonArray(value: Iterable<*>): JSONArray {
    val out = JSONArray()
    value.forEach { out.put(toJsonValue(it)) }
    return out
  }

  private fun toJsonValue(value: Any?): Any = when (value) {
    null -> JSONObject.NULL
    is Map<*, *> -> toJsonObject(value)
    is Iterable<*> -> toJsonArray(value)
    is Array<*> -> toJsonArray(value.asIterable())
    is Enum<*> -> value.name.lowercase()
    else -> value
  }
}

private fun JSONObject.optNullableString(name: String): String? {
  if (!has(name) || isNull(name)) {
    return null
  }
  return optString(name).takeIf { it.isNotBlank() }
}
