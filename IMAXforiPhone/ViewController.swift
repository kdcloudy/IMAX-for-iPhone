//
//  ViewController.swift
//  IMAXforiPhone
//
//  Created by Kaustubh Debnath on 29/01/21.
//

import UIKit

import AVFoundation

class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self._setupCaptureSession()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            _setupCaptureSession()
        @unknown default:
            fatalError()
        }
    }
    

    
    
    @IBOutlet weak var segmentcontrole: UISegmentedControl!
    
    
    private var _captureSession: AVCaptureSession?
    private var _videoOutput: AVCaptureVideoDataOutput?
    private var _assetWriter: AVAssetWriter?
    private var _assetWriterInput: AVAssetWriterInput?
    private var _adpater: AVAssetWriterInputPixelBufferAdaptor?
    private var _filename = ""
    private var _time: Double = 0
    private func _setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        print(session.sessionPreset)
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
          
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input) else { return }

        session.beginConfiguration()
        session.addInput(input)
        session.commitConfiguration()
        let fdesc = device.formats.description
        print(fdesc)
        

        let output = AVCaptureVideoDataOutput()
        guard session.canAddOutput(output) else { return }
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.kdcloudy.video"))
        session.beginConfiguration()
        session.addOutput(output)
        session.commitConfiguration()

        DispatchQueue.main.async {
            let previewView = _PreviewView()
            previewView.videoPreviewLayer.session = session
            previewView.frame = self.view.bounds
            previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.insertSubview(previewView, at: 0)
        }

        session.startRunning()
        _videoOutput = output
        _captureSession = session
    }

    private enum _CaptureState {
        case idle, start, capturing, end
    }
    private var _captureState = _CaptureState.idle

    @IBAction func capture(_ sender: Any) {
        switch _captureState {
        case .idle:
            _captureState = .start
        case .capturing:
            _captureState = .end
        default:
            break
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        switch _captureState {
        case .start:
            // Set up recorder
            _filename = UUID().uuidString
            let videoPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(_filename).mov")
            let writer = try! AVAssetWriter(outputURL: videoPath, fileType: .mov)
            
            //let settings = _videoOutput!.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
           
            print(_videoOutput!.availableVideoCodecTypesForAssetWriter(writingTo: .m4v))
           
            let videoDescription = sampleBuffer.formatDescription;
            
//            let HDRSettings: [String: Any] = [
//
//            ]
            
            
            
            
            let vidSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: 4032,
                AVVideoHeightKey: 3024,
                AVVideoColorPropertiesKey: [ AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                                             AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                                             AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020],
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 150000000,                                                            AVVideoExpectedSourceFrameRateKey: 30,                                                          AVVideoMaxKeyFrameIntervalKey:2,
                                                  ],
            
                
            ]
            
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: vidSettings, sourceFormatHint: videoDescription)
            
            
            input.mediaTimeScale = CMTimeScale(bitPattern: 600)
            input.expectsMediaDataInRealTime = true
         // input.transform = CGAffineTransform(rotationAngle: .pi)
            let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            if writer.canAdd(input) {
                writer.add(input)
            }
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            _assetWriter = writer
            _assetWriterInput = input
            _adpater = adapter
            _captureState = .capturing
            _time = timestamp
        case .capturing:
            if _assetWriterInput?.isReadyForMoreMediaData == true {
                let time = CMTime(seconds: timestamp - _time, preferredTimescale: CMTimeScale(600))
                _adpater?.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: time)
            }
            break
        case .end:
            guard _assetWriterInput?.isReadyForMoreMediaData == true, _assetWriter!.status != .failed else { break }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(_filename).mov")
            _assetWriterInput?.markAsFinished()
            _assetWriter?.finishWriting { [weak self] in
                self?._captureState = .idle
                self?._assetWriter = nil
                self?._assetWriterInput = nil
                DispatchQueue.main.async {
                    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    self?.present(activity, animated: true, completion: nil)
                }
            }
        default:
            break
        }
    }
}

private class _PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
