class MustachioViewController < UIViewController
  def loadView
    @debug = false

    self.view = UIView.alloc.initWithFrame(UIScreen.mainScreen.applicationFrame)
    view.backgroundColor = UIColor.redColor if @debug

    @imageView = UIImageView.alloc.initWithFrame(view.bounds)
    @imageView.contentMode = UIViewContentModeScaleAspectFit
    @imageView.userInteractionEnabled = true
    view.addSubview(@imageView)

    toolbar = UIToolbar.new
    toolbar.barStyle = UIBarStyleBlack
    #toolbar.translucent = true

    # TODO weird one pixel offset, not thinking about this too much more right now
    toolbar.frame = CGRectMake(0, view.bounds.size.height-44+1, view.bounds.size.width, 44)
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin
    toolbar.items = [
      toolbarItem(UIBarButtonSystemItemCamera, target:self, action:'presentImagePickerController:'),
      toolbarSpaceItem,
      toolbarItem(UIBarButtonSystemItemAction, target:self, action:'tweetPhoto:'),
      toolbarSpaceItem,
      toolbarItem(UIBarButtonSystemItemSave,   target:self, action:'savePhoto:'),
    ]
    view.addSubview(toolbar)
  end

  def shouldAutorotateToInterfaceOrientation(orientation)
    orientation == UIInterfaceOrientationPortrait
  end

  def presentImagePickerController(sender)
    # TODO check that images can be loaded in some way.
    #UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypePhotoLibrary)
    #UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypeCamera)
    #UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceTypeSavedPhotosAlbum)

    imagePickerController = UIImagePickerController.new
    imagePickerController.delegate = self
    #imagePickerController.allowsEditing = true
    presentModalViewController(imagePickerController, animated:true)
  end

  def imagePickerController(imagePickerController, didFinishPickingMediaWithInfo:info)
    if @imageView.image = info[UIImagePickerControllerEditedImage] || info[UIImagePickerControllerOriginalImage]
      mustachify
    end
    dismissModalViewControllerAnimated(true)
  end

  def tweetPhoto(sender)
    puts "TWEET"
  end

  def savePhoto(sender)
    puts "SAVE"
  end

  def mustachify
    return unless @imageView && @imageView.image

    # Remove previous mustaches.
    @imageView.subviews.each { |v| v.removeFromSuperview }

    # CoreImage used a coordinate system which is flipped on the Y axis
    # compared to UIKit. Also, a UIImageView can return an image larger than
    # itself. To properly translate points, we use an affine transform.
    transform = CGAffineTransformMakeScale(@imageView.bounds.size.width / @imageView.image.size.width, -(@imageView.bounds.size.height / @imageView.image.size.height))
    transform = CGAffineTransformTranslate(transform, 0, -@imageView.image.size.height)

    image = CIImage.imageWithCGImage(@imageView.image.CGImage)
    @detector ||= CIDetector.detectorOfType(CIDetectorTypeFace, context:nil, options: { CIDetectorAccuracy: CIDetectorAccuracyHigh })
    @detector.featuresInImage(image).each do |feature|
      # We need the mouth and eyes positions to determine where the mustache
      # should be added.
      next unless feature.hasMouthPosition and feature.hasLeftEyePosition and feature.hasRightEyePosition

      if @debug
        [feature.leftEyePosition,feature.rightEyePosition,feature.mouthPosition].each do |pt|
          v = UIView.alloc.initWithFrame CGRectMake(0, 0, 20, 20)
          v.backgroundColor = UIColor.greenColor.colorWithAlphaComponent(0.2)
          pt = CGPointApplyAffineTransform(pt, transform)
          v.center = pt
          @imageView.addSubview(v)
        end
      end

      # Create the mustache view.
      mustacheView = UIImageView.alloc.init
      mustacheView.image = UIImage.imageNamed('mustache')
      mustacheView.contentMode = UIViewContentModeScaleAspectFit

      # Compute its location and size, based on the position of the eyes and
      # mouth. 
      w = feature.bounds.size.width
      h = feature.bounds.size.height / 5
      x = (feature.mouthPosition.x + (feature.leftEyePosition.x + feature.rightEyePosition.x) / 2) / 2 - w / 2
      y = feature.mouthPosition.y
      mustacheView.frame = CGRectApplyAffineTransform([[x, y], [w, h]], transform)

      # Apply a rotation on the mustache, based on the face inclination.
      mustacheAngle = Math.atan2(feature.leftEyePosition.x - feature.rightEyePosition.x, feature.leftEyePosition.y - feature.rightEyePosition.y) + Math::PI/2
      mustacheView.transform = CGAffineTransformMakeRotation(mustacheAngle) 

      @imageView.addSubview(mustacheView)
    end
  end

  private

  def toolbarSpaceItem
    toolbarItem(UIBarButtonSystemItemFlexibleSpace, target:nil, action:nil)
  end

  def toolbarItem(type, target:target, action:action)
    item = UIBarButtonItem.alloc.initWithBarButtonSystemItem(type, target:target, action:action)
    item.style = UIBarButtonItemStyleBordered if target
    item
  end
end
