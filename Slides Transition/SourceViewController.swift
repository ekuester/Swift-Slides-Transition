//
//  SourceViewController.swift
//  Swift Slides Transition
//
//  Created by Erich Küster on December 16, 2016
//  Copyright © 2016 Erich Küster. All rights reserved.
//

import AppKit
import Cocoa
import ZipZap

// before the latest Swift 3, you could compare optional values
// Swift migrator solves that problem by providing a custom < operator
// which takes two optional operands and therefore "restores" the old behavior.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

class SourceViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {

// MARK: - Properties

    @IBOutlet weak var scrollView: NSScrollView!    

    var collectionView: NSCollectionView!
    var containerViewController: ContainerViewController!
    var defaultSession: URLSession!
    var draggedItemsIndexPathSet: Set<IndexPath>!
    var entryIndex: Int = -1
    var fileIndex: Int = -1
    var imageDoubleClickedObserver: NSObjectProtocol!
    var imageFolderURL: URL!
    var imageFiles: [ImageFile] = []
    var recentItemsObserver: NSObjectProtocol!
    var sharedDocumentController: NSDocumentController!

// MARK: - Overrides

    override func viewDidLoad() {
        super.viewDidLoad()
        // to use recent documents
        sharedDocumentController = NSDocumentController.shared()
        view.wantsLayer = true
        collectionView = scrollView.documentView as! NSCollectionView
        let config = URLSessionConfiguration.default
        self.defaultSession = URLSession(configuration: config)
        containerViewController = self.parent as! ContainerViewController!
        imageDoubleClickedObserver = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "com.image.doubleClicked"), object: nil, queue: nil, using: openImage)
        // notification if file from recent documents should be opened
        recentItemsObserver = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "com.image.openview"), object: nil, queue: nil, using: openView)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // now window exists, set first responder
        view.window?.makeFirstResponder(self)
        if let imageFiles = containerViewController.imageFiles {
            fileIndex = 0
            self.imageFiles = imageFiles
            containerViewController.imageFiles?.removeAll()
        }
        processCollectionView()
    }

    override func viewWillDisappear() {
        NotificationCenter.default.removeObserver(imageDoubleClickedObserver)
        NotificationCenter.default.removeObserver(recentItemsObserver)
    }

// MARK: - functions

    func urlFromDialog(zipAllowed: Bool) {
        // generate File Open Dialog class
        let imageDialog: NSOpenPanel = NSOpenPanel()
        imageDialog.prompt = "Choose"
        imageDialog.title = NSLocalizedString("Select an URL for folder or ZIP archive", comment: "title of open panel")
        imageDialog.message = "Choose a directory or zip archive containing images:"
        imageDialog.directoryURL = imageFolderURL
        // allow only one directory or file at the same time
        imageDialog.allowsMultipleSelection = false
        imageDialog.canChooseDirectories = true
        if zipAllowed {
            imageDialog.allowedFileTypes = ["zip"]
            imageDialog.canChooseFiles = true
        }
        else {
            imageDialog.canChooseFiles = false
        }
        imageDialog.showsHiddenFiles = false
        imageDialog.beginSheetModal(for: view.window!, completionHandler: { response in
            // NSFileHandlingPanelOKButton is Int(1)
            guard response == NSFileHandlingPanelOKButton
                else {
                    // Cancel pressed, use old collection view if any
                    guard !self.imageFiles.isEmpty
                        else { return }
                    self.fileIndex = 0
                    self.processCollectionView()
                    // never reached just to satisfy compiler
                    return
            }
            DispatchQueue.main.async {
                self.fileIndex = 0
                    if let url = imageDialog.url {
                        // note url in recent documents
                        self.sharedDocumentController.noteNewRecentDocumentURL(url)
                        // process folder or zip archive from existing URL(s)
                        if zipAllowed {
                            let files = self.imageFilesFromZIP(at: url)
                            if files.isEmpty { return }
                            self.imageFiles = files
                        }
                        else {
                            self.imageFolderURL = url
                            let files = self.imageFilesFromFolder(at: url)
                            if files.isEmpty { return }
                            self.imageFiles = files
                        }
                    self.processCollectionView()
                }
            }
        })
    }

    // put the contents of zipped archive file into temporary files
    func imageFilesFromZIP(at url: URL) -> [ImageFile] {
        var temporaryFiles: [ImageFile] = []
        do {
            entryIndex = -1
            let imageArchive = try ZZArchive(url: url)
            var temporaryFileURLs: [URL] = []
            let fileManager = FileManager.default
            for entry in imageArchive.entries {
                let temporaryFileURL = fileManager.temporaryDirectory.appendingPathComponent(entry.fileName)
                do {
                    let zipData = try entry.newData()
                    do {
                        try zipData.write(to: temporaryFileURL, options: .atomicWrite)
                    }
                    catch let error as NSError {
                        Swift.print("ZipZap error: could not write temporary file in \(error.domain)")
                        continue
                    }
                }
                catch let error as NSError {
                    Swift.print("Error: no valid data in \(error.domain)")
                    continue
                }
                temporaryFileURLs.append(temporaryFileURL)
            }
            for case let temporaryFileURL in temporaryFileURLs {
                // append only if valid image file
                let ending = temporaryFileURL.pathExtension
                let unmanagedFileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ending as CFString, nil)
                // filter out eps or pdf document
                let fileType = unmanagedFileUTI?.takeRetainedValue() as! String
                if ((fileType == "com.adobe.pdf") || (fileType == "com.adobe.encapsulated-postscript")) {
                    let file = ImageFile(with: temporaryFileURL, and: fileType)
                    temporaryFiles.append(file)
                    entryIndex += 1
                }
                guard UTTypeConformsTo((unmanagedFileUTI?.takeRetainedValue())!, kUTTypeImage)
                    else { continue }
                let file = ImageFile(with: temporaryFileURL, and: "public.image")
                temporaryFiles.append(file)
                entryIndex += 1
            }
        } catch let error as NSError {
            entryIndex = -1
            Swift.print("ZipZap error: could not open archive in \(error.domain)")
        }
        return temporaryFiles
    }

    func imageFilesFromFolder(at url: URL) -> [ImageFile] {
        var files: [ImageFile] = []
        let fileManager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions =
            [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]
        // Swift 3 wants set of URLResourceKey not array
        let resourceValueKeys: Set<URLResourceKey> = [.isRegularFileKey, .typeIdentifierKey]
        guard let directoryEnumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .typeIdentifierKey], options: options, errorHandler: { url, error in
            print("`directoryEnumerator` error: \(error).")
            // continue after error
            return true
        })
            else { return files }
        for case let url as URL in directoryEnumerator {
            do {
                // to use the simplified access to resource values you must define
                let resourceValues = try url.resourceValues(forKeys: resourceValueKeys)
                guard resourceValues.isRegularFile!
                    else { continue }
                guard let fileType = resourceValues.typeIdentifier
                    else { continue }
                // at this point only regular files are remaining
                // filter out zip archive
                if fileType == "public.zip-archive" {
                    let temporaryFiles = imageFilesFromZIP(at: url)
                    // check if zip archive contains images
                    guard !temporaryFiles.isEmpty
                        else { continue }
                    files.append(contentsOf: temporaryFiles)
                    continue
                }
                // filter out eps or pdf document
                if ((fileType == "com.adobe.pdf") || (fileType == "com.adobe.encapsulated-postscript")) {
                    let file = ImageFile(with: url, and: fileType)
                    files.append(file)                    
                }
                // after all only images are remaining and should be added as "public.image"
                guard UTTypeConformsTo(fileType as CFString, kUTTypeImage)
                    else { continue }
                let file = ImageFile(with: url, and: "public.image")
                files.append(file)
            }
            catch {
                print("Unexpected error occured: \(error).")
            }
        }
        return files
    }

    func processCollectionView() {
        collectionView.removeFromSuperviewWithoutNeedingDisplay()
        if (fileIndex < 0) {
            // get a single url for a folder or a zip archive with images
            urlFromDialog(zipAllowed: false)
        }
        else {
            if (collectionView.collectionViewLayout == nil) {
                configureCollectionView()
                registerForDragAndDrop()
                collectionView.layer?.backgroundColor = NSColor.black.cgColor
            }
            else {
                collectionView.reloadData()
            }
            scrollView.documentView = self.collectionView
            // select first item of collection view, not needed in the moment
            // collectionView(collectionView, didSelectItemsAt: [IndexPath(item: 0, section: 0)])
        }
    }

    private func configureCollectionView() {
        // item size 216 x 162 (= 4 : 3) for image  and 216 x 22 for Label, 216 x 184 pixel
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 216.0, height: 184.0)
        flowLayout.sectionInset = EdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        flowLayout.minimumInteritemSpacing = 20.0
        flowLayout.minimumLineSpacing = 20.0
        collectionView.collectionViewLayout = flowLayout
    }

    func insertFilesAtIndexPathFrom (_ files: [ImageFile], atIndexPath: IndexPath) {
        var indexPaths: Set<IndexPath> = []
        // section will be always zero in the moment
        let section = atIndexPath.section
        fileIndex = atIndexPath.item
        
        for file in files {
            imageFiles.insert(file, at: fileIndex)
            let actualIndexPath = IndexPath(item: fileIndex, section: section)
            indexPaths.insert(actualIndexPath)
            fileIndex += 1
        }
        
        NSAnimationContext.current().duration = 1.0;
        collectionView.animator().insertItems(at: indexPaths)
    }

    func removeFromImageFilesAt(_ indexPath: IndexPath) -> ImageFile {
        // section will be always zero in the moment
        return (imageFiles.remove(at: indexPath.item))
    }

    func moveFile(_ fromIndexPath: IndexPath, toIndexPath: IndexPath) {
        let itemBeingDragged = removeFromImageFilesAt(fromIndexPath)
        insertFilesAtIndexPathFrom([itemBeingDragged], atIndexPath: toIndexPath)
    }

    func registerForDragAndDrop() {
        // changed for Swift 3
        collectionView.register(forDraggedTypes: [NSURLPboardType])
        // from internal we always move
        collectionView.setDraggingSourceOperationMask(NSDragOperation.every, forLocal: true)
        // from external we always add
        collectionView.setDraggingSourceOperationMask(NSDragOperation.every, forLocal: false)
    }

// MARK: following are the actions for menu entries
    @IBAction func openDocument(_ sender: NSMenuItem) {
        // open new file(s)
        fileIndex = -1
        processCollectionView()
    }

    @IBAction func openZIP(_ sender: NSMenuItem) {
        // open ZIP archive
        fileIndex = -1
        urlFromDialog(zipAllowed: true)
    }

// MARK: - NSCollectionViewDataSource
    // 1
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        // we have only one section
        return 1
    }
    // 2
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        // we are working only with an one-dimensional array of image files
        return (imageFiles.count)
    }
    // 3
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: "CollectionViewItem", for: indexPath)
        guard let collectionViewItem = item as? CollectionViewItem
            else { return item }
        // if you wnat to use more than one section, code has to be changed
        fileIndex = indexPath.item
        collectionViewItem.imageFile = imageFiles[fileIndex]
        return item
    }

// MARK: - NSCollectionViewDelegate
    // 1
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // if you are using more than one selected item, code has to be changed
        for indexPath in indexPaths {
            guard let item = collectionView.item(at: indexPath)
                else { continue }
            let collectionItem = item as! CollectionViewItem
            collectionItem.setHighlight(true)
        }
    }
    // 2
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        for indexPath in indexPaths {
            guard let item = collectionView.item(at: indexPath)
                else { continue }
            (item as! CollectionViewItem).setHighlight(false)
        }
    }
    // 3
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexes: IndexSet, with event: NSEvent) -> Bool {
        return true
    }
    // 4
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        fileIndex = indexPath.item
        let imageFile = imageFiles[fileIndex]
        return imageFile.fileURL.absoluteURL as NSPasteboardWriting?
    }
    // 5
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        draggedItemsIndexPathSet = indexPaths
    }
    // 6
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionViewDropOperation>) -> NSDragOperation {
        if proposedDropOperation.pointee == NSCollectionViewDropOperation.on {
            proposedDropOperation.pointee = NSCollectionViewDropOperation.before
        }
        if draggedItemsIndexPathSet == nil {
            return NSDragOperation.copy
        } else {
            return NSDragOperation.move
        }
    }
    // 7
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionViewDropOperation) -> Bool {
        if draggedItemsIndexPathSet != nil {
            // move operation, supports only one item in the moment
            let indexPathOfFirstItembeingDragged = draggedItemsIndexPathSet.first!
            var toIndexPath: IndexPath
            if indexPathOfFirstItembeingDragged.compare(indexPath) == .orderedAscending {
                toIndexPath = IndexPath(item: indexPath.item-1, section: indexPath.section)
            } else {
                toIndexPath = IndexPath(item: indexPath.item, section: indexPath.section)
            }

            moveFile(indexPathOfFirstItembeingDragged, toIndexPath: toIndexPath)

            NSAnimationContext.current().duration = 1.0;
            collectionView.animator().moveItem(at: indexPathOfFirstItembeingDragged, to: toIndexPath)
        }
        else {
            // copy operation
            // assume drop source is from finder and may be more than one file
            var files = [ImageFile]()
            draggingInfo.enumerateDraggingItems(options: .concurrent, for: collectionView, classes: [NSURL.self], searchOptions: [NSPasteboardURLReadingFileURLsOnlyKey: true], using: {(draggingItem, idx, stop) in
                // only regular file urls are accepted
                let resourceValueKeys: Set<URLResourceKey> = [.typeIdentifierKey]
                if let url = draggingItem.item as? URL {
                    // check file type
                    do {
                        // to use the simplified access to resource values you must define
                        let resourceValues = try url.resourceValues(forKeys: resourceValueKeys)
                        if let fileType = resourceValues.typeIdentifier {
                            // filter out pdf or eps document
                            if ((fileType == "com.adobe.pdf") || (fileType == "com.adobe.encapsulated-postscript")) {
                                let file = ImageFile(with: url, and: fileType)
                                files.append(file)
                            }
                            else {
                                // look if public image uti
                                if UTTypeConformsTo(fileType as CFString, kUTTypeImage) {
                                    let file = ImageFile(with: url, and: "public.image")
                                    files.append(file)
                                }
                            }
                        }
                    }
                    catch {
                        print("Unexpected error occured: \(error).")
                    }
                }
            })
            if !files.isEmpty {
                // files will only be shown, not copied really
                insertFilesAtIndexPathFrom(files, atIndexPath: indexPath)
            }
        }
        return true
    }

// MARK: - notification from collectionviewitem
    func openImage(_ notification: Notification) {
        // invoked when an item of the collectionview is double clicked
        if let imageFile = notification.object as? ImageFile {
            guard let imageIndex = self.imageFiles.index(of: imageFile)
                else { return }
            self.fileIndex = imageIndex
            containerViewController.imageFiles = self.imageFiles
            containerViewController.imageFileIndex = imageIndex
            self.imageFiles.removeAll()
            self.performSegue(withIdentifier: "ShowImageSegue", sender: self)
        }
    }

// MARK: - notification from AppDelegate
    // analogous to <https://www.brandpending.com/2016/02/21/opening-and-saving-custom-document-types-from-a-swift-cocoa-application/>
    func openView(_ notification: Notification) {
        // invoked when an item of recent documents is clicked
        let resourceValueKeys: Set<URLResourceKey> = [.typeIdentifierKey]
        if let url = notification.object as? URL {
            // process folder or zip archive from existing URL(s)
            do {
                // to use the simplified access to resource values you must define
                let resourceValues = try url.resourceValues(forKeys: resourceValueKeys)
                guard let fileType = resourceValues.typeIdentifier
                    else { return }
                // filter out zip archive
                if fileType == "public.zip-archive" {
                    let files = self.imageFilesFromZIP(at: url)
                    if files.isEmpty { return }
                    self.imageFiles = files
                }
                else {
                    self.imageFolderURL = url
                    let files = self.imageFilesFromFolder(at: url)
                    if files.isEmpty { return }
                    self.imageFiles = files
                }
                self.processCollectionView()
            }
            catch {
                print("Unexpected error occured: \(error).")
                
            }
        }
    }
}
