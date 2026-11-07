import FlareCoreAppleSDK
import FlareIMUI
import Foundation
import SwiftUI

/// A `flare-recover://` link as the system handed it, unchanged; nil for anything else. The core verifies it.
func parseRecoveryLink(_ raw: String?) -> String? {
    let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.lowercased().hasPrefix("flare-recover://") ? text : nil
}

private func present(_ value: String?) -> String? { value?.isEmpty == true ? nil : value }

extension FlareAccessStatus {
    /// `access.getStatus` as the kit's diagnostics page takes it.
    init(_ status: AccessStatus) {
        self.init(loaded: status.loaded, serial: Int64(clamping: status.serial), source: status.source, stale: status.stale,
                  developmentMode: status.developmentMode, regionId: present(status.regionId),
                  accessPointId: present(status.accessPointId), protocol: present(status.protocol),
                  connectAck: status.connectAck.map {
                      FlareAccessConnectAck(accessPointId: $0.accessPointId, accessPointMismatch: $0.accessPointMismatch)
                  },
                  recovering: status.recovering.map {
                      FlareAccessRecovering(rounds: Int($0.rounds), nextRoundAtMs: $0.nextRoundAtMs)
                  })
    }
}

extension FlareAccessPoint {
    /// One row of `access.listAccessPoints` as the kit's diagnostics page takes it.
    init(_ point: AccessPointInfo) {
        self.init(accessPointId: point.accessPointId, regionId: present(point.regionId), host: present(point.host),
                  status: point.status, rttMs: point.rttMs, breaker: point.breaker, pinned: point.pinned,
                  current: point.current)
    }
}

/// `access.exportDiagnostics` as readable JSON: the SDK wraps every value, the clipboard wants plain text.
func accessDiagnosticsJSON(_ diagnostics: [String: AnySendable]) throws -> String {
    func plain(_ value: Any) -> Any {
        switch value {
        case let wrapped as AnySendable: return plain(wrapped.value)
        case let map as [String: Any]: return map.mapValues(plain)
        case let list as [Any]: return list.map(plain)
        default: return value
        }
    }
    let json = plain(diagnostics)
    guard JSONSerialization.isValidJSONObject(json) else { throw AppStoreError(message: "Diagnostics are not JSON") }
    let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

/// The host of the network and line page: it reads `access.*`, hands the results to the kit's ``AccessDiagnosticsView``
/// and carries out what the kit reports. What the page says and which line can be pinned are the kit's.
///
/// One lives with the app store, so a recovery link opened from outside and the page it opens read the same outcome.
@MainActor
final class AccessDiagnostics: ObservableObject {
    @Published private(set) var status: FlareAccessStatus?
    @Published private(set) var accessPoints: [FlareAccessPoint] = []
    @Published private(set) var refreshing = false
    @Published private(set) var refreshOutcome: String?
    @Published private(set) var importing = false
    @Published private(set) var importOutcome: String?
    @Published private(set) var importCode: String?
    @Published private(set) var exporting = false
    @Published private(set) var exportOutcome: String?
    /// The core refused the last pin: the line left the directory meanwhile.
    @Published private(set) var pinRefused = false
    /// The page over everything: settings, the connection banner and a recovery link all open it there.
    @Published var presented = false

    private let access: @MainActor () async throws -> any AccessApiProtocol
    private let subscribeLinkEvents: @MainActor (@escaping @Sendable () -> Void) -> () -> Void
    private let writeClipboard: (String) -> Void
    private var stopFollowing: (() -> Void)?
    /// Bumped by every read: a slower read that started earlier must not put an older directory back.
    private var reads = 0

    init(access: @escaping @MainActor () async throws -> any AccessApiProtocol,
         subscribeLinkEvents: @escaping @MainActor (@escaping @Sendable () -> Void) -> () -> Void,
         writeClipboard: @escaping (String) -> Void = PlatformClipboard.copy) {
        self.access = access
        self.subscribeLinkEvents = subscribeLinkEvents
        self.writeClipboard = writeClipboard
    }

    func reload() async {
        reads += 1
        let read = reads
        do {
            let api = try await access()
            let nextStatus = try await api.getStatus()
            let nextPoints = try await api.listAccessPoints()
            guard read == reads else { return }
            status = FlareAccessStatus(nextStatus)
            accessPoints = nextPoints.map(FlareAccessPoint.init)
        } catch {
            print("[access] reading the access directory failed: \(error)")
        }
    }

    /// Reads now and again on every link event, until ``stop()``. The first read brings the client up.
    func follow() async {
        await reload()
        if stopFollowing == nil {
            stopFollowing = subscribeLinkEvents { [weak self] in
                Task { @MainActor in await self?.reload() }
            }
        }
    }

    func stop() {
        stopFollowing?()
        stopFollowing = nil
    }

    func pin(_ accessPointId: String) async {
        pinRefused = false
        do {
            _ = try await access().pin(AccessPinRequest(accessPointId: accessPointId))
        } catch {
            print("[access] pinning an access point failed: \(error)")
            pinRefused = true
        }
        await reload()
    }

    func unpin() async {
        pinRefused = false
        do {
            try await access().unpin()
        } catch {
            print("[access] unpinning failed: \(error)")
        }
        await reload()
    }

    func refresh() async {
        refreshing = true
        refreshOutcome = nil
        var outcome = "failed"
        do {
            outcome = try await access().refresh().outcome
        } catch {
            print("[access] refreshing the access manifest failed: \(error)")
        }
        refreshing = false
        refreshOutcome = outcome
        await reload()
    }

    /// A bad link comes back as `rejected` with its code; only a configuration problem throws, and that is no reason
    /// to say nothing.
    func importRecovery(_ link: String) async {
        importing = true
        importOutcome = nil
        importCode = nil
        var outcome = "rejected"
        var code: String?
        do {
            let imported = try await access().importRecovery(AccessImportRecoveryRequest(link: link))
            outcome = imported.outcome
            code = imported.code
        } catch {
            print("[access] importing a recovery link failed: \(error)")
        }
        importing = false
        importOutcome = outcome
        importCode = code
        await reload()
    }

    /// A recovery link from outside the app: imported at once, and the page opens to say what became of it.
    func openRecoveryLink(_ link: String) {
        presented = true
        Task { await importRecovery(link) }
    }

    func exportDiagnostics() async {
        exporting = true
        exportOutcome = nil
        var outcome = "failed"
        do {
            writeClipboard(try accessDiagnosticsJSON(try await access().exportDiagnostics()))
            outcome = "copied"
        } catch {
            print("[access] copying the diagnostics failed: \(error)")
        }
        exporting = false
        exportOutcome = outcome
    }
}

/// Network and lines: settings, the connection notice's "diagnose" and a recovery link all open this page. The body is
/// the kit's ``AccessDiagnosticsView``; the reads and calls are in ``AccessDiagnostics``.
struct AccessDiagnosticsScreen: View {
    @ObservedObject var model: AccessDiagnostics
    @Environment(\.flareStrings) private var strings

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: FlareSizes.spacingMd) {
                    if model.pinRefused {
                        StatusBannerView(text: String(localized: "This line is no longer available. The list has been refreshed."),
                                         tone: .danger)
                    }
                    AccessDiagnosticsView(
                        status: model.status,
                        accessPoints: model.accessPoints,
                        refreshing: model.refreshing,
                        refreshOutcome: model.refreshOutcome,
                        importing: model.importing,
                        importOutcome: model.importOutcome,
                        importCode: model.importCode,
                        exporting: model.exporting,
                        exportOutcome: model.exportOutcome,
                        onPin: { id in Task { await model.pin(id) } },
                        onUnpin: { Task { await model.unpin() } },
                        onRefresh: { Task { await model.refresh() } },
                        onImportRecovery: { link in Task { await model.importRecovery(link) } },
                        onExportDiagnostics: { Task { await model.exportDiagnostics() } }
                    )
                }
                .padding(FlareSizes.spacingLg)
            }
            .flareShowsImportAnswer(model.importOutcome, lines: model.accessPoints.count, proxy: proxy)
        }
        .background(FlareDesign.appBackground)
        .navigationTitle(strings.accessDiagnosticsTitle)
        .task { await model.follow() }
        .onDisappear { model.stop() }
    }
}

/// The page over the whole app, in either sign-in state.
struct AccessDiagnosticsPresenter: ViewModifier {
    @ObservedObject var model: AccessDiagnostics

    func body(content: Content) -> some View {
        content.sheet(isPresented: $model.presented) {
            NavigationStack {
                AccessDiagnosticsScreen(model: model)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Close")) { model.presented = false }
                        }
                    }
            }
        }
    }
}
