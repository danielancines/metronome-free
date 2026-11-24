//
//  FitToHeight.swift
//  SwiftUI.Metronome
//
//  Measures its content's natural height and scales it down just enough to
//  fit the available space, so the screen never needs to scroll and adapts
//  whenever components are added or removed.
//

import SwiftUI

struct FitToHeight<Content: View>: View {
    @State private var naturalHeight: CGFloat = 0
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let scale = naturalHeight > 0 ? min(1, geo.size.height / naturalHeight) : 1
            let scaledHeight = naturalHeight * scale
            content
                // Lay out wider by 1/scale so that, once scaled down, the content
                // still spans the full width: only the height is adjusted.
                .frame(width: geo.size.width / scale)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
                .scaleEffect(scale, anchor: .top)
                // Pin to the top, then center vertically when there's spare room.
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .offset(y: max(0, (geo.size.height - scaledHeight) / 2))
        }
    }
}
