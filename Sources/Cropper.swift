import UIKit

/// 从截图里裁出试卷内容：
/// 1) 用「大面积灰色分隔带」定位页面底部（比纯白段稳）
/// 2) 用最长白色段定左右
/// 3) 再按非白像素外接框收紧，去掉多余白边
/// 4) 去掉底部孤立的页码行（如「第2页/共2页」）
enum Cropper {

    static func cropPage(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = cg.width
        let h = cg.height
        guard w > 60, h > 60 else { return image }

        let bpp = 4
        let bpr = w * bpp
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: h * bpr)
        buffer.initialize(repeating: 0, count: h * bpr)
        defer { buffer.deallocate() }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: buffer,
                                  width: w,
                                  height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bpr,
                                  space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return image
        }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        func isWhite(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] >= 248 && buffer[o + 1] >= 248 && buffer[o + 2] >= 248
        }
        func isGray(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            let r = Int(buffer[o]), g = Int(buffer[o + 1]), b = Int(buffer[o + 2])
            return abs(r - 242) < 10 && abs(g - 243) < 10 && abs(b - 249) < 10
        }

        // 行统计
        var whiteFrac = [Double](repeating: 0, count: h)
        var grayFrac = [Double](repeating: 0, count: h)
        var y = 0
        while y < h {
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
            y += 1
        }

        // 页面顶部
        var top = 0
        for yy in 0..<h where whiteFrac[yy] > 0.5 {
            top = yy
            break
        }

        // 页面底部：顶部之后第一段灰色带
        var bottom = -1
        var yy = top + 10
        while yy < h {
            if grayFrac[yy] > 0.5 {
                bottom = yy - 1
                break
            }
            yy += 1
        }
        if bottom < 0 {
            for k in stride(from: h - 1, through: top, by: -1) where whiteFrac[k] > 0.5 {
                bottom = k
                break
            }
        }
        if bottom < 0 || bottom - top < h / 5 { bottom = h - 1 }

        // 左右：页面中段多行取最长白色段
        var left = 0
        var right = w - 1
        var best = 0
        for k in 0..<20 {
            let sy = top + (bottom - top) * (k + 1) / 21
            var start = -1
            var x = 0
            while x < w {
                if isWhite(x, sy) {
                    if start < 0 { start = x }
                } else if start >= 0 {
                    if x - start > best { best = x - start; left = start; right = x - 1 }
                    start = -1
                }
                x += 1
            }
            if start >= 0 && w - start > best { best = w - start; left = start; right = w - 1 }
        }
        if best < w / 3 { left = 0; right = w - 1 }

        // 卡片区域
        var x0 = left, x1 = right, y0 = top, y1 = bottom

        // 非白内容外接框（在卡片内）
        var cx0 = x1, cx1 = x0, cy0 = y1, cy1 = y0
        var found = false
        var ry = y0
        while ry <= y1 {
            var rx = x0
            while rx <= x1 {
                let o = ry * bpr + rx * bpp
                if buffer[o] < 245 || buffer[o + 1] < 245 || buffer[o + 2] < 245 {
                    if rx < cx0 { cx0 = rx }
                    if rx > cx1 { cx1 = rx }
                    if ry < cy0 { cy0 = ry }
                    if ry > cy1 { cy1 = ry }
                    found = true
                }
                rx += 1
            }
            ry += 1
        }
        if found {
            let pad = 24
            x0 = max(x0, cx0 - pad)
            x1 = min(x1, cx1 + pad)
            y0 = max(y0, cy0 - pad)
            y1 = min(y1, cy1 + pad)
        }

        // 去掉底部孤立页码行
        let cardH = y1 - y0 + 1
        if cardH > 100 {
            var blocks: [(Int, Int)] = []
            var inBlock = false
            var startRow = 0
            var ry2 = y0
            while ry2 <= y1 {
                var hasContent = false
                var rx2 = x0
                while rx2 <= x1 {
                    let o = ry2 * bpr + rx2 * bpp
                    if buffer[o] < 245 || buffer[o + 1] < 245 || buffer[o + 2] < 245 {
                        hasContent = true
                        break
                    }
                    rx2 += 1
                }
                if hasContent && !inBlock {
                    inBlock = true
                    startRow = ry2
                } else if !hasContent && inBlock {
                    inBlock = false
                    blocks.append((startRow, ry2 - 1))
                }
                ry2 += 1
            }
            if inBlock { blocks.append((startRow, y1)) }

            if blocks.count >= 2 {
                let last = blocks[blocks.count - 1]
                let prev = blocks[blocks.count - 2]
                let gap = last.0 - prev.1
                let lastH = last.1 - last.0 + 1
                if Double(gap) > Double(cardH) * 0.06 &&
                    Double(lastH) < Double(cardH) * 0.05 &&
                    last.0 > y0 + Int(Double(cardH) * 0.8) {
                    y1 = min(y1, prev.1 + 12)
                }
            }
        }

        let rect = CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }
}
