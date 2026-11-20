import UIKit

/// 把图片排成 A4 PDF，每页一张，等比缩放居中。
enum PdfBuilder {

    static func build(images: [UIImage]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let inset: CGFloat = 16
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            for img in images {
                ctx.beginPage()
                let avail = pageRect.insetBy(dx: inset, dy: inset)
                let sw = max(img.size.width, 1)
                let sh = max(img.size.height, 1)
                let scale = min(avail.width / sw, avail.height / sh)
                let w = sw * scale
                let h = sh * scale
                let rect = CGRect(x: (pageRect.width - w) / 2,
                                  y: (pageRect.height - h) / 2,
                                  width: w, height: h)
                img.draw(in: rect)
            }
        }
    }
}
