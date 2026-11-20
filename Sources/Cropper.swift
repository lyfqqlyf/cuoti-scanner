import UIKit

/// 自动裁掉截图里不需要的部分（状态栏、标题栏、底部面板），只留白色页面。
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
        // 翻转坐标系，让缓冲区第 0 行对应图片顶部
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        func isWhite(_ x: Int, _ y: Int) -> Bool {
            let o = y * bpr + x * bpp
            return buffer[o] >= 248 && buffer[o + 1] >= 248 && buffer[o + 2] >= 248
        }

        // 1) 垂直方向：在若干列上找最长的连续白色段
        var bestTop = 0
        var bestBottom = h - 1
        var bestLen = 0
        let step = max(1, w / 40)
        var x = max(4, w / 10)
        while x < w - 4 {
            var runStart = -1
            var y = 0
            while y < h {
                if isWhite(x, y) {
                    if runStart < 0 { runStart = y }
                } else if runStart >= 0 {
                    let len = y - runStart
                    if len > bestLen {
                        bestLen = len
                        bestTop = runStart
                        bestBottom = y - 1
                    }
                    runStart = -1
                }
                y += 1
            }
            if runStart >= 0 {
                let len = h - runStart
                if len > bestLen {
                    bestLen = len
                    bestTop = runStart
                    bestBottom = h - 1
                }
            }
            x += step
        }
        guard bestLen > h / 5 else { return image }

        // 2) 水平方向：在页面中段多扫几行，取最长的白色段
        var left = 0
        var right = w - 1
        var bestHLen = 0
        let pageH = bestBottom - bestTop
        var k = 0
        while k < 20 {
            let y = bestTop + pageH * (k + 1) / 21
            var runStart = -1
            var xx = 0
            while xx < w {
                if isWhite(xx, y) {
                    if runStart < 0 { runStart = xx }
                } else if runStart >= 0 {
                    let len = xx - runStart
                    if len > bestHLen {
                        bestHLen = len
                        left = runStart
                        right = xx - 1
                    }
                    runStart = -1
                }
                xx += 1
            }
            if runStart >= 0 {
                let len = w - runStart
                if len > bestHLen {
                    bestHLen = len
                    left = runStart
                    right = w - 1
                }
            }
            k += 1
        }
        guard bestHLen > w / 3 else { return image }

        let rect = CGRect(x: left,
                          y: bestTop,
                          width: right - left + 1,
                          height: bestBottom - bestTop + 1)
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
