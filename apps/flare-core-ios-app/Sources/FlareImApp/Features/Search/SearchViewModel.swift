import FlareCoreAppleSDK
import Foundation

/// 消息搜索特性的 ViewModel。自包含:草稿 + 结果 + 搜索动作。
/// 依赖共享的 [AppSession](客户端)与 [AppEnvironment](操作执行 / 当前选中会话 / 分栏)。
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var draft = SearchDraft()
    @Published private(set) var results: [AppMessage] = []

    private let session: AppSession
    private let environment: AppEnvironment

    init(session: AppSession, environment: AppEnvironment) {
        self.session = session
        self.environment = environment
    }

    func search() async {
        await environment.run("message.search") { [self] in
            guard let client = session.client else { throw AppStoreError(message: "Login before searching messages") }
            let scopedId = draft.conversationScoped ? environment.selectedConversationId : nil
            let query = MessageSearchQuery(
                conversationId: scopedId,
                includeRecalled: draft.includeRecalled,
                keyword: draft.keyword.isEmpty ? nil : draft.keyword,
                kinds: [draft.kind],
                limit: 100,
                senderId: draft.senderId.isEmpty ? nil : draft.senderId
            )
            let response: ListMessagesResponse
            if scopedId != nil {
                response = try await client.messages.searchMessagesInConversation(query)
            } else if !draft.keyword.isEmpty {
                response = try await client.messages.searchMessagesByQuery(query)
            } else {
                response = try await client.messages.searchMessages(query)
            }
            results = SdkModelMapper.messagesFromCore(response.messages)
                .sorted { $0.appSortTimestamp > $1.appSortTimestamp }
            environment.section = .search
        }
    }
}
