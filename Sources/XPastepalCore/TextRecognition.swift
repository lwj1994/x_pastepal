import Foundation
import ImageIO
import Vision

enum TextRecognition {
    /// Vision 和图片解码只在调用方的后台任务中执行，识别数据不离开本机。
    static func recognize(_ data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0 else {
            throw RecognitionError.invalidImage
        }
        guard width.doubleValue * height.doubleValue <= 50_000_000 else {
            throw RecognitionError.imageTooLarge
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"].filter(supported.contains)
        try VNImageRequestHandler(data: data).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum RecognitionError: LocalizedError {
    case invalidImage
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法读取这张图片"
        case .imageTooLarge: return "图片超过 5,000 万像素，请先缩小后再识别"
        }
    }
}
