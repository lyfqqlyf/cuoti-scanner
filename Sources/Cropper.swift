import UIKit

/// 纯比例裁剪：上下左右四个百分比，不做任何图像识别。
enum Cropper {

    struct Result {
        let image: UIImage
        let rect: CGRect
        let info: String
    }

    static func crop(_ image: UIImage,
                     topPct: Double,
                     bottomPct: Double,
                     leftPct: Double,
                     rightPct: Double) -> Result {
        guard let cgImg = image.cgImage else {
            return Result(image: image, rect: .zero, info: "无 CGImage")
        }
        let w = cgImg.width
        let h = cgImg.height
        guard w > 20, h > 20 else {
            return Result(image: image, rect: .zero, info: "图太小")
        }

        let x0 = Int(Double(w) * max(0, min(0.95, leftPct)))
        let x1 = Int(Double(w) * max(leftPct + 0.03, min(1.0, rightPct)))
        let y0 = Int(Double(h) * max(0, min(0.95, topPct)))
        let y1 = Int(Double(h) * max(topPct + 0.03, min(1.0, bottomPct)))

        let rect = CGRect(x: x0, y: y0,
                          width: max(1, x1 - x0),
                          height: max(1, y1 - y0))
        guard let c = cgImg.cropping(to: rect) else {
            return Result(image: image, rect: .zero, info: "裁剪失败")
        }
        let info = "上\(Int(topPct * 100))% 下\(Int(bottomPct * 100))% 左\(Int(leftPct * 100))% 右\(Int(rightPct * 100))% → \(Int(rect.width))x\(Int(rect.height))"
        return Result(image: UIImage(cgImage: c, scale: 1, orientation: .up),
                      rect: rect,
                      info: info)
    }
}
