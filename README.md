# iOS Scanner

A plug-and-play, feature-rich barcode and QR code scanner for iOS applications. Built with Swift and AVFoundation, this scanner provides a modern UI with smooth animations, pinch-to-zoom, and comprehensive error handling.

![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- ✅ **Multiple Barcode Types**: Supports QR, EAN13, EAN8, Code128, Code39, Code93, PDF417, DataMatrix, UPCE, Interleaved2of5, and ITF14
- ✅ **Pinch-to-Zoom**: Intuitive pinch gesture to zoom in/out (1.0x - 5.0x)
- ✅ **Animated Scanning Line**: Visual feedback with smooth scanning animation
- ✅ **Corner Markers**: Clear visual indication of the scanning area
- ✅ **Camera Permission Handling**: Automatic permission requests with error handling
- ✅ **Haptic Feedback**: Success vibration on successful scan
- ✅ **Visual Success Overlay**: Brief flash animation on successful scan
- ✅ **Customizable**: Configure supported barcode types, scanning area, and more
- ✅ **Delegate Pattern**: Clean delegate protocol for handling scanner events
- ✅ **Auto Focus**: Optimized for close-range barcode scanning
- ✅ **Dark Overlay**: Semi-transparent overlay to focus on scanning area

## Requirements

- iOS 13.0+
- Xcode 12.0+
- Swift 5.0+
- Camera access permission

## Installation

### Manual Installation

1. Download the `iOSScannerViewController.swift` file
2. Drag and drop it into your Xcode project
3. Ensure it's added to your target
4. Add camera usage description to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan barcodes and QR codes</string>
```

## Usage

### Basic Usage

```swift
import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    // MARK: - Show Scanner
    
    @IBAction func scanButtonTapped(_ sender: UIButton) {
        let scanner = iOSScannerViewController()
        scanner.delegate = self
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: true)
    }
}

// MARK: - iOSScannerDelegate

extension ViewController: iOSScannerDelegate {
    
    func scannerDidScannedCode(_ scanner: iOSScannerViewController, code: String, type: AVMetadataObject.ObjectType) {
        print("✅ Scanned: \(code)")
        print("📱 Type: \(type.rawValue)")
        
        // Handle the scanned code
        // For example, show an alert or process the data
        scanner.dismiss(animated: true) {
            self.showAlert(title: "Success", message: "Scanned: \(code)")
        }
    }
    
    func scannerDidCancel(_ scanner: iOSScannerViewController) {
        print("❌ Scanner cancelled by user")
        // Handle cancellation
    }
    
    func scannerDidFail(_ scanner: iOSScannerViewController, error: iOSScannerError) {
        print("⚠️ Scanner failed: \(error.localizedDescription)")
        
        // Handle error - show appropriate message to user
        scanner.dismiss(animated: true) {
            self.showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    // Helper method to show alerts
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

### Advanced Usage - Custom Configuration

```swift
class ViewController: UIViewController {
    
    // MARK: - Scan Only QR Codes
    
    func scanQRCodeOnly() {
        let scanner = iOSScannerViewController()
        scanner.delegate = self
        scanner.supportedCodeTypes = [.qr] // Only QR codes
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: true)
    }
    
    // MARK: - Scan Multiple Specific Types
    
    func scanRetailBarcodes() {
        let scanner = iOSScannerViewController()
        scanner.delegate = self
        scanner.supportedCodeTypes = [.ean13, .ean8, .upce] // Retail barcodes only
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: true)
    }
    
    // MARK: - Pause/Resume Scanning
    
    var currentScanner: iOSScannerViewController?
    
    func showScannerWithPauseControl() {
        let scanner = iOSScannerViewController()
        scanner.delegate = self
        scanner.modalPresentationStyle = .fullScreen
        currentScanner = scanner
        present(scanner, animated: true)
    }
    
    func pauseScanning() {
        currentScanner?.isScanning = false
    }
    
    func resumeScanning() {
        currentScanner?.isScanning = true
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI

struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> iOSScannerViewController {
        let scanner = iOSScannerViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: iOSScannerViewController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, iOSScannerDelegate {
        let parent: ScannerView
        
        init(_ parent: ScannerView) {
            self.parent = parent
        }
        
        func scannerDidScannedCode(_ scanner: iOSScannerViewController, code: String, type: AVMetadataObject.ObjectType) {
            parent.scannedCode = code
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func scannerDidCancel(_ scanner: iOSScannerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func scannerDidFail(_ scanner: iOSScannerViewController, error: iOSScannerError) {
            print("Scanner failed: \(error.localizedDescription)")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Usage in SwiftUI
struct ContentView: View {
    @State private var scannedCode: String?
    @State private var showScanner = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let code = scannedCode {
                Text("Scanned: \(code)")
                    .font(.headline)
            }
            
            Button("Scan Code") {
                showScanner = true
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView(scannedCode: $scannedCode)
        }
    }
}
```

## API Documentation

### iOSScannerViewController

Main scanner view controller that handles camera input and barcode detection.

#### Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `delegate` | `iOSScannerDelegate?` | Delegate to receive scanner events | `nil` |
| `isScanning` | `Bool` | Enable/disable scanning (can be used to pause) | `true` |
| `currentZoomFactor` | `CGFloat` | Current zoom factor | `1.0` |
| `supportedCodeTypes` | `[AVMetadataObject.ObjectType]` | Array of supported barcode types | All types |

#### Methods

```swift
func startScanning()
func stopScanning()
```

### iOSScannerDelegate

Protocol to receive scanner events.

```swift
protocol iOSScannerDelegate: AnyObject {
    /// Called when a code is successfully scanned
    func scannerDidScannedCode(_ scanner: iOSScannerViewController, 
                              code: String, 
                              type: AVMetadataObject.ObjectType)
    
    /// Called when scanning is cancelled by the user
    func scannerDidCancel(_ scanner: iOSScannerViewController)
    
    /// Called when scanner fails
    func scannerDidFail(_ scanner: iOSScannerViewController, 
                       error: iOSScannerError)
}
```

### iOSScannerError

Error types that can occur during scanning.

```swift
enum iOSScannerError: Error {
    case cameraUnavailable          // Camera not available on device
    case cameraAccessDenied         // User denied camera permission
    case cameraConfigurationFailed  // Failed to configure camera
    case captureSessionSetupFailed  // Failed to setup capture session
}
```

### Supported Barcode Types

```swift
.qr              // QR Code
.ean13           // EAN-13
.ean8            // EAN-8
.code128         // Code 128
.code39          // Code 39
.code93          // Code 93
.pdf417          // PDF417
.dataMatrix      // Data Matrix
.upce            // UPC-E
.interleaved2of5 // Interleaved 2 of 5
.itf14           // ITF-14
```

## Features in Detail

### 📸 Pinch-to-Zoom

Users can pinch to zoom in (up to 5x) for scanning distant or small barcodes. A zoom indicator appears during pinch gestures.

### 🎯 Scanning Area

The scanner uses a focused scanning area (70% of screen width) with visual corner markers to guide users where to place the barcode.

### ✅ Success Feedback

When a barcode is successfully scanned:
- Scanning stops automatically
- Blue flash overlay animation
- Haptic feedback (vibration)
- Delegate method called with scanned data

### 🎨 UI Elements

- **Title Label**: "Scanner" at the top center
- **Cancel Button**: Top-left corner to dismiss scanner
- **Zoom Label**: Bottom center (appears during zoom)
- **Scanning Line**: Animated blue line moving vertically
- **Corner Markers**: Blue corner indicators on scanning area
- **Dark Overlay**: Semi-transparent black overlay outside scanning area

### 🔒 Permission Handling

The scanner automatically:
1. Checks camera permission status
2. Requests permission if not determined
3. Shows error message if denied
4. Calls delegate error method with appropriate error

## Best Practices

1. **Always dismiss the scanner** in delegate callbacks after handling the result
2. **Check camera permissions** before presenting the scanner (optional, as scanner handles this internally)
3. **Customize `supportedCodeTypes`** if you only need specific barcode types for better performance
4. **Handle all delegate methods** to provide proper user feedback
5. **Use `.fullScreen` presentation** for best user experience

## Troubleshooting

### Camera Permission Issues

**Problem**: Scanner shows "Camera access denied" error.

**Solution**: 
1. Ensure `NSCameraUsageDescription` is added to `Info.plist`
2. Guide users to Settings → Privacy → Camera → Your App → Enable

### Scanner Not Detecting Barcodes

**Problem**: Camera preview shows but barcodes aren't detected.

**Solution**:
1. Ensure barcode is within the scanning area (corner markers)
2. Check if the barcode type is in `supportedCodeTypes`
3. Try zooming in using pinch gesture for small/distant barcodes
4. Ensure good lighting conditions

### Build Errors

**Problem**: Missing AVFoundation imports.

**Solution**: Add `import AVFoundation` to files using the scanner.

## Example Project Structure

```
YourProject/
├── ViewControllers/
│   ├── iOSScannerViewController.swift  ← Add this file
│   └── YourViewController.swift        ← Use scanner here
├── Info.plist                          ← Add camera permission
└── Assets/
```

## License

This project is available under the MIT License. Feel free to use it in your personal and commercial projects.

```
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

## Support

If you find this scanner useful, please consider:
- ⭐ Starring the repository
- 📢 Sharing with other iOS developers
- 🐛 Reporting issues

## Changelog

### Version 1.0.0
- Initial release
- Support for 11 barcode types
- Pinch-to-zoom functionality
- Animated scanning line
- Comprehensive error handling
- Camera permission management
- Haptic feedback
- Visual success overlay

---

**Built with ❤️ for the iOS developer community**
