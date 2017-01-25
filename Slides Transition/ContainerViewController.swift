//
//  ContainerViewController.swift
//  Slides Transition
//  swift 3.0
//
//  Inspired by John Marstall
//  <http://theiconmaster.com/2015/03/transitioning-between-view-controllers-in-the-same-window-with-swift-mac/>
//  Created by Erich Küster on December 16, 2016
//  Copyright © 2016 Erich Küster. All rights reserved.
//

import Cocoa
import ZipZap

class ContainerViewController: NSViewController {

    var defaultSession: URLSession!
    var mainViewFrame: NSRect!
    var mainViewFrameOrigin = NSPoint.zero
    var sharedDocumentController: NSDocumentController!

    var imageBitmaps = [NSImageRep]()
    var imageFiles: [ImageFile]? = nil
    var imageFileIndex: Int = -1
    var pageIndex: Int = 0
    var viewFrameOrigin = NSPoint.zero
    var viewFrameSize = NSSize.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        // to use recent documents
        sharedDocumentController = NSDocumentController.shared()
        // to use url request
        let config = URLSessionConfiguration.default
        self.defaultSession = URLSession(configuration: config)
        // instantiate source view controller
        let mainStoryboard: NSStoryboard = NSStoryboard(name: "Main", bundle: nil)
        let sourceViewController = mainStoryboard.instantiateController(withIdentifier: "sourceViewController") as! SourceViewController
        self.insertChildViewController(sourceViewController, at: 0)
        // get dimensions for view frame
        guard let mainViewFrame = NSScreen.main()?.visibleFrame
            else { return }
        self.mainViewFrame = mainViewFrame
        self.mainViewFrameOrigin = mainViewFrame.origin
        self.mainViewFrame.origin = NSPoint.zero
//        mainViewFrame.size.width *= 0.6
        let presentationOptions: NSApplicationPresentationOptions = [.hideDock, .autoHideMenuBar]
        NSApp.presentationOptions = presentationOptions
        self.view.addSubview(sourceViewController.view)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // now window exists
        let sourceViewController = self.childViewControllers[0]
        sourceViewController.view.animator().frame = mainViewFrame
        let containerWindow = self.view.window!
        var contentRect = NSRect.zero
        contentRect.origin = mainViewFrameOrigin
        contentRect.size = mainViewFrame.size
        // set frame for container view window
        let frameRect = containerWindow.frameRect(forContentRect: contentRect)
        containerWindow.setFrame(frameRect, display: true, animate: true)
    }

    func imageViewfromImageIndex(_ imageIndex: Int) {
        let imageFile = imageFiles?[imageIndex]
        let imageURL = imageFile?.fileURL
        let urlRequest: URLRequest = URLRequest(url: imageURL!)
        let task = defaultSession.dataTask(with: urlRequest, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error != nil {
                Swift.print("error from data task: \(error!.localizedDescription) in \((error as! NSError).domain)")
                return
            }
            else {
                DispatchQueue.main.async {
                    self.fillBitmaps(with: data!, at: imageIndex)
                    self.imageViewWithBitmap()
                }
            }
        })
        task.resume()
    }

    func drawPDFPageInImage(_ page: CGPDFPage) -> NSImageRep? {
        // adapted from <https://ryanbritton.com/2015/09/correctly-drawing-pdfs-in-cocoa/>
        // start by getting the crop box since only its contents should be drawn
        let cropBox = page.getBoxRect(.cropBox)
        let rotationAngle = page.rotationAngle
        let angleInRadians = Double(-rotationAngle) * (M_PI / 180)
        var transform = CGAffineTransform(rotationAngle: CGFloat(angleInRadians))
        let rotatedCropRect = cropBox.applying(transform);
        // set manually the size scaled by 300 / 72 dpi
        let scale = CGFloat(4.1667)
        // figure out the closest size
        let bestSize = CGSize(width: cropBox.width*scale, height: cropBox.height*scale)
        let bestFit = CGRect(x: 0.0, y: 0.0, width: bestSize.width, height: bestSize.height)
        let scaleX = bestFit.width / rotatedCropRect.width
        let scaleY = bestFit.height / rotatedCropRect.height
        
        let width = Int(bestFit.width)
        let height = Int(bestFit.height)
        let bytesPerRow = (width * 4 + 0x0000000F) & ~0x0000000F
        // create the drawing context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        let context =  CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: (bitmapInfo))
        // fill the background color
        context?.setFillColor(NSColor.white.cgColor)
        context?.fill(CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        if (scaleY > 1) {
            // since CGPDFPageGetDrawingTransform won't scale up, we need to do it manually
            transform = transform.scaledBy(x: scaleX, y: scaleY)
        }
        context?.concatenate(transform)
        // Clip the drawing to the CropBox
        context?.addRect(cropBox)
        context?.clip();
        context?.drawPDFPage(page);
        let image = context?.makeImage()
        return NSBitmapImageRep(cgImage: image!)
    }

    // generate representation(s) for image
    func fillBitmaps(with graphicsData: Data, at index: Int) {
        // generate representation(s) for image
        if (imageBitmaps.count > 0) {
            // make room for new bitmaps
            imageBitmaps.removeAll(keepingCapacity: false)
        }
        pageIndex = 0
        imageBitmaps = NSBitmapImageRep.imageReps(with: graphicsData)
        if (imageBitmaps.count == 0) {
            let fileType = imageFiles?[index].fileType
            if fileType == "com.adobe.pdf" {
                // try pdf document
                let provider = CGDataProvider(data: graphicsData as CFData)
                guard let document = CGPDFDocument(provider!) else {
                    return
                }
                let count = document.numberOfPages
                // go through pages
                for i in 1 ... count {
                    if let page = document.page(at: i) {
                        if let imageRep = drawPDFPageInImage(page) {
                            imageBitmaps.append(imageRep)
                        }
                    }
                }
            }
            // only eps data are remaining at this point
            if (NSEPSImageRep(data: graphicsData) != nil) {
                var pdfData = NSMutableData()
                let provider = CGDataProvider(data: graphicsData as CFData)
                let consumer = CGDataConsumer(data: pdfData as CFMutableData)
                var callbacks = CGPSConverterCallbacks()
                let converter = CGPSConverter(info: nil, callbacks: &callbacks, options: [:] as CFDictionary)
                let converted = converter!.convert(provider!, consumer: consumer!, options: [:] as CFDictionary)
                let pdfProvider = CGDataProvider(data: pdfData as CFData)
                let document = CGPDFDocument(pdfProvider!)
                // EPS contains always only one page
                if let page = document?.page(at: 1) {
                    if let imageRep = drawPDFPageInImage(page) {
                        imageBitmaps.append(imageRep)
                    }
                }
            }
        }
    }

    // look also at <https://blog.alexseifert.com/2016/06/18/resize-an-nsimage-proportionately-in-swift/>
    func fitImageIntoFrameRespectingAspectRatio(_ size: NSSize, into frame: NSRect) -> NSRect {
        var frameOrigin = NSPoint.zero
        var frameSize = frame.size
        // calculate aspect ratios
        let imageSize = size
        // calculate aspect ratios
        let mainRatio = frameSize.width / frameSize.height
        let imageRatio = imageSize.width / imageSize.height
        // fit view frame into main frame
        if (mainRatio > imageRatio) {
            // portrait, scale maxWidth
            let innerWidth = frameSize.height * imageRatio
            frameOrigin.x = (frameSize.width - innerWidth) / 2.0
            frameSize.width = innerWidth
        }
        else {
            // landscape, scale maxHeight
            let innerHeight = frameSize.width / imageRatio
            frameOrigin.y = (frameSize.height - innerHeight) / 2.0
            frameSize.height = innerHeight
        }
        viewFrameOrigin = frameOrigin
        viewFrameSize = frameSize
        viewFrameSize.height += 40
        return NSRect(x: 0.0, y: 0.0, width: frameSize.width, height: frameSize.height)
    }

    func imageViewWithBitmap() {
        let imageViewController = self.childViewControllers[0]
        let imageSubview = imageViewController.view.subviews[1] as! NSImageView
        let imageFile = imageFiles?[imageFileIndex]
        if (imageBitmaps.count > 0) {
            let imageBitmap = imageBitmaps[pageIndex]
            // get the real imagesize in pixels
            // look at <http://briksoftware.com/blog/?p=72>
            let imageSize = NSSize(width: imageBitmap.pixelsWide, height: imageBitmap.pixelsHigh)
            var imageRect = fitImageIntoFrameRespectingAspectRatio(imageSize, into: mainViewFrame)
            imageSubview.frame = imageRect
            let image = NSImage()
            image.addRepresentations([imageBitmap])
            imageSubview.image = image
            // shift image view by 40 to leave place for button
            imageRect.size.height += 40
            let containerWindow = self.view.window!
            containerWindow.setTitleWithRepresentedFilename((imageFile?.fileName)!)
            //resize view controller
            imageViewController.view.animator().frame = imageRect
//            imageViewController.view.frame = imageRect
//            self.view.frame = imageRect
            var contentRect = NSRect.zero
            contentRect.origin = viewFrameOrigin
            contentRect.size = viewFrameSize
            // set frame for container view window
            let frameRect = containerWindow.frameRect(forContentRect: contentRect)
            containerWindow.setFrame(frameRect, display: true, animate: true)
        }
    }

    func sheetUp(_ sender: NSMenuItem) {
        // show page up
        if (!imageBitmaps.isEmpty) {
            let nextIndex = pageIndex - 1
            if (nextIndex >= 0) {
                pageIndex = nextIndex
                imageViewWithBitmap()
            }
        }
    }
    
    func sheetDown(_ sender: NSMenuItem) {
        // show page down
        if (imageBitmaps.count > 1) {
            let nextIndex = pageIndex + 1
            if (nextIndex < imageBitmaps.count) {
                pageIndex = nextIndex
                imageViewWithBitmap()
            }
        }
    }

    func nextImage(_ sender: Any) {
        if (imageFileIndex >= 0) {
            // test what is in next URL
            let nextIndex = imageFileIndex + 1
            if (nextIndex < (imageFiles?.count)!) {
                imageFileIndex = nextIndex
                imageViewfromImageIndex(nextIndex)
            }
        }
    }

    func previousImage(_ sender: Any) {
        if (imageFileIndex >= 0) {
            // test what is in previuos URL
            let nextIndex = imageFileIndex - 1
            if (nextIndex >= 0) {
                imageFileIndex = nextIndex
                imageViewfromImageIndex(nextIndex)
            }
        }
    }
}
