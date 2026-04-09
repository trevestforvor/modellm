import Foundation

extension QuantizationType {
    /// Parses quantization type from a GGUF filename by matching against rawValue strings.
    ///
    /// Examples:
    ///   "llama-3-8b-instruct.Q4_K_M.gguf" → .q4KM
    ///   "gemma-2b-it-Q2_K.gguf"           → .q2K
    ///   "model.Q8_0.gguf"                  → .q8_0
    ///   "model.gguf"                        → .unknown
    ///   "MODEL.Q4_K_M.GGUF"               → .q4KM (case-insensitive)
    ///
    /// Iteration order follows QuantizationType.allCases declaration order.
    /// More specific variants (Q3_K_S, Q3_K_M) appear before less specific (Q3_K)
    /// in the enum, so first-match is safe.
    static func fromFilename(_ filename: String) -> QuantizationType {
        let upper = filename.uppercased()
        for quant in QuantizationType.allCases where quant != .unknown {
            if upper.contains(quant.rawValue) {
                return quant
            }
        }
        return .unknown
    }
}
