//
//  WebViewController.swift
//  RNWebSdk
//
//  Created by Nikhil1 Saxena on 02/12/20.
//  Copyright © 2020 Nikhil1 Saxena. All rights reserved.
//

import Foundation
import MobileCoreServices
import MediaPlayer
import UIKit
import WebKit
import AVFoundation
import AVKit

public class WebViewController : UIViewController, WKScriptMessageHandler, UINavigationControllerDelegate, UIImagePickerControllerDelegate, WKUIDelegate {
    
    @IBOutlet weak var mWebKitView: WKWebView!
    
    let mNativeToWebHandler = "OroWebViewInterface"
    let mNativeOnImageCapture = "onImageCapture"
    let mNativeFileDownload = "handleDownloadFile"
    let mNativeFileUpload = "handleUploadFile"
    let mNativeRecordVideo = "onVideoCapture"
    let mNativePlayVideo = "handlePlayVideo"
    let mWebPageName : String = "sampleweb"
    let mWebPageExtension : String = "html"
    var fileURL: URL!
    var downloadedFileURL: String = ""
    var originalImage: UIImage!
    
    var thumbnailImage: UIImage!
    
    let videoPlayer : AVPlayer? = nil
    var playerItem:AVPlayerItem?
    let videoFileName = "/video.mp4"
    
    var videoURL: URL!
    var uploadedFileDetails :[Dictionary<String, AnyObject>] = []
    var totalUploadFileCount: Int!
    
    let sampleCSVData = "a%2Cb%2Cc%0A1%2C2%2Cx%0A2%2C1%2Cx%0A3%2C5%2Cy%0A4%2C6%2Cy%0A"
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        loadWebView()
        setupWebViewHandler()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.finishedPlaying(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    
    @objc func finishedPlaying(notification:NSNotification) {
        self.dismiss(animated: true, completion: nil)
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadWebView () {
        
        //                if let url = Bundle.main.url(forResource: mWebPageName, withExtension: mWebPageExtension) {
        //                    mWebKitView.configuration.preferences.javaScriptEnabled = true
        //                    mWebKitView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        //                }
        
        //http://localhost:3000
        //http://192.168.29.164:3000/mutual_fund
        let url = URL(string: "https://jio.orowealth.com/jfsmf/")!
//        let url = URL(string: "http://192.168.1.6:3000/")!
        mWebKitView.load(URLRequest(url: url))
        mWebKitView.configuration.preferences.javaScriptEnabled = true
        mWebKitView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        mWebKitView.allowsBackForwardNavigationGestures = true
    }
    
    func setupWebViewHandler () {
        let contentController = WKUserContentController()
        mWebKitView.configuration.userContentController = contentController
        mWebKitView.configuration.userContentController.add(self, name: mNativeToWebHandler)
        mWebKitView.configuration.userContentController.add(self, name: mNativeOnImageCapture)
        mWebKitView.configuration.userContentController.add(self, name: mNativeFileDownload)
        mWebKitView.configuration.userContentController.add(self, name: mNativeFileUpload)
        mWebKitView.configuration.userContentController.add(self, name: mNativeRecordVideo)
        mWebKitView.configuration.userContentController.add(self, name: mNativePlayVideo)
    }
    
    func generateThumbnail(path: URL) -> UIImage? {
        do {
            let asset = AVURLAsset(url: path, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            return thumbnail
        } catch let error {
            print("*** Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
    
    
    func openNativeCamera() {
        
        print("Inside Open Camera")
        let vc = UIImagePickerController()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            vc.sourceType = .camera
        }else {
            vc.sourceType = .photoLibrary
        }
        
        vc.allowsEditing = true
        vc.delegate = self
        present(vc, animated: true)
    }
    
    func playVideo(url:String) {
        let selectedVideoUrl = URL(string: url)
        let player = AVPlayer(url: selectedVideoUrl!)
        let controller=AVPlayerViewController()
        controller.player=player
        controller.view.frame = self.view.frame
        //        self.view.addSubview(controller.view)
        player.play()
        self.present(controller, animated: true, completion: nil)
        //        self.addChild(controller)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let selectedVideo:URL = (info[UIImagePickerController.InfoKey.mediaURL] as? URL) {
            self.videoURL = selectedVideo
            self.thumbnailImage = generateThumbnail(path: selectedVideo)
            sendThumbnailToJS()
        }
        
        guard let image = info[.editedImage] as? UIImage else {
            return
        }
        
        self.originalImage = image
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = NSDate().timeIntervalSince1970
        let fileName = "\(timestamp).jpeg"
        fileURL = documentsDirectory.appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality:  1.0),
           !FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try data.write(to: fileURL)
                
            } catch {
                print("error saving file:", error)
            }
        }
        sendUrlToJS()
    }
    
    func sendThumbnailToJS() {
        let imageStr = self.thumbnailImage.jpegData(compressionQuality: 0.3)?.base64EncodedString(options: []) ?? ""
        let url = self.videoURL.path
        let jsMethod = "onVideoCapture(\""+url+"\",\""+imageStr+"\");"
        
        self.mWebKitView.evaluateJavaScript(jsMethod, completionHandler: { result, error in
            guard error == nil else {
                print(error as Any)
                return
            }
        })
    }
    
    func sendUrlToJS () {
        let imageStr = self.originalImage.jpegData(compressionQuality: 0.3)?.base64EncodedString(options: []) ?? ""
        let url = self.fileURL.path
        let jsMethod = "onImageCapture(\""+url+"\",\""+imageStr+"\");"
        
        self.mWebKitView.evaluateJavaScript(jsMethod, completionHandler: { result, error in
            guard error == nil else {
                print(error as Any)
                return
            }
        })
    }
    
    func recordVideo() {
        
        let vc = UIImagePickerController()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            vc.sourceType = .camera
            vc.mediaTypes = [kUTTypeMovie as String]
            
        }else {
            vc.sourceType = .photoLibrary
        }
        
        vc.allowsEditing = true
        vc.delegate = self
        present(vc, animated: true)
    }
    
    
    func downloadFile(url:String) {
        
        let fileDataUrl = URL(string: url)
        FileDownloader.loadFileAsync(url: fileDataUrl!) { (path, error) in
            self.downloadedFileURL = path!
        }
        
        let filename = getDocumentsDirectory().appendingPathComponent("Sample-Spreadsheet-50000-rows.csv")
        self.downloadedFileURL = "file://\(self.downloadedFileURL)"
        do {
            let contents  = try FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for indexx in 0..<contents.count {
                if contents[indexx].lastPathComponent == filename.lastPathComponent {
                    let activityViewController = UIActivityViewController(activityItems: [contents[indexx]], applicationActivities: nil)
                    self.present(activityViewController, animated: true, completion: nil)
                }
            }
        }
        catch{
            print ("failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func newCreateRequest(url:URL, headers:[String:AnyObject], imagePath: URL, fileUrl:String) throws -> URLRequest {
        
        let mimeType = mimeTypeForPath(path: fileUrl)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        let boundary = generateBoundaryString()
        for (key, value) in headers {
            urlRequest.setValue(value as? String, forHTTPHeaderField: key)
        }
        
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        
        if let contentData = FileManager.default.contents(atPath: fileUrl) {
            urlRequest.httpBody = createBodyWithParameters(parameters: nil, filePathKey: "uploadcandocs", imageDataKey: contentData, boundary: boundary, mimeType:mimeType)
        }
        
        //        print("========Request==========", urlRequest.httpBody as Any)
        //        print("========Request headers==========", urlRequest.allHTTPHeaderFields as Any)
        //        print("========Request debug==========", urlRequest.description)
        
        return urlRequest
        
        
    }
    
    func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
    
    
    func uploadFile(url:String, headers:[String:AnyObject], fileUrl:String, ftype:String) {
        
        
        let serverUrl = URL(string: "\(url)&type=\(ftype)")
        
        let photoUrl = URL(string: fileUrl as String)
        //let requestHeaders = headers
        //print("Server Url ======>",serverUrl as Any, "requestHeaders ======>",requestHeaders, "photoUrl ======>",photoUrl as Any)
        
        let request: URLRequest
        
        do {
            request = try newCreateRequest(url:serverUrl!, headers:headers, imagePath:photoUrl!, fileUrl:fileUrl)
        } catch{
            print(error)
            return
        }
        
        
        let task = URLSession.shared.dataTask(with: request) { [self] data, response, error  in
            guard let data = data, error == nil else {
                //              print(error ?? "Unknown error")
                self.sendCallBackToJS(response: "Unknown error", methodName: "onError")
                return
            }
            do {
                
                let json = try JSONSerialization.jsonObject(with: data) as! Dictionary<String, AnyObject>
                //                print("=======json=======", json)
                
                DispatchQueue.main.async { [self] () -> Void in
                    
                    if(self.isSessionExpired(json: json)){
                        self.sendCallBackToJS(response: json, methodName: "onError")
                    }else{
                        if let success = json["success"] as? Bool, success == true {
                            self.uploadedFileDetails.append(json)
                        }else{
                            self.sendCallBackToJS(response: json, methodName: "onError")
                        }
                    }
                    
                    if(self.uploadedFileDetails.count == self.totalUploadFileCount ){
                        self.sendCallBackToJS(response: self.uploadedFileDetails, methodName: "onResult")
                    }
                    
                }
                
            }catch {
                
                let jsMethod = "onError(\"Failed to loadimage\");"
                
                self.mWebKitView.evaluateJavaScript(jsMethod, completionHandler: { result, error in
                    guard error == nil else {
                        print(error as Any)
                        return
                    }
                })
            }
            
        }
        task.resume()
        
    }
    
    func sendCallBackToJS(response:Any, methodName:String){
        let jsonData = try? JSONSerialization.data(withJSONObject: response, options: [])
        let encodedData = jsonData!.base64EncodedString(options: .endLineWithCarriageReturn)
        
        let jsMethod = "\(methodName)(\""+encodedData+"\");"
        
        self.mWebKitView.evaluateJavaScript(jsMethod, completionHandler: { result, error in
            guard error == nil else {
                print(error as Any)
                return
            }
        })
    }
    
    func isSessionExpired(json:Dictionary<String, AnyObject>)-> Bool{
        var sessionExpiry = false
        
        if let error = json["error"] as? Dictionary<String, AnyObject> {
            if let code = error["code"] as? String, code == "U50013" {
                sessionExpiry = true
            }
        }
        
        return sessionExpiry
        
    }
    
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        do {
            let msgBody = message.body as! String
            print("The data ", msgBody)
            let data = Data(msgBody.utf8)
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] {
                // try to read out a string array
                if let event = json["event"] as? String {
                    if event == "OPEN_CAMERA" {
                        openNativeCamera()
                    }
                    
                    if event == "RECORD_VIDEO" {
                        recordVideo()
                    }
                    
                    if event == "OPEN_VIDEO" {
                        if let eventData:[String:AnyObject] = (json["data"] as? [String:AnyObject]) {
                            if let selectedVideo:String = (eventData["uri"] as? String) {
                                playVideo(url:"file:///\(selectedVideo)" )
                            }
                        }
                        
                    }
                    
                    if event == "UPLOAD_FILE" {
                        if let eventData:[String:AnyObject] = (json["data"] as? [String:AnyObject]) {
                            let header = eventData["headers"] as! [String:AnyObject]
                            let url = eventData["url"] as! String
                            
                            let fileUrl = eventData["path"] as! [String]
                            let type = eventData["ftype"] as! [String]
                            self.totalUploadFileCount = fileUrl.count
                            
                            self.uploadedFileDetails = []
                            for index in 0..<fileUrl.count {
                                uploadFile(url:url, headers:header, fileUrl:fileUrl[index], ftype:type[index])
                            }
                            
                        }
                        
                        
                    }
                    if event == "DOWNLOAD_FILE" {
                        if let eventData:[String:AnyObject] = (json["data"] as? [String:AnyObject]) {
                            let url = eventData["url"] as! String
                            downloadFile(url:url)
                            
                        }
                    }
                }
            }
        } catch let error as NSError {
            let jsMethod = "onError(\"Failed to loadimage\");"
            
            self.mWebKitView.evaluateJavaScript(jsMethod, completionHandler: { result, error in
                guard error == nil else {
                    print(error as Any)
                    return
                }
            })
            
            print("Failed to load: \(error.localizedDescription)")
        }
        
    }
    
    
    func createBodyWithParameters(parameters: [String: String]?, filePathKey: String?, imageDataKey: Data, boundary: String, mimeType:String) -> Data {
        var body = Data();
        
        if parameters != nil {
            for (key, value) in parameters! {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(value)\r\n")
            }
        }
        
        let filename = "image.jpg"
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(filePathKey!)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageDataKey)
        body.appendString("\r\n")
        
        body.appendString("--\(boundary)--\r\n")
        //        print("========Request body==========", body)
        return body
    }
    
    func generateBoundaryString() -> String {
        return "Boundary-\(NSUUID().uuidString)"
    }
}

extension Data {
    mutating func appendString(_ string: String) {
        let data = string.data(using: String.Encoding.utf8, allowLossyConversion: true)
        append(data!)
    }
}




