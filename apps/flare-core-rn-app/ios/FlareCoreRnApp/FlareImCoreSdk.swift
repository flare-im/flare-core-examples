import Foundation
import React

private typealias SyncStringFn = @convention(c) () -> FlareString
private typealias StringFreeFn = @convention(c) (FlareString) -> Void
private typealias ErrorFreeFn = @convention(c) (UnsafePointer<FlareError>?) -> Void
private typealias CreateFn = @convention(c) () -> FlareHandle
private typealias ReleaseFn = @convention(c) (FlareHandle) -> Void
private typealias HardResetFn = @convention(c) () -> Void
private typealias StateFn = @convention(c) (FlareHandle) -> Int32
private typealias BoolFn = @convention(c) (FlareHandle) -> Bool
private typealias Async0Fn = @convention(c) (FlareHandle, UnsafeMutableRawPointer?, FlareResultCallback) -> Int32
private typealias AsyncJsonFn = @convention(c) (
  FlareHandle,
  UnsafePointer<CChar>?,
  UnsafeMutableRawPointer?,
  FlareResultCallback
) -> Int32
private typealias AsyncDispatchFn = @convention(c) (
  FlareHandle,
  UnsafePointer<CChar>?,
  UnsafePointer<CChar>?,
  UnsafeMutableRawPointer?,
  FlareResultCallback
) -> Int32
private typealias AsyncLoginFn = @convention(c) (
  FlareHandle,
  UnsafePointer<CChar>?,
  UnsafePointer<CChar>?,
  UnsafePointer<CChar>?,
  UnsafeMutableRawPointer?,
  FlareResultCallback
) -> Int32
private typealias Async2StringFn = @convention(c) (
  FlareHandle,
  UnsafePointer<CChar>?,
  UnsafePointer<CChar>?,
  UnsafeMutableRawPointer?,
  FlareResultCallback
) -> Int32

private struct NativeDescriptor {
  let operation: String
  let transport: String
  let cApi: String
  let dispatchOp: String?
  let responseEncoding: String
  let returnMode: String
}

private final class PendingCall {
  let operation: String
  let responseEncoding: String
  let returnMode: String
  let resolve: RCTPromiseResolveBlock
  let reject: RCTPromiseRejectBlock

  init(
    operation: String,
    responseEncoding: String,
    returnMode: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    self.operation = operation
    self.responseEncoding = responseEncoding
    self.returnMode = returnMode
    self.resolve = resolve
    self.reject = reject
  }
}

private final class FlareFfiSymbols {
  static var shared: FlareFfiSymbols?

  let sdkVersion: SyncStringFn
  let ffiContractVersion: SyncStringFn
  let stringFree: StringFreeFn
  let errorFree: ErrorFreeFn
  let create: CreateFn
  let release: ReleaseFn
  let hardReset: HardResetFn
  let state: StateFn
  let isConnected: BoolFn
  let sessionActive: BoolFn
  let sdkInit: AsyncJsonFn
  let sdkUninit: Async0Fn
  let sdkLogin: AsyncLoginFn
  let sdkLogout: Async0Fn
  let updateAccessToken: Async2StringFn
  let currentUserId: Async0Fn
  let disconnect: Async0Fn
  let dataRoot: Async0Fn
  let sdkInvokeJson: AsyncDispatchFn
  let messageBuildJson: AsyncJsonFn
  let messageDispatchJson: AsyncDispatchFn
  let capabilityDispatchJson: AsyncDispatchFn
  let mediaDispatchJson: AsyncDispatchFn

  init() throws {
    guard let handle = dlopen(nil, RTLD_NOW) else {
      throw NativeBridgeError("native_library_load_failed", String(cString: dlerror()))
    }

    sdkVersion = try Self.load(handle, "flare_sdk_version")
    ffiContractVersion = try Self.load(handle, "flare_sdk_ffi_contract_version")
    stringFree = try Self.load(handle, "flare_string_free")
    errorFree = try Self.load(handle, "flare_error_heap_free")
    create = try Self.load(handle, "flare_sdk_create")
    release = try Self.load(handle, "flare_sdk_release")
    hardReset = try Self.load(handle, "flare_sdk_hard_reset")
    state = try Self.load(handle, "flare_sdk_state")
    isConnected = try Self.load(handle, "flare_sdk_is_connected")
    sessionActive = try Self.load(handle, "flare_sdk_session_active")
    sdkInit = try Self.load(handle, "flare_sdk_init")
    sdkUninit = try Self.load(handle, "flare_sdk_uninit")
    sdkLogin = try Self.load(handle, "flare_sdk_login")
    sdkLogout = try Self.load(handle, "flare_sdk_logout")
    updateAccessToken = try Self.load(handle, "flare_sdk_update_access_token")
    currentUserId = try Self.load(handle, "flare_sdk_current_user_id")
    disconnect = try Self.load(handle, "flare_sdk_disconnect")
    dataRoot = try Self.load(handle, "flare_sdk_data_root")
    sdkInvokeJson = try Self.load(handle, "flare_sdk_invoke_json")
    messageBuildJson = try Self.load(handle, "flare_message_build_json")
    messageDispatchJson = try Self.load(handle, "flare_message_dispatch_json")
    capabilityDispatchJson = try Self.load(handle, "flare_capability_dispatch_json")
    mediaDispatchJson = try Self.load(handle, "flare_media_dispatch_json")
    Self.shared = self
  }

  private static func load<T>(_ handle: UnsafeMutableRawPointer, _ symbol: String) throws -> T {
    guard let pointer = dlsym(handle, symbol) else {
      throw NativeBridgeError("native_symbol_missing", "Missing FFI symbol: \(symbol)")
    }
    return unsafeBitCast(pointer, to: T.self)
  }

  func takeString(_ value: FlareString) -> String {
    defer { stringFree(value) }
    return copyString(value)
  }

  func copyString(_ value: FlareString) -> String {
    guard let ptr = value.ptr, value.len > 0 else {
      return ""
    }
    return String(decoding: UnsafeRawBufferPointer(start: ptr, count: value.len), as: UTF8.self)
  }
}

private struct NativeBridgeError: Error {
  let code: String
  let message: String

  init(_ code: String, _ message: String) {
    self.code = code
    self.message = message
  }
}

@objc(FlareImCoreSdk)
final class FlareImCoreSdk: NSObject {
  private var symbols: FlareFfiSymbols?
  private var handle: FlareHandle = 0
  private var released = true

  private static var nextContextId = 1
  private static var pending: [Int: PendingCall] = [:]
  private static let lock = NSLock()

  @objc static func requiresMainQueueSetup() -> Bool {
    false
  }

  @objc
  func invoke(
    _ operation: String,
    requestJson: String,
    descriptorJson: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    do {
      let descriptor = try decodeDescriptor(operation: operation, descriptorJson: descriptorJson)
      guard descriptor.operation == operation else {
        reject("native.operation_mismatch", "Native descriptor operation \(descriptor.operation) does not match requested operation \(operation).", nil)
        return
      }
      try invoke(descriptor, requestJson: requestJson, resolve: resolve, reject: reject)
    } catch let error as NativeBridgeError {
      reject(error.code, error.message, error)
    } catch {
      reject("native.invoke_failed", error.localizedDescription, error)
    }
  }

  private func invoke(
    _ descriptor: NativeDescriptor,
    requestJson: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) throws {
    let ffi = try requireSymbols()

    switch descriptor.operation {
    case "diagnostics.ffi_contract_version":
      resolve(try encodeJson(["version": ffi.takeString(ffi.ffiContractVersion())]))
    case "diagnostics.sdk_version":
      resolve(try encodeJson(["version": ffi.takeString(ffi.sdkVersion())]))
    case "sdk.create":
      resolve(try encodeJson(["handle": NSNumber(value: try requireHandle())]))
    case "sdk.dispose":
      releaseHandle()
      resolve("null")
    case "sdk.hard_reset":
      ffi.hardReset()
      handle = 0
      released = true
      resolve("null")
    case "sdk.is_connected":
      resolve(ffi.isConnected(try requireHandle()) ? "true" : "false")
    case "sdk.session_active":
      resolve(ffi.sessionActive(try requireHandle()) ? "true" : "false")
    case "connection.get_state":
      resolve(try encodeJson(connectionState(ffi.state(try requireHandle()))))
    default:
      try invokeAsync(descriptor, requestJson: requestJson, resolve: resolve, reject: reject)
    }
  }

  private func invokeAsync(
    _ descriptor: NativeDescriptor,
    requestJson: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) throws {
    let ffi = try requireSymbols()
    let activeHandle = try requireHandle()
    let contextId = reserveContextId(PendingCall(
      operation: descriptor.operation,
      responseEncoding: descriptor.responseEncoding,
      returnMode: descriptor.returnMode,
      resolve: resolve,
      reject: reject
    ))
    let context = UnsafeMutableRawPointer(bitPattern: contextId)

    let code: Int32
    switch descriptor.cApi {
    case "flare_sdk_init":
      code = requestJson.withCString { ffi.sdkInit(activeHandle, $0, context, Self.resultCallback) }
    case "flare_sdk_uninit":
      code = ffi.sdkUninit(activeHandle, context, Self.resultCallback)
    case "flare_sdk_login":
      let request = try decodeMap(requestJson)
      code = try callLogin(ffi, request: request, context: context)
    case "flare_sdk_logout":
      code = ffi.sdkLogout(activeHandle, context, Self.resultCallback)
    case "flare_sdk_update_access_token":
      let request = try decodeMap(requestJson)
      code = try callTwoString(
        ffi.updateAccessToken,
        first: stringField(request, "accessToken"),
        second: stringField(request, "tenantId"),
        context: context
      )
    case "flare_sdk_current_user_id":
      code = ffi.currentUserId(activeHandle, context, Self.resultCallback)
    case "flare_sdk_disconnect":
      code = ffi.disconnect(activeHandle, context, Self.resultCallback)
    case "flare_sdk_data_root":
      code = ffi.dataRoot(activeHandle, context, Self.resultCallback)
    case "flare_sdk_invoke_json":
      code = try callDispatch(ffi.sdkInvokeJson, op: descriptor.operation, requestJson: requestJson, context: context)
    case "flare_message_build_json":
      code = requestJson.withCString { ffi.messageBuildJson(activeHandle, $0, context, Self.resultCallback) }
    case "flare_message_dispatch_json":
      code = try callDispatch(ffi.messageDispatchJson, op: descriptor.dispatchOp ?? descriptor.operation, requestJson: requestJson, context: context)
    case "flare_capability_dispatch_json":
      code = try callDispatch(ffi.capabilityDispatchJson, op: descriptor.dispatchOp ?? descriptor.operation, requestJson: requestJson, context: context)
    case "flare_media_dispatch_json":
      code = try callDispatch(ffi.mediaDispatchJson, op: descriptor.dispatchOp ?? descriptor.operation, requestJson: requestJson, context: context)
    default:
      removePending(contextId)
      throw NativeBridgeError("native.unsupported_operation", "Unsupported iOS RN FFI operation: \(descriptor.operation) via \(descriptor.cApi).")
    }

    if code != 0 {
      removePending(contextId)
      throw NativeBridgeError("native.submit_failed", "Native C ABI submit failed for \(descriptor.operation) with code \(code).")
    }
  }

  private func requireSymbols() throws -> FlareFfiSymbols {
    if let symbols {
      return symbols
    }
    let loaded = try FlareFfiSymbols()
    symbols = loaded
    return loaded
  }

  private func requireHandle() throws -> FlareHandle {
    if handle == 0 || released {
      let ffi = try requireSymbols()
      handle = ffi.create()
      released = false
    }
    if handle == 0 {
      throw NativeBridgeError("native_create_failed", "flare_sdk_create returned an invalid handle.")
    }
    return handle
  }

  private func releaseHandle() {
    guard handle != 0, !released, let symbols else {
      handle = 0
      released = true
      return
    }
    symbols.release(handle)
    handle = 0
    released = true
  }

  private func callDispatch(
    _ fn: AsyncDispatchFn,
    op: String,
    requestJson: String,
    context: UnsafeMutableRawPointer?
  ) throws -> Int32 {
    let activeHandle = try requireHandle()
    return op.withCString { opPtr in
      requestJson.withCString { requestPtr in
        fn(activeHandle, opPtr, requestPtr, context, Self.resultCallback)
      }
    }
  }

  private func callTwoString(
    _ fn: Async2StringFn,
    first: String,
    second: String,
    context: UnsafeMutableRawPointer?
  ) throws -> Int32 {
    let activeHandle = try requireHandle()
    return first.withCString { firstPtr in
      second.withCString { secondPtr in
        fn(activeHandle, firstPtr, secondPtr, context, Self.resultCallback)
      }
    }
  }

  private func callLogin(
    _ ffi: FlareFfiSymbols,
    request: [String: Any],
    context: UnsafeMutableRawPointer?
  ) throws -> Int32 {
    let activeHandle = try requireHandle()
    let storeConfigJson = stringField(request, "storeConfigJson").isEmpty ? "{}" : stringField(request, "storeConfigJson")
    return stringField(request, "userId").withCString { userId in
      stringField(request, "token").withCString { token in
        storeConfigJson.withCString { storeConfig in
          ffi.sdkLogin(activeHandle, userId, token, storeConfig, context, Self.resultCallback)
        }
      }
    }
  }

  private static let resultCallback: FlareResultCallback = { context, error, result in
    guard let context else {
      FlareFfiSymbols.shared?.stringFree(result)
      return
    }
    let contextId = Int(bitPattern: context)
    guard let pending = takePending(contextId) else {
      FlareFfiSymbols.shared?.stringFree(result)
      return
    }

    if let error {
      let ffi = FlareFfiSymbols.shared
      let code = error.pointee.code
      let message = ffi?.copyString(error.pointee.message) ?? "Native C ABI call failed."
      let details = ffi?.copyString(error.pointee.details_json) ?? ""
      ffi?.errorFree(error)
      ffi?.stringFree(result)
      DispatchQueue.main.async {
        pending.reject("native.\(code)", "\(message) \(details)".trimmingCharacters(in: .whitespacesAndNewlines), nil)
      }
      return
    }

    let raw = FlareFfiSymbols.shared?.takeString(result) ?? ""
    let output = (pending.returnMode == "callback-unit" || pending.responseEncoding == "unit")
      ? "null"
      : (raw.isEmpty ? "null" : raw)
    DispatchQueue.main.async {
      pending.resolve(output)
    }
  }

  private func reserveContextId(_ pending: PendingCall) -> Int {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    let id = Self.nextContextId
    Self.nextContextId += 1
    Self.pending[id] = pending
    return id
  }

  private func removePending(_ id: Int) {
    Self.lock.lock()
    Self.pending.removeValue(forKey: id)
    Self.lock.unlock()
  }

  private static func takePending(_ id: Int) -> PendingCall? {
    lock.lock()
    defer { lock.unlock() }
    return pending.removeValue(forKey: id)
  }

  private func decodeDescriptor(operation: String, descriptorJson: String) throws -> NativeDescriptor {
    let map = try decodeMap(descriptorJson)
    return NativeDescriptor(
      operation: stringField(map, "operation").isEmpty ? operation : stringField(map, "operation"),
      transport: stringField(map, "transport"),
      cApi: stringField(map, "cApi"),
      dispatchOp: optionalStringField(map, "dispatchOp"),
      responseEncoding: stringField(map, "responseEncoding"),
      returnMode: stringField(map, "returnMode")
    )
  }

  private func decodeMap(_ json: String) throws -> [String: Any] {
    guard let data = json.data(using: .utf8) else {
      return [:]
    }
    if data.isEmpty {
      return [:]
    }
    let value = try JSONSerialization.jsonObject(with: data)
    return value as? [String: Any] ?? [:]
  }

  private func encodeJson(_ value: Any) throws -> String {
    if JSONSerialization.isValidJSONObject(value) {
      let data = try JSONSerialization.data(withJSONObject: value)
      return String(data: data, encoding: .utf8) ?? "null"
    }
    if let string = value as? String {
      return "\"\(string.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
    if let bool = value as? Bool {
      return bool ? "true" : "false"
    }
    if let number = value as? NSNumber {
      return number.stringValue
    }
    return "null"
  }

  private func stringField(_ map: [String: Any], _ key: String) -> String {
    if let value = map[key] as? String {
      return value
    }
    return map[key].map { "\($0)" } ?? ""
  }

  private func optionalStringField(_ map: [String: Any], _ key: String) -> String? {
    let value = stringField(map, key)
    return value.isEmpty ? nil : value
  }

  private func connectionState(_ code: Int32) -> String {
    switch code {
    case 1: return "connecting"
    case 2: return "connected"
    case 3: return "ready"
    case 4: return "reconnecting"
    default: return "disconnected"
    }
  }
}
