import SwiftUI
import UIKit

struct ContentView: View {
    @State private var cropped: [UIImage] = []
    @State private var showPicker = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var status = "选几张截图，自动裁掉状态栏和底部按钮"

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                content
                bottomBar
            }
            .navigationTitle("错题卷")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPicker) {
                PhotoPicker { imgs in
                    guard !imgs.isEmpty else { return }
                    var out: [UIImage] = []
                    var detail = ""
                    for img in imgs {
                        let r = Cropper.cropPage(img)
                        out.append(r.0)
                        if detail.isEmpty { detail = r.1 }
                    }
                    cropped = out
                    status = "已裁剪 \(out.count) 页：\(detail)"
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    @ViewBuilder
    private var content: some View {
        if cropped.isEmpty {
            VStack(spacing: 0) {
                Spacer()
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.6))
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 14)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(Array(cropped.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.35))
                                )
                        }
                    }
                    .padding(12)
                }
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                showPicker = true
            } label: {
                Label("选截图", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                makeWord()
            } label: {
                Label("出 Word", systemImage: "doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(cropped.isEmpty)

            Button {
                makePDF()
            } label: {
                Label("出 PDF", systemImage: "doc.richtext")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(cropped.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func documentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func makeWord() {
        let data = DocxBuilder.build(images: cropped)
        let url = documentsDir().appendingPathComponent("错题卷.docx")
        do {
            try data.write(to: url, options: .atomic)
            status = "已生成 错题卷.docx（\(cropped.count) 页，\(data.count / 1024) KB）"
            shareItems = [url]
            showShare = true
        } catch {
            status = "写入失败：\(error.localizedDescription)"
        }
    }

    private func makePDF() {
        let data = PdfBuilder.build(images: cropped)
        let url = documentsDir().appendingPathComponent("错题卷.pdf")
        do {
            try data.write(to: url, options: .atomic)
            status = "已生成 错题卷.pdf（\(cropped.count) 页，\(data.count / 1024) KB）"
            shareItems = [url]
            showShare = true
        } catch {
            status = "写入失败：\(error.localizedDescription)"
        }
    }
}
