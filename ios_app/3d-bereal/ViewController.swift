//
//  ViewController.swift
//  3d-bereal
//
//  Created by Zichen Yuan on 2/17/24.
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession!
    var videoOutput: AVCaptureMovieFileOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var recordingStartTime: Date?
    
    @IBOutlet weak var but: UIButton!
    
    @IBOutlet weak var preview: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraSession()
    }
    func setupCameraSession() {
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        // Assuming you're using the rear camera
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else { return }
        
        captureSession.addInput(videoInput)
        
        videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = preview.bounds // Use the bounds of the container view
        previewLayer.videoGravity = .resizeAspectFill
        
        // Add the previewLayer as a sublayer of the container view's layer
        preview.layer.addSublayer(previewLayer)
        
        // Make sure the previewLayer resizes with its superlayer
        previewLayer.frame = preview.layer.bounds
        preview.layer.masksToBounds = true
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }


//    func setupCameraSession() {
//        captureSession = AVCaptureSession()
//        captureSession.beginConfiguration()
//
//        // Assuming you're using the rear camera
//        guard let videoDevice = AVCaptureDevice.default(for: .video),
//              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
//              captureSession.canAddInput(videoInput) else { return }
//
//        captureSession.addInput(videoInput)
//
//        videoOutput = AVCaptureMovieFileOutput()
//        if captureSession.canAddOutput(videoOutput) {
//            captureSession.addOutput(videoOutput)
//        }
//
//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.frame = view.bounds // Adjust as needed
//        previewLayer.videoGravity = .resizeAspectFill
//        view.layer.addSublayer(previewLayer)
//
//        captureSession.commitConfiguration()
//        captureSession.startRunning()
//    }
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        recordingStartTime = Date() // Capture the current time as the start time
        let outputPath = NSTemporaryDirectory() + "output.mov"
        let outputFileURL = URL(fileURLWithPath: outputPath)
        
        videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
        
        // Stop recording after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.videoOutput.stopRecording()
        }
    }
    
    // AVCaptureFileOutputRecordingDelegate methods
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Recording started")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("Recording finished")
        // Handle the recorded video (save or preview it) here
        
   
        // save the video to the photo library
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
        
        // save to firebase
        uploadVideoToFirebaseStorage(videoURL:outputFileURL)
        
    }
    
    
    // This is the selector method called after the video has been saved
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving video: \(error.localizedDescription)")
        } else {
            print("Video saved successfully.")
        }
    }
    
    
    //to firebase
    func uploadVideoToFirebaseStorage(videoURL: URL) {
        guard let startTime = recordingStartTime else {
            print("Recording start time is nil")
            return
        }
        
        // Format the date to a string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let dateString = dateFormatter.string(from: startTime)
        let baseString = String(dateString.dropLast())
        let flooredDateString = baseString + "0"
        
        // Use the formatted date as part of the file path
        let storageRef = Storage.storage().reference()
        let videoPath = "videos/\(flooredDateString)/\(UUID().uuidString).mov"
        let videosRef = storageRef.child(videoPath)
        
        // Start the upload process
        videosRef.putFile(from: videoURL, metadata: nil) { metadata, error in
            guard let metadata = metadata else {
                print("Error uploading video: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            print("Video uploaded successfully. Metadata: \(metadata)")
            
            // Optionally, get the download URL
            videosRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("Error getting download URL: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("Download URL: \(downloadURL)")
                
                // Here you can also save the download URL and the timestamp to Firestore or Realtime Database
                self.saveVideoInfoToDatabase(downloadURL: downloadURL, timestamp: startTime)
            }
        }
    }
    
    func saveVideoInfoToDatabase(downloadURL: URL, timestamp: Date) {
        let db = Firestore.firestore()
        let videosCollection = db.collection("videos")
        
        videosCollection.addDocument(data: [
            "url": downloadURL.absoluteString,
            "timestamp": timestamp
        ]) { error in
            if let error = error {
                print("Error saving video info to database: \(error.localizedDescription)")
            } else {
                print("Video info saved successfully")
            }
        }
    }

    
    
    
//    func uploadVideoToFirebaseStorage(videoURL: URL) {
//        let storageRef = Storage.storage().reference()
//        let videosRef = storageRef.child("videos/\(UUID().uuidString).mov")
//        print(videosRef)
//
//        videosRef.putFile(from: videoURL, metadata: nil) { metadata, error in
//            guard let metadata = metadata else {
//                // Handle the error
//                print(error?.localizedDescription ?? "Unknown error")
//                return
//            }
//            // Video uploaded successfully
//            print("Video uploaded: \(metadata.size)")
//
//            // Retrieve download URL if needed
//            videosRef.downloadURL { url, error in
//                guard let downloadURL = url else {
//                    // Handle any error
//                    return
//                }
//                print("Download URL: \(downloadURL)")
//                // Optionally, save the download URL to Firestore or Realtime Database
//            }
//        }
//    }
    
}
