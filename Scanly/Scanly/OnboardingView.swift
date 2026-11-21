//
//  OnboardingView.swift
//  Tutoriel du premier lancement (4 pages).
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.appTheme) private var theme
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let icon: String
        let color: Color
        let titleKey: String
        let textKey: String
    }

    private let pages: [Page] = [
        Page(icon: "doc.viewfinder", color: .blue, titleKey: "onb1_title", textKey: "onb1_text"),
        Page(icon: "text.magnifyingglass", color: .purple, titleKey: "onb2_title", textKey: "onb2_text"),
        Page(icon: "signature", color: .orange, titleKey: "onb3_title", textKey: "onb3_text"),
        Page(icon: "lock.shield.fill", color: .green, titleKey: "onb4_title", textKey: "onb4_text")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button(loc("skip")) { onFinish() }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
            }
            .frame(height: 44)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation(.snappy) { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                PrimaryButtonLabel(title: page < pages.count - 1 ? loc("next") : loc("start"))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .frame(maxWidth: 520)
        }
    }

    private func pageView(_ item: Page, index: Int) -> some View {
        VStack(spacing: 26) {
            Spacer()
            if index == 0 {
                demoCard
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(item.color)
                    .frame(width: 150, height: 150)
                    .glassBackground(in: Circle())
            }
            VStack(spacing: 12) {
                Text(loc(item.titleKey))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(loc(item.textKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: 560)
    }

    /// Mini animation : une feuille scannée, avec le cadre de détection qui « respire ».
    private var demoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
                .frame(width: 170, height: 230)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 9) {
                        Capsule().fill(Color.black.opacity(0.75)).frame(width: 90, height: 9)
                        ForEach(0..<7, id: \.self) { row in
                            Capsule().fill(Color.gray.opacity(0.45))
                                .frame(width: row % 3 == 2 ? 80 : 130, height: 6)
                        }
                        Spacer()
                        Capsule().fill(theme.primary.opacity(0.8)).frame(width: 60, height: 8)
                    }
                    .padding(18)
                }
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.diagonalGradient, style: StrokeStyle(lineWidth: 4, dash: [26, 10]))
                .frame(width: 196, height: 256)
                .phaseAnimator([false, true]) { content, on in
                    content.scaleEffect(on ? 1.04 : 0.97).opacity(on ? 1 : 0.7)
                } animation: { _ in
                    .easeInOut(duration: 1.1)
                }
        }
        .frame(width: 260, height: 290)
        .glassBackground(in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}
