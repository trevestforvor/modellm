import Testing
@testable import ModelRunner

@Suite("PromptFormatter")
struct PromptFormatterTests {

    @Test("chatml with empty messages starts with system block and ends with assistant tag")
    func testChatmlEmptyMessages() {
        let result = PromptFormatter.chatml(system: "You are helpful.", messages: [])
        #expect(result.hasPrefix("<|im_start|>system\nYou are helpful.<|im_end|>\n"))
        #expect(result.hasSuffix("<|im_start|>assistant\n"))
    }

    @Test("chatml wraps user message in correct tags")
    func testChatmlUserMessage() {
        let messages = [ChatMessage(role: .user, content: "Hello")]
        let result = PromptFormatter.chatml(system: "Be helpful.", messages: messages)
        #expect(result.contains("<|im_start|>user\nHello<|im_end|>\n"))
        #expect(result.hasSuffix("<|im_start|>assistant\n"))
    }

    @Test("chatml renders full conversation with alternating roles")
    func testChatmlConversation() {
        let messages = [
            ChatMessage(role: .user, content: "What is 2+2?"),
            ChatMessage(role: .assistant, content: "4"),
            ChatMessage(role: .user, content: "Why?")
        ]
        let result = PromptFormatter.chatml(system: "Math tutor.", messages: messages)
        #expect(result.contains("<|im_start|>user\nWhat is 2+2?<|im_end|>\n"))
        #expect(result.contains("<|im_start|>assistant\n4<|im_end|>\n"))
        #expect(result.hasSuffix("<|im_start|>assistant\n"))
    }

    @Test("system block always precedes user block")
    func testChatmlRoleOrder() {
        let messages = [ChatMessage(role: .user, content: "Hi")]
        let result = PromptFormatter.chatml(system: "sys", messages: messages)
        let systemRange = result.range(of: "<|im_start|>system")!
        let userRange = result.range(of: "<|im_start|>user")!
        #expect(systemRange.lowerBound < userRange.lowerBound)
    }

    @Test("chatml produces correct token count for multi-turn conversation")
    func testChatmlTokenStructure() {
        let messages = [
            ChatMessage(role: .user, content: "A"),
            ChatMessage(role: .assistant, content: "B")
        ]
        let result = PromptFormatter.chatml(system: "S", messages: messages)
        // Count im_start occurrences: system + user + assistant turn + trailing = 4
        let count = result.components(separatedBy: "<|im_start|>").count - 1
        #expect(count == 4)
    }
}
