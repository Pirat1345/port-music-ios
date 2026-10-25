//
//  NPMetalBackdropView.swift
//  octave
//

import SwiftUI
import MetalKit

struct NPMetalBackdropView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.05, blue: 0.15, alpha: 1.0)
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
