import Testing
@testable import ModelRunner

@Suite("QuantizationType.fromFilename")
struct QuantizationTypeTests {

    @Test("parses Q4_K_M from standard filename")
    func testQ4KM() {
        #expect(QuantizationType.fromFilename("llama-3-8b-instruct.Q4_K_M.gguf") == .q4KM)
    }

    @Test("parses Q2_K from filename")
    func testQ2K() {
        #expect(QuantizationType.fromFilename("gemma-2b-it-Q2_K.gguf") == .q2K)
    }

    @Test("parses Q3_K_S from filename")
    func testQ3KS() {
        #expect(QuantizationType.fromFilename("model.Q3_K_S.gguf") == .q3KS)
    }

    @Test("parses Q3_K_M from filename without matching Q3_K_S")
    func testQ3KM() {
        #expect(QuantizationType.fromFilename("model.Q3_K_M.gguf") == .q3KM)
    }

    @Test("parses Q8_0 from filename")
    func testQ8_0() {
        #expect(QuantizationType.fromFilename("model.Q8_0.gguf") == .q8_0)
    }

    @Test("returns unknown for bare .gguf with no quantization tag")
    func testUnknown() {
        #expect(QuantizationType.fromFilename("model.gguf") == .unknown)
    }

    @Test("matching is case-insensitive — uppercase GGUF extension")
    func testCaseInsensitive() {
        #expect(QuantizationType.fromFilename("MODEL.Q4_K_M.GGUF") == .q4KM)
    }

    @Test("parses Q5_K_M from filename")
    func testQ5KM() {
        #expect(QuantizationType.fromFilename("mistral-7b.Q5_K_M.gguf") == .q5KM)
    }

    @Test("parses F16 from filename")
    func testF16() {
        #expect(QuantizationType.fromFilename("llama-3-8b.F16.gguf") == .f16)
    }
}
