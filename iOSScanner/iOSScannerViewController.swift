//
//  iOSScannerViewController.swift
//  A plug-and-play barcode/QR code scanner for iOS
//
//  Usage:
//  1. Import this file into your project
//  2. Create an instance: let scanner = iOSScannerViewController()
//  3. Set the delegate: scanner.delegate = self
//  4. Present it: present(scanner, animated: true)
//  5. Implement the iOSScannerDelegate protocol
//

import UIKit
import AVFoundation

// MARK: - Delegate Protocol

/// Protocol to receive scanner events
protocol iOSScannerDelegate: AnyObject {
    /// Called when a code is successfully scanned
    /// - Parameters:
    ///   - scanner: The scanner view controller
    ///   - code: The scanned code string
    ///   - type: The barcode type (e.g., QR, EAN13, etc.)
    func scannerDidScannedCode(_ scanner: iOSScannerViewController, code: String, type: AVMetadataObject.ObjectType)

    /// Called when scanning is cancelled by the user
    /// - Parameter scanner: The scanner view controller
    func scannerDidCancel(_ scanner: iOSScannerViewController)

    /// Called when scanner fails (e.g., camera permission denied, no camera available)
    /// - Parameters:
    ///   - scanner: The scanner view controller
    ///   - error: The error that occurred
    func scannerDidFail(_ scanner: iOSScannerViewController, error: iOSScannerError)
}

// MARK: - Error Types

/// Errors that can occur during scanning
enum iOSScannerError: Error, LocalizedError {
    case cameraUnavailable
    case cameraAccessDenied
    case cameraConfigurationFailed
    case captureSessionSetupFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .cameraAccessDenied:
            return "Camera access denied. Please enable camera access in Settings."
        case .cameraConfigurationFailed:
            return "Failed to configure camera for scanning"
        case .captureSessionSetupFailed:
            return "Failed to setup camera capture session"
        }
    }
}

// MARK: - Main View Controller

/// A standalone barcode/QR code scanner view controller
class iOSScannerViewController: UIViewController {

    // MARK: - Public Properties

    /// Delegate to receive scanner events
    weak var delegate: iOSScannerDelegate?

    /// Enable/disable scanning (can be used to pause scanning)
    var isScanning: Bool = true

    /// Current zoom factor (1.0 to maxZoomFactor)
    var currentZoomFactor: CGFloat = 1.0

    /// Maximum zoom factor allowed
    private var maxZoomFactor: CGFloat = 5.0

    /// Supported barcode types (can be customized before presenting)
    var supportedCodeTypes: [AVMetadataObject.ObjectType] = [
        .qr, .ean13, .ean8, .code128, .code39, .code93, .pdf417,
        .dataMatrix, .upce, .interleaved2of5, .itf14
    ]

    // MARK: - Private Properties

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanningAreaRect: CGRect = .zero
    private var overlayView: UIView?
    private var scanLineView: UIView?
    private var scanLineAnimation: CABasicAnimation?
    private var videoCaptureDevice: AVCaptureDevice?

    // UI Elements
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let zoomLabel: UILabel = {
        let label = UILabel()
        label.text = "1.0x"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Scanner"
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        checkCameraPermissions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        updateOverlayAndScanLine()
    }

    // MARK: - Setup Methods

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.handleError(.cameraAccessDenied)
                    }
                }
            }
        case .denied, .restricted:
            handleError(.cameraAccessDenied)
        @unknown default:
            handleError(.cameraAccessDenied)
        }
    }

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            handleError(.cameraUnavailable)
            return
        }

        self.videoCaptureDevice = device
        self.maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 10.0)

        let captureSession = AVCaptureSession()

        do {
            // Configure video input
            let videoInput = try AVCaptureDeviceInput(device: device)

            guard captureSession.canAddInput(videoInput) else {
                handleError(.captureSessionSetupFailed)
                return
            }

            captureSession.addInput(videoInput)

            // Configure camera for better barcode scanning
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.unlockForConfiguration()

            // Configure metadata output
            let metadataOutput = AVCaptureMetadataOutput()

            guard captureSession.canAddOutput(metadataOutput) else {
                handleError(.captureSessionSetupFailed)
                return
            }

            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = supportedCodeTypes

            self.captureSession = captureSession

            // Setup preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            // Setup UI elements
            setupUI()

            // Setup pinch gesture for zoom
            setupPinchGesture()

            // Update scanning area
            DispatchQueue.main.async { [weak self] in
                self?.updateScanningArea()
            }

        } catch {
            handleError(.cameraConfigurationFailed)
        }
    }

    private func setupUI() {
        // Add title label
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // Add cancel button
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Add zoom label
        view.addSubview(zoomLabel)
        NSLayoutConstraint.activate([
            zoomLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            zoomLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zoomLabel.widthAnchor.constraint(equalToConstant: 60),
            zoomLabel.heightAnchor.constraint(equalToConstant: 32)
        ])

        // Create overlay with cutout
        createOverlayView()

        // Create scanning line
        createScanLineView()
    }

    private func createOverlayView() {
        overlayView = UIView(frame: view.bounds)
        overlayView?.backgroundColor = .clear
        overlayView?.isUserInteractionEnabled = false

        if let overlayView = overlayView {
            view.addSubview(overlayView)
        }
    }

    private func createScanLineView() {
        scanLineView = UIView()
        scanLineView?.backgroundColor = UIColor.blue.withAlphaComponent(0.5)
        scanLineView?.translatesAutoresizingMaskIntoConstraints = false

        if let scanLineView = scanLineView {
            view.addSubview(scanLineView)
        }
    }

    private func updateOverlayAndScanLine() {
        guard let overlayView = overlayView else { return }

        // Remove existing sublayers
        overlayView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Calculate cutout rect (always use normal mode - 70% of screen)
        let rectSize = view.bounds.width * 0.7

        let cutoutRect = CGRect(
            x: (view.bounds.width - rectSize) / 2,
            y: (view.bounds.height - rectSize) / 2,
            width: rectSize,
            height: rectSize
        )

        // Create overlay with cutout
        let overlayPath = UIBezierPath(rect: view.bounds)
        let cutoutPath = UIBezierPath(rect: cutoutRect)
        overlayPath.append(cutoutPath)
        overlayPath.usesEvenOddFillRule = true

        let overlayLayer = CAShapeLayer()
        overlayLayer.path = overlayPath.cgPath
        overlayLayer.fillRule = .evenOdd
        overlayLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        overlayView.layer.addSublayer(overlayLayer)

        // Add corner markers
        addCornerMarkers(to: overlayView, cutoutRect: cutoutRect)

        // Update scan line
        updateScanLineAnimation(in: cutoutRect)
    }

    private func addCornerMarkers(to view: UIView, cutoutRect: CGRect) {
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 3
        let cornerColor = UIColor.blue

        let corners: [(CGPoint, [UIRectEdge])] = [
            (CGPoint(x: cutoutRect.minX, y: cutoutRect.minY), [.top, .left]),
            (CGPoint(x: cutoutRect.maxX, y: cutoutRect.minY), [.top, .right]),
            (CGPoint(x: cutoutRect.minX, y: cutoutRect.maxY), [.bottom, .left]),
            (CGPoint(x: cutoutRect.maxX, y: cutoutRect.maxY), [.bottom, .right])
        ]

        for (point, edges) in corners {
            for edge in edges {
                let cornerLine = UIBezierPath()

                switch edge {
                case .top:
                    cornerLine.move(to: point)
                    cornerLine.addLine(to: CGPoint(x: point.x + (edges.contains(.right) ? -cornerLength : cornerLength), y: point.y))
                case .bottom:
                    cornerLine.move(to: point)
                    cornerLine.addLine(to: CGPoint(x: point.x + (edges.contains(.right) ? -cornerLength : cornerLength), y: point.y))
                case .left:
                    cornerLine.move(to: point)
                    cornerLine.addLine(to: CGPoint(x: point.x, y: point.y + (edges.contains(.bottom) ? -cornerLength : cornerLength)))
                case .right:
                    cornerLine.move(to: point)
                    cornerLine.addLine(to: CGPoint(x: point.x, y: point.y + (edges.contains(.bottom) ? -cornerLength : cornerLength)))
                default:
                    break
                }

                let lineLayer = CAShapeLayer()
                lineLayer.path = cornerLine.cgPath
                lineLayer.strokeColor = cornerColor.cgColor
                lineLayer.lineWidth = cornerWidth
                lineLayer.lineCap = .round
                view.layer.addSublayer(lineLayer)
            }
        }
    }

    private func updateScanLineAnimation(in rect: CGRect) {
        guard let scanLineView = scanLineView else { return }

        // Stop existing animation
        scanLineView.layer.removeAllAnimations()

        // Update scan line size and position
        scanLineView.frame = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: 2
        )

        // Create animation
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = rect.minY
        animation.toValue = rect.maxY
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        scanLineView.layer.add(animation, forKey: "scanLineAnimation")
    }

    private func updateScanningArea() {
        guard let captureSession = captureSession,
              let output = captureSession.outputs.first as? AVCaptureMetadataOutput,
              let previewLayer = previewLayer else {
            return
        }

        // Always use normal mode scanning area
        let scanRect = CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7)

        output.rectOfInterest = scanRect
        scanningAreaRect = previewLayer.layerRectConverted(fromMetadataOutputRect: scanRect)

        updateOverlayAndScanLine()
    }

    // MARK: - Scanning Control

    /// Starts the scanning session
    func startScanning() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    /// Stops the scanning session
    func stopScanning() {
        captureSession?.stopRunning()
    }

    // MARK: - Actions

    @objc private func cancelButtonTapped() {
        delegate?.scannerDidCancel(self)
        dismiss(animated: true)
    }

    // MARK: - Zoom Control

    private func setupPinchGesture() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGesture)
    }

    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let device = videoCaptureDevice else { return }

        switch gesture.state {
        case .began:
            currentZoomFactor = device.videoZoomFactor
            showZoomLabel()

        case .changed:
            var newZoomFactor = currentZoomFactor * gesture.scale
            newZoomFactor = max(1.0, min(newZoomFactor, maxZoomFactor))

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoomFactor
                device.unlockForConfiguration()

                updateZoomLabel(with: newZoomFactor)
            } catch {
                print("Error setting zoom: \(error.localizedDescription)")
            }

        case .ended, .cancelled:
            currentZoomFactor = device.videoZoomFactor
            hideZoomLabel()

        default:
            break
        }
    }

    private func showZoomLabel() {
        UIView.animate(withDuration: 0.2) {
            self.zoomLabel.alpha = 1.0
        }
    }

    private func hideZoomLabel() {
        UIView.animate(withDuration: 0.3, delay: 0.5) {
            self.zoomLabel.alpha = 0
        }
    }

    private func updateZoomLabel(with zoomFactor: CGFloat) {
        zoomLabel.text = String(format: "%.1fx", zoomFactor)
    }

    // MARK: - Error Handling

    private func handleError(_ error: iOSScannerError) {
        // Stop scanning
        stopScanning()

        // Show error message
        let errorLabel = UILabel()
        errorLabel.text = error.localizedDescription
        errorLabel.textAlignment = .center
        errorLabel.textColor = .white
        errorLabel.font = UIFont.systemFont(ofSize: 16)
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Notify delegate
        delegate?.scannerDidFail(self, error: error)
    }

    private func handleSuccessfulScan(code: String, type: AVMetadataObject.ObjectType) {
        // Stop scanning
        stopScanning()
        isScanning = false

        // Show success overlay
        let successOverlay = UIView(frame: view.bounds)
        successOverlay.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
        successOverlay.alpha = 0
        view.addSubview(successOverlay)

        UIView.animate(withDuration: 0.3, animations: {
            successOverlay.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.2, animations: {
                successOverlay.alpha = 0
            }) { _ in
                successOverlay.removeFromSuperview()
            }
        }

        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Notify delegate
        delegate?.scannerDidScannedCode(self, code: code, type: type)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension iOSScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning else { return }

        for metadataObject in metadataObjects {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue,
                  let barcodeObject = previewLayer?.transformedMetadataObject(for: readableObject) else {
                continue
            }

            let barcodeBounds = barcodeObject.bounds

            // Check if barcode is within the scanning area
            if scanningAreaRect.contains(barcodeBounds) {
                handleSuccessfulScan(code: stringValue, type: readableObject.type)
                return
            }
        }
    }
}

// MARK: - Usage Example (Comment this out when using in production)
/*

 // Example 1: Basic Usage
 class MyViewController: UIViewController, iOSScannerDelegate {

     func showScanner() {
         let scanner = iOSScannerViewController()
         scanner.delegate = self
         scanner.modalPresentationStyle = .fullScreen
         present(scanner, animated: true)
     }

     func scannerDidScannedCode(_ scanner: iOSScannerViewController, code: String, type: AVMetadataObject.ObjectType) {
         print("Scanned code: \(code), type: \(type)")
         scanner.dismiss(animated: true)
     }

     func scannerDidCancel(_ scanner: iOSScannerViewController) {
         print("Scanner cancelled")
     }

     func scannerDidFail(_ scanner: iOSScannerViewController, error: iOSScannerError) {
         print("Scanner failed: \(error.localizedDescription)")
         scanner.dismiss(animated: true)
     }
 }

 // Example 2: Custom Configuration
 class MyViewController: UIViewController, iOSScannerDelegate {

     func showCustomScanner() {
         let scanner = iOSScannerViewController()
         scanner.delegate = self
         scanner.supportedCodeTypes = [.qr] // Only QR codes
         scanner.modalPresentationStyle = .fullScreen
         present(scanner, animated: true)
     }

     // Implement delegate methods...
 }

 */
