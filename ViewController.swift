//
//  ViewController.swift
//  R2D2
//
//  Created by Charlie Barber on 6/2/21.
//

import UIKit
import MetalKit

class ViewController: UIViewController {

    var metalView: MTKView!
    var r2Renderer: R2Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("No GPU available")
        }
        
        metalView = MTKView()
        metalView.device = device
        view.addSubview(metalView)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        metalView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        
        r2Renderer = R2Renderer(metalView, and: device)
        metalView.delegate = r2Renderer
    }
}

