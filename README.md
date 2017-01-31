# Swift-Slides-Transition
Collection View Transition to Image View ( Cocoa / macOS )

Show images from a directory or zipped file in a Collection View

On double-click perform a transition into an Image View for a single image
and vice versa

The development environment now is Xcode 8 under OS X 10.12 aka macOS Sierra.


The storyboard method ( main.storyboard ) is used for coupling AppDelegate, WindowsController and three ViewControllers together. The transition between two view controllers is carried out by a storyboard segue.

You will find some useful methods to exchange data between all these objects. I wrote this program to become familiar with the Swift language and to get a feeling how to display images on the screen. It contains a lot of useful stuff regarding handling of windows, menus, images, segues, resizing images for thumbnails and so on.

The program is written in Swift 3 and respects the latest changes.


Usage:
When starting the program you can choose a folder ( preferably containing images ) which afterwards are displayed in a collection view. The items of the collection view can be dragged as you like, you can even drag an item onto the desktop or in another folder. It is possible in the same manner to drag an item from the desktop or the finder into the collection view where it is shown immediately.

When you decide to look more intensely into an image, double click on the single item representing it. Then a transition from the collection view to a single image view is executed, in which the image is shown. The image is scaled so that it fits best into the main Screen. Clicking on the "Back" button will lead back to the collection view.

Both views are supporting now the "Full Screen Mode" of macOS.

The image files can be of different kind, including besides the normal types also EPS, multipage TIFFs and PDF documents.

The sequence of the shown images is controlled by the cursor keys ( look into the menu "View", too ):

- back space : return to collection view

- left : previous image

- right : next image

in case of multi-page TIFFs or PDFs use

- up : previous page of document

- down : next page of document

The program does fill the recent documents entries under the "File" menu und you can use them in the normal manner.

There is a link in the source code to the ZipZap framework

- see <https://github.com/pixelglow/zipzap>

Thanks to this framework also images from a zipped archive are read and stored in expanded form in a temporary folder. Thus they can be displayed in the collection view.

The program was inspired by an excellent article written by John Marstall

- see <http://theiconmaster.com/2015/03/transitioning-between-view-controllers-in-the-same-window-with-swift-mac/>

My thanks go to the Stack Overflow sites. Without the folks there and whose answers this program would not exist.

Disclaimer: Use the program for what purpose you like, but hold in mind, that I will not be responsible for any harm it will cause to your hard- or software. It was your decision to use this piece of software.
