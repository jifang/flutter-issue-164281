//
//  FlutterView.swift
//  flutter_add_to_app
//
//  Created by Ji Fang on 3/1/25.
//

import SwiftUI
import Flutter

struct FlutterView: UIViewControllerRepresentable {
    let flutter: FlutterDependencies
    
    func makeUIViewController(context: Context) -> FlutterViewController {
        flutter.flutterEngine.viewController = nil
        let flutterVC = FlutterViewController(engine: flutter.flutterEngine, nibName: nil, bundle: nil)
        return flutterVC
    }
    
    func updateUIViewController(_ uiViewController: FlutterViewController, context: Context) {}
}
