import XCTest
@testable import FlareImApp

/// iOS 的送达状态必须与**核心**逐位一致。动作可用性不用对：iOS 直接问核心要答案。
///
/// 向量由核心生成（`cargo test action_availability_vectors`）；
/// 规则一改这里就红，逼你回来看 iOS 是否要跟着改。
final class MessageActionVectorsTests: XCTestCase {

    private struct Vector: Decodable {
        struct Input: Decodable {
            let isSelf: Bool
            let messageType: Int
            let status: Int
            let hasText: Bool
            let isPending: Bool
            let isPinned: Bool
            let isConnected: Bool
            let multiSelectMode: Bool
            let isFailed: Bool
            let isRead: Bool
        }
        let label: String
        let input: Input
        let deliveryState: String
    }

    private struct Vectors: Decodable { let cases: [Vector] }

    func testDeliveryStateMatchesCoreVectors() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FlareImAppTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // flare-core-ios-app
            .deletingLastPathComponent()   // examples
            .deletingLastPathComponent()   // flare-im-core-client-sdk 根
        let url = root.appendingPathComponent("sdk-spec/message-action-vectors.json")
        let data = try Data(contentsOf: url)
        let vectors = try JSONDecoder().decode(Vectors.self, from: data)

        XCTAssertGreaterThanOrEqual(
            vectors.cases.count, 10,
            "向量太少，这条门禁形同虚设"
        )

        for vector in vectors.cases {
            let delivery = MessageDelivery.state(
                isSelf: vector.input.isSelf,
                status: vector.input.status,
                isRead: vector.input.isRead,
                isPending: vector.input.isPending,
                isFailed: vector.input.isFailed
            )
            XCTAssertEqual(
                delivery.rawValue, vector.deliveryState,
                "送达状态与核心不一致：\(vector.label)"
            )
        }
    }
}
