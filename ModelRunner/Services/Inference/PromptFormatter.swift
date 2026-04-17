import Foundation
import llama

/// Formats chat messages into model-specific prompt strings.
public enum PromptFormatter {

    /// Apply a chat template to format messages.
    ///
    /// `llama_chat_apply_template` takes a template string (retrieved by the caller via
    /// `llama_model_chat_template(model, nil)`), sniffs a family (Gemma, Llama-3, Mistral,
    /// Phi, ChatML, …) from that string, and renders the messages accordingly. When the
    /// model has no embedded template, the caller passes nil here and we fall back to ChatML.
    public static func applyModelTemplate(
        template: String?,
        system: String,
        messages: [ChatMessage]
    ) -> String {
        guard let template else {
            return chatml(system: system, messages: messages)
        }
        return template.withCString { tmplPtr in
            renderWithTemplate(tmplPtr: tmplPtr, system: system, messages: messages)
        }
    }

    private static func renderWithTemplate(
        tmplPtr: UnsafePointer<CChar>,
        system: String,
        messages: [ChatMessage]
    ) -> String {
        var pairs: [(role: String, content: String)] = [("system", system)]
        for msg in messages {
            pairs.append((msg.role == .user ? "user" : "assistant", msg.content))
        }

        // Recursive withCString keeps all C-string pointers alive simultaneously on the stack
        // for the duration of the llama_chat_apply_template call.
        func withCStrings(
            _ pairs: [(role: String, content: String)],
            index: Int,
            accumulated: inout [llama_chat_message],
            body: (UnsafeBufferPointer<llama_chat_message>) -> Int32
        ) -> Int32 {
            if index == pairs.count {
                return accumulated.withUnsafeBufferPointer { body($0) }
            }
            return pairs[index].role.withCString { rolePtr in
                pairs[index].content.withCString { contentPtr in
                    accumulated.append(llama_chat_message(role: rolePtr, content: contentPtr))
                    let r = withCStrings(pairs, index: index + 1, accumulated: &accumulated, body: body)
                    accumulated.removeLast()
                    return r
                }
            }
        }

        let totalChars = pairs.reduce(0) { $0 + $1.role.count + $1.content.count }
        var bufSize = max(totalChars * 2, 1024)
        var buf = [CChar](repeating: 0, count: bufSize)

        var accumulated: [llama_chat_message] = []
        var result = withCStrings(pairs, index: 0, accumulated: &accumulated) { msgBuf in
            llama_chat_apply_template(tmplPtr, msgBuf.baseAddress, msgBuf.count, true, &buf, Int32(bufSize))
        }

        if result > Int32(bufSize) {
            bufSize = Int(result) + 1
            buf = [CChar](repeating: 0, count: bufSize)
            accumulated.removeAll()
            result = withCStrings(pairs, index: 0, accumulated: &accumulated) { msgBuf in
                llama_chat_apply_template(tmplPtr, msgBuf.baseAddress, msgBuf.count, true, &buf, Int32(bufSize))
            }
        }

        guard result > 0 else {
            return chatml(system: system, messages: messages)
        }

        buf[Int(result)] = 0
        return String(cString: buf)
    }

    /// ChatML fallback — used only when the model has no `tokenizer.chat_template` in metadata
    /// or when llama.cpp's template sniffer rejects it.
    public static func chatml(system: String, messages: [ChatMessage]) -> String {
        var result = "<|im_start|>system\n\(system)<|im_end|>\n"
        for message in messages {
            let role = message.role == .user ? "user" : "assistant"
            result += "<|im_start|>\(role)\n\(message.content)<|im_end|>\n"
        }
        result += "<|im_start|>assistant\n"
        return result
    }
}
