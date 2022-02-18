//
//  LazyView.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 2/14/22.
//  With credit to Chris Eidhof:
//  https://gist.github.com/chriseidhof/d2fcafb53843df343fe07f3c0dac41d5
//

import SwiftUI

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
