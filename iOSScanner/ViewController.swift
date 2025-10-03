//
//  ViewController.swift
//  iOSScanner
//
//  Created by Nakul Sharma on 03/10/25.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    // MARK: - UI Components
    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Scan Code", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap button to scan"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.addSubview(scanButton)
        view.addSubview(resultLabel)
        
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            // Button constraints - center horizontally, slightly above center vertically
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            scanButton.widthAnchor.constraint(equalToConstant: 200),
            scanButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Label constraints - centered horizontally, below the button
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resultLabel.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 30),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    @objc private func scanButtonTapped() {
        let scanner = iOSScannerViewController()
        scanner.delegate = self
        scanner.modalPresentationStyle = .fullScreen
        present(scanner, animated: true)
    }
}

// MARK: - iOSScannerDelegate
extension ViewController: iOSScannerDelegate {
    func scannerDidScannedCode(_ scanner: iOSScannerViewController, code: String, type: AVMetadataObject.ObjectType) {
        resultLabel.text = code
        scanner.dismiss(animated: true)
    }
    
    func scannerDidCancel(_ scanner: iOSScannerViewController) {
        resultLabel.text = "Scan cancelled"
    }
    
    func scannerDidFail(_ scanner: iOSScannerViewController, error: iOSScannerError) {
        resultLabel.text = "Error: \(error.localizedDescription)"
        scanner.dismiss(animated: true)
    }
}
