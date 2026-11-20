import UIKit

/// 从截图里裁出试卷内容，并返回「原图尺寸 → 裁剪尺寸」的诊断字符串。
enum Cropper {

    static func cropPage(_ image: UIImage) -> (UIImage, String) {
        var cg = image.cgImage
        if cg == nil {
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.scale = 1
            let r = UIGraphicsImageRenderer(size: image.size, format: fmt)
            let rendered = r.image { _ in image.draw(at: .zero) }
            cg = rendered.cgImage
        }
        guard let cgImg = cg else { return (image, "无 CGImage，跳过") }

        let w = cgImg.width
        let h = cgImg.height
        guard w > 60, h > 60 else { return (image, "图太小 \(w)x\(h)") }

        let bpp = 4
        let bpr = w * bpp
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: h * bpr)
        buffer.initialize(repeating: 0, count: h * bpr)
        defer { buffer.deallocate() }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: buffer, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: bpr, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return (image, "建位图失败 \(w)x\(h)")
        }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))

        func isWhite(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] >= 248 && buffer[o + 1] >= 248 && buffer[o + 2] >= 248
        }
        func isContent(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] < 245 || buffer[o + 1] < 245 || buffer[o + 2] < 245
        }

        var whiteFrac = [Double](repeating: 0, count: h)
        for y in 0..<h {
            var wc = 0
            var x = 0
            while x < w {
                if isWhite(x, y) { wc += 1 }
                x += 1
            }
            whiteFrac[y] = Double(wc) / Double(w)
        }

        // 连续白行段（允许小缺口）
        var runs: [(Int, Int)] = []
        var start = -1
        for y in 0..<h {
            if whiteFrac[y] > 0.5 {
                if start < 0 { start = y }
            } else if start >= 0 {
                runs.append((start, y - 1))
                start = -1
            }
        }
        if start >= 0 { runs.append((start, h - 1)) }

        let mergeGap = max(8, Int(Double(h) * 0.015))
        var merged: [(Int, Int)] = []
        for r in runs {
            if let last = merged.last, r.0 - last.1 <= mergeGap {
                merged[merged.count - 1] = (last.0, r.1)
            } else {
                merged.append(r)
            }
        }

        func fallback(_ why: String) -> (UIImage, String) {
            let y0 = Int(Double(h) * 0.05)
            let y1 = Int(Double(h) * 0.78)
            let rect = CGRect(x: 0, y: y0, width: w, height: max(1, y1 - y0))
            if let c = cgImg.cropping(to: rect) {
                return (UIImage(cgImage: c, scale: 1, orientation: .up),
                        "\(why)，兜底 \(w)x\(h) → \(Int(rect.width))x\(Int(rect.height))")
            }
            return (image, "\(why)，未裁剪 \(w)x\(h)")
        }

        guard let best = merged.max(by: { ($0.1 - $0.0) < ($1.1 - $1.0) }) else {
            return fallback("找不到白色页")
        }
        if best.1 - best.0 < h / 5 { return fallback("白页太短") }

        var top = best.0
        var bottom = best.1

        var left = 0
        var right = w - 1
        var bestLen = 0
        for k in 0..<20 {
            let sy = top + (bottom - top) * (k + 1) / 21
            var s = -1
            var x = 0
            while x < w {
                if isWhite(x, sy) {
                    if s < 0 { s = x }
                } else if s >= 0 {
                    if x - s > bestLen { bestLen = x - s; left = s; right = x - 1 }
                    s = -1
                }
                x += 1
            }
            if s >= 0 && w - s > bestLen { bestLen = w - s; left = s; right = w - 1 }
        }
        if bestLen < w / 3 { left = 0; right = w - 1 }

        var cy0 = -1
        var cy1 = -1
        for yy in top...bottom {
            var has = false
            var xx = left
            while xx <= right {
                if isContent(xx, yy) { has = true; break }
                xx += 1
            }
            if has {
                if cy0 < 0 { cy0 = yy }
                cy1 = yy
            }
        }
        if cy0 >= 0 {
            let pad = 24
            top = max(top, cy0 - pad)
            bottom = min(bottom, cy1 + pad)
        }

        // 去掉底部孤立页码
        let cardH = bottom - top + 1
        if cardH > 100 {
            var blocks: [(Int, Int)] = []
            var inBlock = false
            var sRow = 0
            for ry in top...bottom {
                var has = false
                var rx = left
                while rx <= right {
                    if isContent(rx, ry) { has = true; break }
                    rx += 1
                }
                if has && !inBlock { inBlock = true; sRow = ry }
                else if !has && inBlock { inBlock = false; blocks.append((sRow, ry - 1)) }
            }
            if inBlock { blocks.append((sRow, bottom)) }

            if blocks.count >= 2 {
                let lastB = blocks[blocks.count - 1]
                let prevB = blocks[blocks.count - 2]
                let gap = lastB.0 - prevB.1
                let lastH = lastB.1 - lastB.0 + 1
                if Double(gap) > Double(cardH) * 0.06 &&
                    Double(lastH) < Double(cardH) * 0.05 &&
                    lastB.0 > top + Int(Double(cardH) * 0.8) {
                    bottom = min(bottom, prevB.1 + 12)
                }
            }
        }

        let rect = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
        guard let cropped = cgImg.cropping(to: rect) else {
            return fallback("裁剪失败")
        }
        let out = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        return (out, "\(w)x\(h) → \(Int(rect.width))x\(Int(rect.height))")
    }
}
