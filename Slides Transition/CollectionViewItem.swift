//
//  CollectionViewItem.swift
//  Slides Transition
//
//  Created by Erich Küster on December 16, 2016
//  Copyright © 2016 Erich Küster. All rights reserved.
//

import Cocoa

class CollectionViewItem: NSCollectionViewItem {

    // 1
    var imageFile: ImageFile? {
        didSet {
            guard isViewLoaded
                else { return }
            imageView?.image = imageFile?.thumbnail
            textField?.stringValue = (imageFile?.fileName)!
        }
    }
    // 2
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.lightGray.cgColor
        view.layer?.borderWidth = 0.0
        view.layer?.borderColor = NSColor.red.cgColor

        // If the set image view is a DoubleActionImageView, set the double click handler
        if let imageView = imageView as? DoubleActionImageView {
            imageView.doubleAction = #selector(CollectionViewItem.handleDoubleClickInImageView(_:))
            imageView.target = self
        }
    }
    // 3
    func setHighlight(_ selected: Bool) {
        view.layer?.borderWidth = selected ? 2.0 : 0.0
    }

// MARK: IBActions
    @IBAction func handleDoubleClickInImageView(_ sender: AnyObject?) {
        // On double click, show the image in a new view
        NotificationCenter.default.post(name: Notification.Name(rawValue: "com.image.doubleClicked"), object: self.imageFile)
    }

}
