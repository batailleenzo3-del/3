//
//  SignatureViews.swift
//  Signer un document : dessiner sa signature (enregistrée pour la prochaine fois),
//  choisir la page, la placer et l'agrandir avec le doigt.
//

import SwiftUI
import Combine
import UIKit

struct SignFlow: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DocumentStore
    let docID: UUID

    @State private var drawing = false
    @State private var pageIndex = 0
    @State private var center = CGPoint(x: 0.68, y: 0.86)
    @State private var widthRatio: CGFloat = 0.34
    @State private var pinchStart: CGFloat?
    @State private var blueInk = false
    @State private var working = false

    var body: some View {
        NavigationStack {
            Group {
                if drawing || store.signature == nil {
                    SignaturePad { image in
                        store.saveSignature(image)
                        drawing = false
                    }
                } else if let doc = store.document(docID), let signature = store.signature {
                    placement(doc, signature: signature)
                }
            }
            .background { AppBackground() }
            .navigationTitle(drawing || store.signature == nil ? loc("sign_draw_title") : loc("sign_place_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("cancel")) {
                        if drawing && store.signature != nil { drawing = false } else { dismiss() }
                    }
                }
                if !drawing, store.signature != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(loc("sign_apply")) { Task { await apply() } }
                            .fontWeight(.bold)
                            .disabled(working)
                    }
                }
            }
        }
    }

    private func inked(_ signature: UIImage) -> UIImage {
        signature.withTintColor(blueInk ? UIColor(red: 0.05, green: 0.2, blue: 0.65, alpha: 1) : .black,
                                renderingMode: .alwaysOriginal)
    }

    // MARK: Placement

    private func placement(_ doc: ScanDocument, signature: UIImage) -> some View {
        let safeIndex = min(pageIndex, max(0, doc.pages.count - 1))
        let page = doc.pages.isEmpty ? nil : doc.pages[safeIndex]
        let image = page.flatMap { store.image(doc.id, $0.file) }
        let pageAspect = image.map { $0.size.width / max(1, $0.size.height) } ?? 0.707
        let sigAspect = signature.size.height / max(1, signature.size.width)

        return VStack(spacing: 14) {
            if doc.pages.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(doc.pages.enumerated()), id: \.element.id) { index, item in
                            Button {
                                pageIndex = index
                                Haptics.tap()
                            } label: {
                                PageThumbnail(store: store, docID: doc.id, file: item.file, cornerRadius: 6)
                                    .frame(width: 44, height: 58)
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(index == safeIndex ? theme.primary : .clear, lineWidth: 2.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            ZStack {
                if let image {
                    Image(uiImage: image).resizable()
                } else {
                    Rectangle().fill(.white)
                }
                GeometryReader { geo in
                    let size = geo.size
                    let width = size.width * widthRatio
                    Image(uiImage: inked(signature))
                        .resizable()
                        .frame(width: width, height: width * sigAspect)
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.primary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        .position(x: center.x * size.width, y: center.y * size.height)
                        .frame(width: size.width, height: size.height)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    center = CGPoint(x: min(1, max(0, value.location.x / max(1, size.width))),
                                                     y: min(1, max(0, value.location.y / max(1, size.height))))
                                }
                        )
                        .simultaneousGesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    let start = pinchStart ?? widthRatio
                                    pinchStart = start
                                    widthRatio = min(0.9, max(0.08, start * value.magnification))
                                }
                                .onEnded { _ in pinchStart = nil }
                        )
                }
            }
            .aspectRatio(pageAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "textformat.size.smaller")
                    Slider(value: $widthRatio, in: 0.08...0.9)
                    Image(systemName: "textformat.size.larger")
                }
                .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Picker(loc("sign_ink"), selection: $blueInk) {
                        Text(loc("ink_black")).tag(false)
                        Text(loc("ink_blue")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    Button {
                        drawing = true
                    } label: {
                        Label(loc("sign_new"), systemImage: "pencil.and.scribble")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                Text(loc("sign_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .overlay {
            if working { ProgressView().controlSize(.large) }
        }
    }

    private func apply() async {
        guard let doc = store.document(docID), !doc.pages.isEmpty, let signature = store.signature else { return }
        let page = doc.pages[min(pageIndex, doc.pages.count - 1)]
        guard let image = store.image(doc.id, page.file) else { return }
        let pageSize = image.size
        let sigAspect = signature.size.height / max(1, signature.size.width)
        let w = widthRatio
        let h = (w * pageSize.width * sigAspect) / max(1, pageSize.height)
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        working = true
        await store.sign(docID, pageID: page.id, signature: inked(signature), rect: rect)
        working = false
        Haptics.success()
        dismiss()
    }
}

// MARK: - Dessiner sa signature

struct SignaturePad: View {
    @Environment(\.appTheme) private var theme
    let onSave: (UIImage) -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    @State private var padSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 18) {
            Text(loc("sign_draw_hint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            GeometryReader { geo in
                Canvas { context, _ in
                    for stroke in strokes + [current] {
                        context.stroke(Self.path(stroke), with: .color(.black),
                                       style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    }
                }
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.35))
                        .frame(height: 1)
                        .padding(.horizontal, 30)
                        .padding(.bottom, geo.size.height * 0.28)
                        .allowsHitTesting(false)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in current.append(value.location) }
                        .onEnded { _ in
                            if !current.isEmpty { strokes.append(current) }
                            current = []
                        }
                )
                .onAppear { padSize = geo.size }
                .onChange(of: geo.size) { _, size in padSize = size }
            }
            .frame(height: 260)

            HStack(spacing: 12) {
                Button {
                    strokes = []
                    current = []
                } label: {
                    GlassButtonLabel(title: loc("clear"), icon: "eraser")
                }
                .buttonStyle(.plain)
                Button {
                    if let image = render() { onSave(image) }
                } label: {
                    PrimaryButtonLabel(title: loc("save"), icon: "checkmark")
                }
                .buttonStyle(.plain)
                .disabled(strokes.isEmpty)
                .opacity(strokes.isEmpty ? 0.5 : 1)
            }
            Label(loc("sign_private"), systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    private static func path(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 1 {
            path.addLine(to: CGPoint(x: first.x + 0.5, y: first.y + 0.5))
            return path
        }
        for index in 1..<points.count {
            let mid = CGPoint(x: (points[index - 1].x + points[index].x) / 2,
                              y: (points[index - 1].y + points[index].y) / 2)
            path.addQuadCurve(to: mid, control: points[index - 1])
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }

    /// Image transparente, recadrée autour du tracé, en haute définition.
    private func render() -> UIImage? {
        let all = strokes.flatMap { $0 }
        guard let minX = all.map(\.x).min(), let maxX = all.map(\.x).max(),
              let minY = all.map(\.y).min(), let maxY = all.map(\.y).max() else { return nil }
        let margin: CGFloat = 8
        let box = CGRect(x: minX - margin, y: minY - margin,
                         width: max(20, maxX - minX + margin * 2), height: max(12, maxY - minY + margin * 2))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 4
        format.opaque = false
        return UIGraphicsImageRenderer(size: box.size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: -box.minX, y: -box.minY)
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineWidth(3.2)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for stroke in strokes {
                cg.addPath(Self.path(stroke).cgPath)
                cg.strokePath()
            }
        }
    }
}
