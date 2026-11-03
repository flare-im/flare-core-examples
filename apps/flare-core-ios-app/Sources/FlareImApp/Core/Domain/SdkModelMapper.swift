import FlareCoreAppleSDK

enum SdkModelMapper {
    static func conversationFromCore(_ conversation: Conversation) -> AppConversation {
        AppConversation(core: conversation)
    }

    static func conversationsFromCore(_ conversations: [Conversation]) -> [AppConversation] {
        conversations.map(conversationFromCore)
    }

    static func messageFromCore(_ message: Message) -> AppMessage {
        AppMessage(core: message)
    }

    static func messagesFromCore(_ messages: [Message]) -> [AppMessage] {
        messages.map(messageFromCore)
    }
}
