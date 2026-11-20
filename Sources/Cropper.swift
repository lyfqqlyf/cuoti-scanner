import UIKit

/// 裁剪：自动检测 + 手动百分比两种模式
enum Cropper {

    struct Result {
        let image: UIImage
        let rect: CGRect
        let info: String
    }

    // MARK: - 手动百分比裁剪（最可靠）

    static func cropManual(_ image: UIImage, topPct: Double, bottomPct: Double) -> Result {
        guard let cgImg = image.cgImage else {
            return Result(image: image, rect: .zero, info: "无 CGImage")
        }
        let w = cgImg.width
        let h = cgImg.height
        let y0 = Int(Double(h) * max(0, min(0.9, topPct)))
        let y1 = Int(Double(h) * max(topPct + 0.05, min(1.0, bottomPct)))
        let rect = CGRect(x: 0, y: y0, width: w, height: max(1, y1 - y0))
        guard let c = cgImg.cropping(to: rect) else {
            return Result(image: image, rect: .zero, info: "裁剪失败")
        }
        return Result(image: UIImage(cgImage: c, scale: 1, orientation: .up),
                      rect: rect,
                      info: "手动 \(Int(topPct * 100))%~\(Int(bottomPct * 100))% → \(Int(rect.width))x\(Int(rect.height))")
    }

    // MARK: - 自动检测

    static func cropAuto(_ image: UIImage) -> Result {
        var cg = image.cgImage
        if cg == nil {
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.scale = 1
            let r = UIGraphicsImageRenderer(size: image.size, format: fmt)
            let rendered = r.image { _ in image.draw(at: .zero) }
            cg = rendered.cgImage
        }
        guard let cgImg = cg else {
            return Result(image: image, rect: .zero, info: "无 CGImage")
        }

        let w = cgImg.width
        let h = cgImg.height
        guard w > 60, h > 60 else {
            return Result(image: image, rect: CGRect(x: 0, y: 0, width: w, height: h), info: "图太小")
        }

        let bpp = 4
        let bpr = w * bpp
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: h * bpr)
        buffer.initialize(repeating: 0, count: h * bpr)
        defer { buffer.deallocate() }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: buffer, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: bpr, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return Result(image: image, rect: CGRect(x: 0, y: 0, width: w, height: h), info: "建位图失败")
        }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))

        func isWhite(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] >= 246 && buffer[o + 1] >= 246 && buffer[o + 2] >= 246
        }
        func isDark(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] < 200 || buffer[o + 1] < 200 || buffer[o + 2] < 200
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

        // 找最长的白行段（页面卡片）
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
        merged = merged.filter { $0.1 - $0.0 >= Int(Double(h) * 0.15) }

        guard let band = merged.max(by: { ($0.1 - $0.0) < ($1.1 - $1.0) }) else {
            return Result(image: image, rect: CGRect(x: 0, y: 0, width: w, height: h), info: "找不到白色页")
        }

        // 卡片内找第一行和最后一行深色内容
        var firstDark = -1
        var lastDark = -1
        for y in band.0...band.1 {
            var has = false
            var x = 0
            while x < w {
                if isDark(x, y) { has = true; break }
                x += 1
            }
            if has {
                if firstDark < 0 { firstDark = y }
                lastDark = y
            }
        }
        if firstDark < 0 || lastDark < 0 {
            return Result(image: image, rect: CGRect(x: 0, y: band.0, width: w, height: band.1 - band.0 + 1), info: "无深色内容")
        }

        // 最后一块内容如果孤立在底部（页码），去掉它
        var blocks: [(Int, Int)] = []
        var inBlock = false
        var sRow = 0
        for y in band.0...band.1 {
            var has = false
            var x = 0
            while x < w {
                if isDark(x, y) { has = true; break }
                x += 1
            }
            if has && !inBlock { inBlock = true; sRow = y }
            else if !has && inBlock { inBlock = false; blocks.append((sRow, y - 1)) }
        }
        if inBlock { blocks.append((sRow, band.1)) }

        var bottomLimit = lastDark
        if blocks.count >= 2 {
            let lastB = blocks[blocks.count - 1]
            let prevB = blocks[blocks.count - 2]
            let gap = lastB.0 - prevB.1
            let lastH = lastB.1 - lastB.0 + 1
            let bandH = band.1 - band.0 + 1
            if gap > Int(Double(bandH) * 0.05) && lastH < Int(Double(bandH) * 0.06) {
                bottomLimit = prevB.1
            }
        }

        let pad = 24
        let y0 = max(band.0, firstDark - pad)
        let y1 = min(band.1, bottomLimit + pad)
        let rect = CGRect(x: 0, y: y0, width: w, height: max(1, y1 - y0))
        guard let c = cgImg.cropping(to: rect) else {
            return Result(image: image, rect: CGRect(x: 0, y: 0, width: w, height: h), info: "裁剪失败")
        }
        return Result(image: UIImage(cgImage: c, scale: 1, orientation: .up),
                      rect: rect,
                      info: "自动 → \(Int(rect.minY))~\(Int(rect.maxY)) = \(Int(rect.width))x\(Int(rect.height))")
    }
}
