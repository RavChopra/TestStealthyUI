//
//  QRCodeView.swift
//  StealthyAI-macOS
//
//  Created by Claude on 2025-09-30.
//

#if os(macOS)
import SwiftUI
import CoreImage.CIFilterBuiltins
import AppKit

struct QRCodeView: View {
    let text: String
    let size: CGFloat

    var body: some View {
        Group {
            if let qrImage = generateQRCode(from: text) {
                // Unified rendering for both light and dark mode
                // - interpolation(.none): crisp pixels, no smoothing
                // - antialiased(false): avoid 1px halo around edges
                // - renderingMode(.original): prevent system recoloring
                // - background(Color.clear): no implicit white/black background
                // - compositingGroup(): clean compositing, helps eliminate halo issues
                // - floor(size): pixel-snap to avoid subpixel rendering artifacts
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .antialiased(false)
                    .resizable()
                    .renderingMode(.original)
                    .background(Color.clear)
                    .compositingGroup()
                    .scaledToFit()
                    .frame(width: floor(size), height: floor(size))
            } else {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Text("QR Error")
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else {
            return nil
        }

        filter.message = data
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else {
            return nil
        }

        // Scale up for crisp rendering using integer scale to avoid interpolation blur
        // Integer scaling (10x) ensures clean pixel boundaries
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
#endif
