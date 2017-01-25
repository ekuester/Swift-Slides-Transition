//
//  ImageFile.swift
//  Swift Slides Transition
//
//  inspired by Apples Exhibition App sample
//
//  Created by Erich Küster on December 14, 2016
//  Copyright © 2016 Erich Küster. All rights reserved.
//

import Cocoa
import ZipZap

// ImageFile represents an image on disk. It can create thumbnail and full image representations.
class ImageFile {

// MARK: Properties

    // date the image file was last updated from its URL source
    fileprivate(set) var dateLastUpdated = Date()

    // url the receiver references
    fileprivate(set) var fileURL: Foundation.URL

    // filename of the receiver, with the extension
    var fileName: String? {
        return fileURL.lastPathComponent
    }

    // filename of the receiver, without the extension, suitable for presentation names
    var fileNameExcludingExtension: String? {
        return fileURL.deletingPathExtension().lastPathComponent
    }

    // uniform type identifier of URL
    var fileType: String = ""

    // thumbnail for image with file url
    fileprivate(set) var thumbnail: NSImage? = nil
    // thumbnail size
    fileprivate let thumbSize = CGSize(width: 216, height: 162)

// MARK: Initializer

    init(with url: Foundation.URL, and fileType: String) {
        // image from URL
        self.fileURL = url
        self.fileType = fileType
        switch fileType {
        case "com.adobe.pdf":
            do {
                let pdfData = try Data(contentsOf: url)
                if let pdfImageRep = NSPDFImageRep(data: pdfData) {
                    // make image for first page
                    pdfImageRep.currentPage = 0
                    let imageRect = NSRectToCGRect(pdfImageRep.bounds)
                    let image = NSImage(size: imageRect.size)
                    image.addRepresentation(pdfImageRep)

                    image.lockFocus()
                    // fill bitmap with white background
                    NSColor.white.setFill()
                    NSRectFill(imageRect)
                    // draw image over the background
                    image.draw(in: imageRect)
                    image.unlockFocus()

                    thumbnail = sizeImage(image, into: thumbSize)
                }
            }
            catch let error as NSError {
                print("error reading pdf: \(error.localizedDescription) in \(error.domain)")
            }
        case "com.adobe.encapsulated-postscript":
            // eps documents have per definitionem one page
            do {
                let epsData = try Data(contentsOf: url)
                if let epsImageRep = NSEPSImageRep(data: epsData) {
                    let imageRect = NSRectToCGRect(epsImageRep.boundingBox)
                    let image = NSImage(size: imageRect.size)
                    image.addRepresentation(epsImageRep)
                    thumbnail = sizeImage(image, into: thumbSize)
                }
            }
            catch let error as NSError {
                print("error reading eps: \(error.localizedDescription) in \(error.domain)")
            }
        default:
            // public.image is remaining
            let image = NSImage(byReferencing: fileURL)
            thumbnail = sizeImage(image, into: thumbSize)
        }
    }

    // adapted from <https://blog.alexseifert.com/2016/06/18/resize-an-nsimage-proportionately-in-swift/>
    func sizeImage(_ image:NSImage, into size: CGSize) -> NSImage? {
        var imageRect = CGRect.zero
        imageRect.size = image.size
        let imageRef = image.cgImage(forProposedRect: &imageRect, context: nil, hints: [:])
        let imageAspectRatio = image.size.width / image.size.height
        // resize dimensions for new image
        var newSize = size
        if (imageAspectRatio > 1.0) {
            newSize.height = size.width / imageAspectRatio
        }
        else {
            newSize.width = size.height * imageAspectRatio
        }
        // Create new image from CGImage using new size
        return NSImage(cgImage: imageRef!, size: newSize)
    }
}

// image files are equivalent if their URLs are equivalent.
extension ImageFile: Hashable {
    var hashValue: Int {
        return fileURL.hashValue
    }
}

extension ImageFile: Equatable { }
// implement equatable protocol to use index(of: )
func ==(lhs: ImageFile, rhs: ImageFile) -> Bool {
    return lhs.fileURL == rhs.fileURL
}
