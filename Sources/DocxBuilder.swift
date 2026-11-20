import UIKit

/// 把若干张图片拼成一个 A4 Word 文档（每页一张图，按页宽等比缩放）。
enum DocxBuilder {

    private static let contentWidthEMU = 5731510  // ≈15.9cm

    static func build(images: [UIImage]) -> Data {
        let W = contentWidthEMU
        var body = ""
        var rels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        var media: [ZipEntry] = []

        for (i, img) in images.enumerated() {
            let idx = i + 1
            guard let jpeg = img.jpegData(compressionQuality: 0.92) else { continue }
            let w = max(img.size.width, 1)
            let h = max(img.size.height, 1)
            let cy = Int(Double(W) * Double(h) / Double(w))
            let rid = "rId\(idx)"

            rels += "<Relationship Id=\"\(rid)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image\(idx).jpg\"/>"

            body += "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr><w:r><w:drawing>"
                + "<wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">"
                + "<wp:extent cx=\"\(W)\" cy=\"\(cy)\"/>"
                + "<wp:docPr id=\"\(idx)\" name=\"P\(idx)\"/>"
                + "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">"
                + "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
                + "<pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
                + "<pic:nvPicPr><pic:cNvPr id=\"\(idx)\" name=\"image\(idx).jpg\"/><pic:cNvPicPr/></pic:nvPicPr>"
                + "<pic:blipFill><a:blip r:embed=\"\(rid)\"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>"
                + "<pic:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"\(W)\" cy=\"\(cy)\"/></a:xfrm>"
                + "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></pic:spPr>"
                + "</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>"

            if i < images.count - 1 {
                body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
            media.append(ZipEntry(name: "word/media/image\(idx).jpg", data: jpeg))
        }

        rels += "</Relationships>"

        let doc = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
            + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
            + "xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" "
            + "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" "
            + "xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
            + "<w:body>\(body)"
            + "<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/>"
            + "<w:pgMar w:top=\"720\" w:right=\"720\" w:bottom=\"720\" w:left=\"720\" w:header=\"0\" w:footer=\"0\" w:gutter=\"0\"/>"
            + "</w:sectPr></w:body></w:document>"

        let contentTypes = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
            + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
            + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
            + "<Default Extension=\"jpg\" ContentType=\"image/jpeg\"/>"
            + "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>"
            + "</Types>"

        let rootRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
            + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>"
            + "</Relationships>"

        var entries: [ZipEntry] = [
            ZipEntry(name: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            ZipEntry(name: "_rels/.rels", data: Data(rootRels.utf8)),
            ZipEntry(name: "word/document.xml", data: Data(doc.utf8)),
            ZipEntry(name: "word/_rels/document.xml.rels", data: Data(rels.utf8))
        ]
        entries.append(contentsOf: media)
        return ZipWriter.make(entries)
    }
}
