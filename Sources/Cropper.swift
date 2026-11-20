import UIKit

/// 裁剪算法 v6：
/// 1) 粗定位：白色占比 > 0.3 的行段（页面卡片两侧有灰边，占比到不了 1），允许 2.5% 缺口合并
/// 2) 带内多行取最长白段定左右
/// 3) 灰带兜底：卡片下方第一段大面积灰色 = 页面底部（面板分隔带）
/// 4) 纵向按非白内容收紧（横向保持卡片宽度，多页字号一致）
/// 5) 去掉底部孤立页码行
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
        guard let cgImg = cg else { return (image, "无 CGImage") }

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
            return (image, "建位图失败")
        }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))

        func isWhite(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] >= 246 && buffer[o + 1] >= 246 && buffer[o + 2] >= 246
        }
        func isGray(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            let r = Int(buffer[o]), g = Int(buffer[o + 1]), b = Int(buffer[o + 2])
            return abs(r - 242) < 12 && abs(g - 243) < 12 && abs(b - 249) < 12
        }
        func isContent(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] < 245 || buffer[o + 1] < 245 || buffer[o + 2] < 245
        }

        var whiteFrac = [Double](repeating: 0, count: h)
        var grayFrac = [Double](repeating: 0, count: h)
        for y in 0..<h {
            var wc = 0
            var gc = 0
            var x = 0
            while x < w {
                if isWhite(x, y) { wc += 1 }
                if isGray(x, y) { gc += 1 }
                x += 1
            }
            whiteFrac[y] = Double(wc) / Double(w)
            grayFrac[y] = Double(gc) / Double(w)
        }

        // 1) 粗定位
        var runs: [(Int, Int)] = []
        var s = -1
        for y in 0..<h {
            if whiteFrac[y] > 0.3 {
                if s < 0 { s = y }
            } else if s >= 0 {
                runs.append((s, y - 1))
                s = -1
            }
        }
        if s >= 0 { runs.append((s, h - 1)) }

        let mergeGap = max(10, Int(Double(h) * 0.025))
        var merged: [(Int, Int)] = []
        for r in runs {
            if let last = merged.last, r.0 - last.1 <= mergeGap {
                merged[merged.count - 1] = (last.0, r.1)
            } else {
                merged.append(r)
            }
        }
        let minLen = Int(Double(h) * 0.15)
        merged = merged.filter { $0.1 - $0.0 >= minLen }

        func fallback(_ why: String) -> (UIImage, String) {
            let y0 = Int(Double(h) * 0.16)
            let y1 = Int(Double(h) * 0.70)
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
        var top = best.0
        var bottom = best.1
        if bottom - top < h / 6 { return fallback("白页太短") }

        // 2) 左右
        var left = 0
        var right = w - 1
        var bestLen = 0
        for k in 0..<24 {
            let sy = top + (bottom - top) * (k + 1) / 25
            var st = -1
            var x = 0
            while x < w {
                if isWhite(x, sy) {
                    if st < 0 { st = x }
                } else if st >= 0 {
                    if x - st > bestLen { bestLen = x - st; left = st; right = x - 1 }
                    st = -1
                }
                x += 1
            }
            if st >= 0 && w - st > bestLen { bestLen = w - st; left = st; right = w - 1 }
        }
        if bestLen < w / 3 { left = 0; right = w - 1 }

        // 3) 灰带兜底
        var y2 = top + max(10, (bottom - top) / 20)
        while y2 <= bottom {
            if grayFrac[y2] > 0.5 {
                bottom = y2 - 1
                break
            }
            y2 += 1
        }
        if bottom - top < h / 6 { return fallback("页面过短") }

        // 4) 纵向收紧
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

        // 5) 去页码
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
        guard let cropped = cgImg.cropping(to: rect) else { return fallback("裁剪失败") }
        return (UIImage(cgImage: cropped, scale: 1, orientation: .up),
                "\(w)x\(h) → \(Int(rect.width))x\(Int(rect.height))")
    }
}
