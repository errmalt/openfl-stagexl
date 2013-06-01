package flash.display;


import flash.geom.Rectangle;


class Bitmap extends DisplayObject {
  
	
	public var bitmapData:BitmapData;
	public var pixelSnapping:PixelSnapping;
	public var clipRectangle:Rectangle;
	
	
	public function new (bitmapData:BitmapData = null, pixelSnapping = null) {
		
		this.bitmapData = bitmapData;
		
		if (pixelSnapping != null) {
			
			this.pixelSnapping = pixelSnapping;
			
		} else {
			
			this.pixelSnapping = PixelSnapping.AUTO;
			
		}
		
	}
	
	
	public function getBoundsTransformed (matrix:Matrix, returnRectangle:Rectangle = null):Rectangle {
		
		var width = (bitmapData != null) ? bitmapData.width : 0;
		var height = (bitmapData != null) ? bitmapData.height : 0;
		
		return _getBoundsTransformedHelper (matrix, width, height, returnRectangle);
		
	}
	
	
	public function hitTestInput (localX:Float, localY:Float):DisplayObject {
		
		if (bitmapData != null && localX >= 0.0 && localY >= 0.0 && localX < bitmapData.width && localY < bitmapData.height)
			return this;
		
		return null;
		
	}
	
	
	public function render (renderState:RenderState):Void {
		
		if (bitmapData == null) return;
		
		if (clipRectangle == null) {
			
			bitmapData.render (renderState);
			
		} else {
			
			bitmapData.renderClipped (renderState, clipRectangle);
			
		}
		
	}
	

}