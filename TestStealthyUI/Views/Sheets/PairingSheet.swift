//
//  PairingSheet.swift
//  TestStealthyUI
//
//  Migrated from StealthyAI-macOS
//

#if os(macOS)
import SwiftUI
import Combine
import AppKit

struct PairingSheet: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var currentTime = Date()
    @State private var showCopiedFeedback = false
    @State private var qrCodeID = UUID()

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 28) {
            // Header
            Text("Pair with iPhone")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundStyle(.primary)

            Text("Scan the QR codes below to install the app and pair your iPhone")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 48) {
                // QR #1: iOS app link
                VStack(spacing: 16) {
                    QRCodeView(
                        text: "https://example.com/stealthyai-ios",
                        size: installQRSize
                    )
                    .frame(width: installQRSize, height: installQRSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .accessibilityLabel("Install App QR code")

                    VStack(spacing: 6) {
                        Text("1. Install App")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(.primary)
                        Text("Scan to download")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: installQRSize, alignment: .center)

                // QR #2: Pairing token
                VStack(spacing: 16) {
                        // Ring geometry: strokeBorder draws fully inside the shape bounds
                        let outerSize: CGFloat = pairingContainerSize
                        let ringStrokeWidth: CGFloat = ringLineWidth
                        let outerRadius: CGFloat = cornerRadius
                        let innerSize = outerSize - 2 * ringStrokeWidth
                        let innerRadius = max(0, outerRadius - ringStrokeWidth)

                        ZStack(alignment: .center) {
                            // Background rounded-square ring (drawn inside bounds)
                            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: ringStrokeWidth)
                                .frame(width: outerSize, height: outerSize)

                            // Progress rounded-square ring (drawn inside bounds)
                            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                                .trim(from: 0, to: progressFraction)
                                .stroke(isTokenExpired ? Color.red : Color.accentColor,
                                        style: StrokeStyle(lineWidth: ringStrokeWidth, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: outerSize, height: outerSize)
                                .animation(.linear(duration: 0.3), value: progressFraction)
                                .opacity(isTokenExpired ? 0.6 : 1.0)

                            // QR fills the ring's inner area exactly; pixel-snapped to avoid halo
                            // innerSize = outerSize - 2*ringStrokeWidth ensures no gap
                            // innerRadius = outerRadius - ringStrokeWidth matches inner curvature
                            if let deepLink = viewModel.pairingDeepLink {
                                QRCodeView(
                                    text: deepLink.absoluteString,
                                    size: floor(innerSize)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                                .padding(0)
                                .frame(width: floor(innerSize), height: floor(innerSize))
                                .allowsHitTesting(false)
                                .id(qrCodeID)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.25), value: qrCodeID)
                                .accessibilityLabel(isTokenExpired ? "Pairing token QR expired" : "Pairing token QR, expires in \(timeRemaining)")
                            } else {
                                QRCodeView(
                                    text: "stealthyai://pair/\(viewModel.pairingToken.uuidString)",
                                    size: floor(innerSize)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                                .padding(0)
                                .frame(width: floor(innerSize), height: floor(innerSize))
                                .allowsHitTesting(false)
                                .id(qrCodeID)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.25), value: qrCodeID)
                                .accessibilityLabel(isTokenExpired ? "Pairing token QR expired" : "Pairing token QR, expires in \(timeRemaining)")
                            }
                        }
                        .frame(width: outerSize, height: outerSize)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)

                        VStack(spacing: 6) {
                            Text("2. Pair Device")
                                .font(.system(size: 15, weight: .semibold, design: .default))
                                .foregroundStyle(.primary)

                            if isTokenExpired {
                                Text("Expired")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundStyle(.red)
                                    .transition(.opacity)
                            } else {
                                Text("Expires in \(timeRemaining)")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isTokenExpired)
                    }
                    .frame(width: pairingContainerSize, alignment: .center)
                }
            .frame(maxWidth: .infinity, alignment: .center)

            // Debug token string
            VStack(spacing: 6) {
                Text("Pairing Token:")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(.tertiary)
                Text(viewModel.pairingToken.uuidString)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(isTokenExpired ? .tertiary : .secondary)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.2), value: isTokenExpired)

            // Actions
            HStack(spacing: 12) {
                Button(showCopiedFeedback ? "Copied!" : "Copy Token") {
                    if let deepLink = viewModel.pairingDeepLink {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(deepLink.absoluteString, forType: .string)
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedFeedback = false
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isTokenExpired)
                .animation(.easeInOut(duration: 0.15), value: showCopiedFeedback)

                Button("Regenerate Token") {
                    qrCodeID = UUID()
                    viewModel.regeneratePairingToken()
                }
                .buttonStyle(.bordered)
                .disabled(currentTime < viewModel.pairingRegenerateDisabledUntil)

                Button("Done") {
                    viewModel.closePairingSheet()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40)
        .padding(.vertical, 36)
        .frame(width: 640)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    private var isTokenExpired: Bool {
        currentTime >= viewModel.pairingTokenExpiresAt
    }

    private var cornerRadius: CGFloat { 8 }
    private var ringLineWidth: CGFloat { 8 }
    private var installQRSize: CGFloat { 180 }

    // Pair Device ring must match Install QR outer size exactly
    private var pairingContainerSize: CGFloat { installQRSize }

    private var progressFraction: CGFloat {
        let total: TimeInterval = 90
        let remaining = max(0, viewModel.pairingTokenExpiresAt.timeIntervalSince(currentTime))
        return CGFloat(remaining / total)
    }

    private var timeRemaining: String {
        let seconds = Int(max(0, viewModel.pairingTokenExpiresAt.timeIntervalSince(currentTime)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
#endif
