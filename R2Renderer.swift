//
//  R2Renderer.swift
//  R2D2
//
//  Created by Charlie Barber on 6/22/21.
//

import MetalKit
import simd

struct Uniforms {
    var modelMatrix: float4x4
    var viewProjectionMatrix: float4x4
    var normalMatrix: float3x3
    
}

class R2Renderer: NSObject, MTKViewDelegate {
    
    var viewPortSize: SIMD2<UInt32>?
    let metalView: MTKView
    let device: MTLDevice
    var pipelineState: MTLRenderPipelineState?
    var mdlMesh: [MDLMesh] = []
    var mtkMesh: [MTKMesh] = []
    var depthStencilState: MTLDepthStencilState?
    var commandQueue: MTLCommandQueue
    var texture: MTLTexture?
    
    init(_ metalView: MTKView, and device: MTLDevice) {
        self.metalView = metalView
        self.device = device
        
        self.commandQueue = device.makeCommandQueue()!
        
        let mdlVertexDescriptor = MDLVertexDescriptor()
        mdlVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        mdlVertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
        mdlVertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size * 6, bufferIndex: 0)
        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        
        guard let library = device.makeDefaultLibrary() else {
            return
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        descriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mdlVertexDescriptor)
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Could not create pipeline state \(error)")
        }
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        
        let url = Bundle.main.url(forResource: "R2", withExtension: "obj")
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlAsset = MDLAsset(url: url, vertexDescriptor: mdlVertexDescriptor, bufferAllocator: allocator)
        
        let (mdlMesh, mtkMesh) = try! MTKMesh.newMeshes(asset: mdlAsset, device: device)
        
        self.mdlMesh = mdlMesh
        self.mtkMesh = mtkMesh
        
        let textureLoader = MTKTextureLoader(device: self.device)
        guard let textureURL = Bundle.main.url(forResource: "R2Texture", withExtension: "png") else {
            fatalError("Could not find texture url")
        }
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft, .SRGB: false ]
        do {
            self.texture = try textureLoader.newTexture(URL: textureURL, options: options)
        } catch {
            fatalError("Could not load texture")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewPortSize = SIMD2<UInt32>()
        viewPortSize?.x = UInt32(size.width)
        viewPortSize?.y = UInt32(size.height)

    }
    
    func draw(in view: MTKView) {

        let commandBuffer = commandQueue.makeCommandBuffer()!

        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture

            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            commandEncoder?.setDepthStencilState(depthStencilState)

            let modelMatrix = float4x4(scaleBy: 1)
            let viewMatrix = float4x4(translateBy: SIMD3<Float>(0, 0, -25))
            let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
            let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
            let viewProjectionMatrix = projectionMatrix * viewMatrix
            let normalMatrix = modelMatrix.normalMatrix
            var uniforms = Uniforms(modelMatrix: modelMatrix, viewProjectionMatrix: viewProjectionMatrix, normalMatrix: normalMatrix)
            commandEncoder?.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            commandEncoder?.setFragmentTexture(texture, index: 0)

            commandEncoder?.setRenderPipelineState(pipelineState!)

            for mesh in mtkMesh {
                let vertexBuffer = mesh.vertexBuffers.first!
                commandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)

                for submesh in mesh.submeshes {
                    commandEncoder?.drawIndexedPrimitives(
                        type: submesh.primitiveType,
                        indexCount: submesh.indexCount,
                        indexType: submesh.indexType,
                        indexBuffer: submesh.indexBuffer.buffer,
                        indexBufferOffset: submesh.indexBuffer.offset)
                }
            }

            commandEncoder?.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

    }

}
