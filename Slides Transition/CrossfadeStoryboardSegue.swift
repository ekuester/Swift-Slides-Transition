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
        let titles = ["Back", "Page Up", "Page Down", "Next Image", "Previous Image"]
        // strange enough, you do not need the class prefix containerViewController
        let selectors = [
            NSSelectorFromString("backToCollection:"),
            NSSelectorFromString("sheetUp:"),
            NSSelectorFromString("sheetDown:"),
            NSSelectorFromString("nextImage:"),
            NSSelectorFromString("previousImage:")
        ]
        let keys = [NSBackspaceCharacter, NSUpArrowFunctionKey, NSDownArrowFunctionKey, NSRightArrowFunctionKey, NSLeftArrowFunctionKey]

        var menuItems: [NSMenuItem] = [NSMenuItem.separator()]
        for (i, selector) in zip(0...4, selectors) {
            let keyChar = UniChar(keys[i])
            let keyEquivalent = String(utf16CodeUnits: [keyChar], count: 1)
            let menuItem = NSMenuItem(title: titles[i], action: selector, keyEquivalent: keyEquivalent)
            menuItem.keyEquivalentModifierMask = []
            menuItems.append(menuItem)
        }
        // perform transition animating with NSViewControllerTransitionOptions
        let containerWindow = containerViewController.view.window!
        var contentRect = NSRect.zero
        let targetRect = containerViewController.mainContent!
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
            for index in (2...7).reversed() {
                viewMenu?.submenu?.removeItem(at: index)
            }
        }
        else {
            // add items to submenu "View"
            for (menuEntry, index) in zip(menuItems, 2...7) {
                viewMenu?.submenu?.insertItem(menuEntry, at: index)
            }
        }
    }
}
