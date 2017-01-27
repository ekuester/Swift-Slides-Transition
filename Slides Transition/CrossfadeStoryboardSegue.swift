//
//  CrossfadeStoryboardSegue.swift
//  Slides Transition
//
//  Created by Erich Küster on December 16, 2016
//  Copyright © 2016 Erich Küster. All rights reserved.
//

import Cocoa

class CrossfadeStoryboardSegue: NSStoryboardSegue {

    // make references to the source controller and destination controller
    override init(identifier: String?, source sourceController: Any, destination destinationController: Any) {
        var myIdentifier: String
        if identifier == nil {
            myIdentifier = ""
        } else {
            myIdentifier = identifier!
        }
        super.init(identifier: myIdentifier, source: sourceController, destination: destinationController)
    }

    override func perform() {
        // build from-to and parent-child view controller relationships
        let sourceViewController  = self.sourceController as! NSViewController
        let destinationViewController = self.destinationController as! NSViewController
        let containerViewController = sourceViewController.parent! as! ContainerViewController
        // add destinationViewController as child
        containerViewController.insertChildViewController(destinationViewController, at: 1)
        // prepare for animation
        sourceViewController.view.wantsLayer = true
        destinationViewController.view.wantsLayer = true

        // prepare additional items for menu view
        let upArrowKey = unichar(NSUpArrowFunctionKey)
        let upArrow = String(utf16CodeUnits: [upArrowKey], count: 1)
        let sheetUpItem = NSMenuItem(title: "Page Up", action: #selector(containerViewController.sheetUp(_:)), keyEquivalent: upArrow)
        sheetUpItem.keyEquivalentModifierMask = []
        let downArrowKey = unichar(NSDownArrowFunctionKey)
        let downArrow = String(utf16CodeUnits: [downArrowKey], count: 1)
        let sheetDownItem = NSMenuItem(title: "Page Down", action: #selector(containerViewController.sheetDown(_:)), keyEquivalent: downArrow)
        sheetDownItem.keyEquivalentModifierMask = []
        let rightArrowKey = unichar(NSRightArrowFunctionKey)
        let rightArrow = String(utf16CodeUnits: [rightArrowKey], count: 1)
        let nextImageItem = NSMenuItem(title: "Next Image", action: #selector(containerViewController.nextImage(_:)), keyEquivalent: rightArrow)
        nextImageItem.keyEquivalentModifierMask = []
        let leftArrowKey = unichar(NSLeftArrowFunctionKey)
        let leftArrow = String(utf16CodeUnits: [leftArrowKey], count: 1)
        let previousImageItem = NSMenuItem(title: "Previous Image", action: #selector(containerViewController.previousImage(_:)), keyEquivalent: leftArrow)
        previousImageItem.keyEquivalentModifierMask = []

        // perform transition animating with NSViewControllerTransitionOptions
        let containerWindow = containerViewController.view.window!
        var contentRect = NSRect.zero
        var targetRect = containerViewController.mainContent!
        if let sourceController = self.sourceController as? SourceViewController {
            // show single image
            containerViewController.transition(from: sourceViewController, to: destinationViewController, options: [NSViewControllerTransitionOptions.crossfade], completionHandler: nil)

            // lose the not longer required sourceViewController, it's no longer visible
            containerViewController.removeChildViewController(at: 0)

            let imageIndex = sourceController.fileIndex
            containerViewController.imageViewfromImageIndex(imageIndex)
        }
        else {
            // show collection view again
            containerViewController.transition(from: sourceViewController, to: destinationViewController, options: [NSViewControllerTransitionOptions.crossfade, .slideUp], completionHandler: nil)
            containerWindow.setTitleWithRepresentedFilename("Show Collection View")
            //resize view controller
            sourceViewController.view.animator().frame = targetRect
            
            //resize and shift window
            let currentFrame = containerWindow.frame
            let currentRect = NSRectToCGRect(currentFrame)
//            targetRect.origin = containerViewController.mainViewFrameOrigin
            // shift parameters, calculate frame rect of container view
            let horizontalChange = (targetRect.size.width - currentRect.size.width)/2
            let verticalChange = (targetRect.size.height - currentRect.size.height)
            contentRect = NSRect(x: currentRect.origin.x - horizontalChange, y: currentRect.origin.y - verticalChange, width: targetRect.size.width, height: targetRect.size.height)
            // set frame for container view window
            let frameRect = containerWindow.frameRect(forContentRect: contentRect)
            containerWindow.setFrame(frameRect, display: true, animate: true)
            
            // lose the not longer required sourceViewController, it's no longer visible
            containerViewController.removeChildViewController(at: 0)
        }
        // correct view menu items
        let viewMenu = NSApp.mainMenu!.item(withTitle: "View")
        if destinationViewController is SourceViewController {
            // remove items from submenu "View"
            for index in (3...6).reversed() {
                viewMenu?.submenu?.removeItem(at: index)
            }
        }
        else {
            // add items to submenu "View"
            viewMenu?.submenu?.insertItem(sheetUpItem, at: 3)
            viewMenu?.submenu?.insertItem(sheetDownItem, at: 4)
            viewMenu?.submenu?.insertItem(nextImageItem, at: 5)
            viewMenu?.submenu?.insertItem(previousImageItem, at: 6)
        }
    }

}
