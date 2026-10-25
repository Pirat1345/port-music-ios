//
//  NPBackdropRenderer.swift
//  octave
//

import Foundation
import Metal

final class NPBackdropRenderer {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?

    init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
    }
}
