import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// Manages AVCaptureSession and delivers sample buffers for OCR processing.
@Observable
final class CameraManager: NSObject {
    let session = AVCaptureSession()
    var isRunning = false
    var permissionGranted = false
    var permissionDenied = false

    /// Called when a new frame is ready for processing.
    var onFrameCaptured: ((_ sampleBuffer: CMSampleBuffer) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.poro.camera", qos: .userInitiated)
    private nonisolated(unsafe) var lastProcessedTime: CFTimeInterval = 0
    private let throttleInterval: CFTimeInterval = 1.0

    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    if granted {
                        self?.permissionGranted = true
                        self?.setupSession()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func startSession() {
        guard !isRunning, permissionGranted else { return }
        let session = self.session
        processingQueue.async {
            session.startRunning()
            Task { @MainActor [weak self] in
                self?.isRunning = true
            }
        }
    }

    func stopSession() {
        guard isRunning else { return }
        let session = self.session
        processingQueue.async {
            session.stopRunning()
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    private func setupSession() {
        let session = self.session
        let videoOutput = self.videoOutput
        let queue = self.processingQueue

        processingQueue.async { [weak self] in
            session.beginConfiguration()
            session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            if let self {
                videoOutput.setSampleBufferDelegate(self, queue: queue)
            }
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            session.commitConfiguration()
        }
    }
}

extension CameraManager: @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastProcessedTime >= throttleInterval else { return }
        lastProcessedTime = now

        let callback = onFrameCaptured
        callback?(sampleBuffer)
    }
}
