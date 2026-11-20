import SwiftUI
import UIKit

struct CropItem: Identifiable {
    let id = UUID()
    let preview: UIImage
    let cropped: UIImage
    let info: String
}

struct ContentView: View {
    @State private var originals: [UIImage] = []
    @State private var items: [CropItem] = []
    @State private var showPicker = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var status = "选几张截图，用四个滑块框住题目区"

    // 四个百分比
    @State private var topPct: Double = 0.15
    @State private var bottomPct: Double = 0.70
    @State private var leftPct: Double = 0.08
    @State private var rightPct: Double = 0.92

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                content
                sliders
                bottomBar
            }
            .navigationTitle(versionText)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPicker) {
                PhotoPicker { imgs in
                    guard !imgs.isEmpty else { return }
                    originals = imgs
                    rebuild()
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    private var versionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "错题卷 v\(v)(\(b))"
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            VStack(spacing: 0) {
                Spacer()
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.6))
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(items) { it in
                        VStack(spacing: 4) {
                            Image(uiImage: it.preview)
                                .resizable()
                                .scaledToFit()
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
                            Text(it.info)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    private var sliders: some View {
        VStack(spacing: 2) {
            row("顶部", value: $topPct, range: 0...0.6)
            row("底部", value: $bottomPct, range: 0.2...1.0)
            row("左边", value: $leftPct, range: 0...0.4)
            row("右边", value: $rightPct, range: 0.6...1.0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func row(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Text("\(title) \(Int(value.wrappedValue * 100))%")
                .font(.system(size: 11))
                .frame(width: 68, alignment: .leading)
            Slider(value: value, in: range, step: 0.01) { _ in rebuild() }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                showPicker = true
            } label: {
                Label("选截图", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                makeWord()
            } label: {
                Label("出 Word", systemImage: "doc").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(items.isEmpty)

            Button {
                makePDF()
            } label: {
                Label("出 PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(items.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func rebuild() {
        guard !originals.isEmpty else { return }
        var out: [CropItem] = []
        var lastInfo = ""
        for img in originals {
            let r = Cropper.crop(img,
                                 topPct: topPct,
                                 bottomPct: bottomPct,
                                 leftPct: leftPct,
                                 rightPct: rightPct)
            let pv = Self.drawOverlay(original: img, rect: r.rect)
            out.append(CropItem(preview: pv, cropped: r.image, info: r.info))
            lastInfo = r.info
        }
        items = out
        status = "\(out.count) 页 · \(lastInfo)"
    }

    private func documentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func makeWord() {
        let data = DocxBuilder.build(images: items.map { $0.cropped })
        let url = documentsDir().appendingPathComponent("错题卷.docx")
        do {
            try data.write(to: url, options: .atomic)
            status = "已生成 错题卷.docx（\(items.count) 页）"
            shareItems = [url]
            showShare = true
        } catch {
            status = "写入失败：\(error.localizedDescription)"
        }
    }

    private func makePDF() {
        let data = PdfBuilder.build(images: items.map { $0.cropped })
        let url = documentsDir().appendingPathComponent("错题卷.pdf")
        do {
            try data.write(to: url, options: .atomic)
            status = "已生成 错题卷.pdf（\(items.count) 页）"
            shareItems = [url]
            showShare = true
        } catch {
            status = "写入失败：\(error.localizedDescription)"
        }
    }

    static func drawOverlay(original: UIImage, rect: CGRect) -> UIImage {
        let w = max(original.size.width * original.scale, 1)
        let h = max(original.size.height * original.scale, 1)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        let r = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt)
        return r.image { ctx in
            original.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            let c = ctx.cgContext
            c.setStrokeColor(UIColor.systemRed.cgColor)
            c.setLineWidth(max(4, w / 180))
            c.stroke(rect)
        }
    }
}
