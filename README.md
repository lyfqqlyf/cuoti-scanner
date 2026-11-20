# 错题卷（CuotiScanner）

把手机截图里的**试卷题目**自动裁出来，拼成 A4 的 Word / PDF，直接打印。

专治：截图里带着状态栏、`导出打印` 标题、底部「组卷模式 / 排列方式 / 打印设置」一大块面板，打印出来难看。

## 它做什么

1. 从相册选几张截图（可多选）
2. 自动识别截图里的**白色页面区域**，把页面以外的部分全部裁掉
3. 按 A4 排版生成文件：
   - `错题卷.docx`（Word，可编辑）
   - `错题卷.pdf`（打印最稳）
4. 保存到 App 的 Documents，并弹出系统分享面板 → 可以直接发微信

裁剪是纯像素分析：在页面左侧若干列上找最长的连续纯白段（页面上下边界），再在页面中段找最长的连续纯白段（左右边界）。不依赖任何固定坐标，换机型、换截图比例都能用。

## 编译（GitHub Actions，无需 Mac）

仓库已带 `.github/workflows/build.yml`，push 到 GitHub 后自动编译：

```bash
# 1. 在 GitHub 上新建一个空仓库，比如 cuoti-scanner
# 2. 本地执行（把 URL 换成你的）
git remote add origin https://github.com/<你的账号>/cuoti-scanner.git
git branch -M main
git push -u origin main
```

push 之后：

1. 打开仓库 → **Actions** → `build-ipa`
2. 等 3～5 分钟，绿勾
3. 点进这次运行 → 页面底部 **Artifacts** → 下载 `CuotiScanner-ipa.zip`
4. 解压得到 `CuotiScanner.ipa`

也可以手动触发：Actions → build-ipa → **Run workflow**。

## 安装（iPhone 6sp / iOS 15，已越狱 + TrollStore）

1. 把 `CuotiScanner.ipa` 传到手机（AirDrop / 微信文件传输助手 / 数据线）
2. 用 **TrollStore** 打开它 → Install
3. 桌面出现「错题卷」

> IPA 是未签名 + ldid ad-hoc 签名，TrollStore 直接装。
> 用 Sideloadly 也行，但需要你自己的 Apple ID 重签。

## 用法

1. 打开 App → 点「选截图」→ 从相册选你截好的那几张（一次可多选）
2. 自动裁剪，网格里能预览裁完的效果
3. 点「出 Word」或「出 PDF」
4. 弹出分享面板 → 发微信 / 存文件 / 打印
5. 文件同时留在：**「文件」App → 我的 iPhone → 错题卷**

## 目录结构

```
project.yml                 XcodeGen 工程定义
Info.plist                  App 配置（含 UIFileSharingEnabled）
Sources/
  App.swift                 入口
  ContentView.swift         主界面：选图 / 预览 / 生成
  PhotoPicker.swift         相册多选 + 系统分享面板
  Cropper.swift             白色页面自动裁剪
  DocxBuilder.swift         docx 组装（document.xml + media）
  ZipWriter.swift           最小 ZIP 写入器（stored + CRC32）
  PdfBuilder.swift          A4 PDF 渲染
.github/workflows/build.yml 自动编译出 IPA
```

## 已知限制

- 裁剪基于「白色页面」假设：截图里的试卷页必须是白底。深色模式截图会裁不准。
- docx 里每页是一张整图，文字不可编辑（要可编辑的 Word 得走 OCR，那是另一件事）。
- 生成的 docx 用 Word / WPS 打开正常；Pages 也支持。
