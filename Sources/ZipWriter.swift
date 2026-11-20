import Foundation

struct ZipEntry {
    let name: String
    let data: Data
}

/// 最小 ZIP 写入器（stored，不压缩）。docx 本质就是一个 zip。
enum ZipWriter {

    private static let crcTable: [UInt32] = {
        var t = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            t[i] = c
        }
        return t
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in data {
            crc = crcTable[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }

    static func make(_ entries: [ZipEntry]) -> Data {
        var out = Data()
        var central = Data()

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let year = UInt16(max(1980, comps.year ?? 2024) - 1980)
        let month = UInt16(comps.month ?? 1)
        let day = UInt16(comps.day ?? 1)
        let hour = UInt16(comps.hour ?? 0)
        let minute = UInt16(comps.minute ?? 0)
        let second = UInt16((comps.second ?? 0) / 2)
        let dosTime = (hour << 11) | (minute << 5) | second
        let dosDate = (year << 9) | (month << 5) | day

        for e in entries {
            let nameData = e.name.data(using: .utf8) ?? Data()
            let crc = crc32(e.data)
            let offset = UInt32(out.count)
            let size = UInt32(e.data.count)

            var local = Data()
            local.appendLE(0x04034b50 as UInt32)
            local.appendLE(20 as UInt16)
            local.appendLE(0 as UInt16)
            local.appendLE(0 as UInt16)
            local.appendLE(dosTime)
            local.appendLE(dosDate)
            local.appendLE(crc)
            local.appendLE(size)
            local.appendLE(size)
            local.appendLE(UInt16(nameData.count))
            local.appendLE(0 as UInt16)
            local.append(nameData)
            local.append(e.data)
            out.append(local)

            var c = Data()
            c.appendLE(0x02014b50 as UInt32)
            c.appendLE(20 as UInt16)
            c.appendLE(20 as UInt16)
            c.appendLE(0 as UInt16)
            c.appendLE(0 as UInt16)
            c.appendLE(dosTime)
            c.appendLE(dosDate)
            c.appendLE(crc)
            c.appendLE(size)
            c.appendLE(size)
            c.appendLE(UInt16(nameData.count))
            c.appendLE(0 as UInt16)
            c.appendLE(0 as UInt16)
            c.appendLE(0 as UInt16)
            c.appendLE(0 as UInt16)
            c.appendLE(0 as UInt32)
            c.appendLE(offset)
            c.append(nameData)
            central.append(c)
        }

        let cdOffset = UInt32(out.count)
        out.append(central)

        var eocd = Data()
        eocd.appendLE(0x06054b50 as UInt32)
        eocd.appendLE(0 as UInt16)
        eocd.appendLE(0 as UInt16)
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(UInt32(central.count))
        eocd.appendLE(cdOffset)
        eocd.appendLE(0 as UInt16)
        out.append(eocd)

        return out
    }
}

extension Data {
    mutating func appendLE(_ v: UInt16) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
    }
    mutating func appendLE(_ v: UInt32) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
        append(UInt8((v >> 16) & 0xFF))
        append(UInt8((v >> 24) & 0xFF))
    }
}
