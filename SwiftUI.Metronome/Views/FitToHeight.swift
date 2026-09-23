//
//  FitToHeight.swift
//  SwiftUI.Metronome
//
//  Measures its content's natural height and scales it down just enough
//  to fit the available space, so the screen never needs to scroll —
//  on any iPhone or iPad, in any orientation.
//

import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FitToHeight<Content: View>: View {
    @State private var measuredHeight: CGFloat = 0
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let scale = measuredHeight > 0 ? min(1, geo.size.height / measuredHeight) : 1
            let fits = scale >= 0.999

            content
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { inner in
                        Color.clear.preference(key: ContentHeightKey.self, value: inner.size.height)
                    }
                )
                .scaleEffect(scale, anchor: .top)
                .frame(width: geo.size.width, height: geo.size.height, alignment: fits ? .center : .top)
        }
        .onPreferenceChange(ContentHeightKey.self) { measuredHeight = $0 }
    }
}
