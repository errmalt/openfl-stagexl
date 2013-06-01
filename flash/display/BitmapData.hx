package flash.display;


import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.ImageElement;
import js.Browser;


class BitmapData implements IBitmapDrawable {
	
	
	private var _width:Int;
	private var _height:Int;
	private var _transparent:Bool;
	private var _pixelRatio:Float;
	private var _pixelRatioSource:Float;
	
	private var _renderMode:Int;
	private var _destinationWidth:Int;
	private var _destinationHeight:Int;
	private var _destinationX:Int;
	private var _destinationY:Int;
	private var _sourceX:Int;
	private var _sourceY:Int;
	private var _sourceWidth:Int;
	private var _sourceHeight:Int;
	
	private var _source:CanvasImageSource;
	private var _context:CanvasRenderingContext2D;
	
	public static var defaultLoadOptions = new BitmapDataLoadOptions ();
	
	
	public function new (width:Int, height:Int, transparent = true, fillColor = 0xFFFFFFFF, pixelRatio = 1.0) {
		
		_width = width;
		_height = height;
		_transparent = transparent;
		_pixelRatio = pixelRatio;
		_pixelRatioSource = _pixelRatio / _backingStorePixelRatio;
		
		_renderMode = (Math.abs (1.0 - _pixelRatioSource) < 0.001) ? 0 : 1;
		_destinationX = 0;
		_destinationY = 0;
		_destinationWidth = _width;
		_destinationHeight = _height;
		_sourceX = 0;
		_sourceY = 0;
		_sourceWidth = Math.ceil (_width * _pixelRatioSource);
		_sourceHeight = Math.ceil (_height * _pixelRatioSource);
		
		// TODO: Don't require canvas creation when using static "from" function
		
		var canvas:CanvasElement = Browser.document.createElement ("canvas");
		canvas.width = _sourceWidth;
		canvas.height = _sourceHeight;
		
		_source = canvas;
		_context = canvas.context2D;
		_context.fillStyle = _transparent ? _color2rgba (fillColor) : _color2rgb (fillColor);
		_context.fillRect (0, 0, _sourceWidth, _sourceHeight);
		
	}
	
	
	public static function fromImageElement (imageElement:ImageElement, pixelRatio = 1.0):BitmapData {
		
		var imageWidth = imageElement.naturalWidth.toInt();
		var imageHeight = imageElement.naturalHeight.toInt();
		
		var bitmapData = new BitmapData (Math.round (imageWidth / pixelRatio), Math.round (imageHeight / pixelRatio), true);
		
		bitmapData._pixelRatio = pixelRatio;
		bitmapData._pixelRatioSource = _pixelRatio;
		
		bitmapData._renderMode = (Math.abs (1.0 - _pixelRatioSource) < 0.001) ? 0 : 1;
		bitmapData._sourceWidth = imageWidth;
		bitmapData._sourceHeight = imageHeight;
		
		bitmapData._source = imageElement;
		
		return bitmapData;
		
	}
	
	
	public static function fromTextureAtlasFrame (textureAtlasFrame:TextureAtlasFrame):BitmapData {
		
		var source = textureAtlasFrame.textureAtlas._bitmapData;
		
		var bitmapData = new BitmapData (textureAtlasFrame.originalWidth, textureAtlasFrame.originalHeight, true);
		
		bitmapData._pixelRatio = source._pixelRatio;
		bitmapData._pixelRatioSource = source._pixelRatioSource;
		
		bitmapData._renderMode = textureAtlasFrame.rotated ? 3 : 2;
		bitmapData._destinationX = textureAtlasFrame.offsetX;
		bitmapData._destinationY = textureAtlasFrame.offsetY;
		bitmapData._destinationWidth = textureAtlasFrame.frameWidth;
		bitmapData._destinationHeight = textureAtlasFrame.frameHeight;
		bitmapData._sourceX = Math.floor (textureAtlasFrame.frameX * _pixelRatioSource);
		bitmapData._sourceY = Math.floor (textureAtlasFrame.frameY * _pixelRatioSource);
		bitmapData._sourceWidth = Math.ceil (textureAtlasFrame.frameWidth * _pixelRatioSource);
		bitmapData._sourceHeight = Math.ceil (textureAtlasFrame.frameHeight * _pixelRatioSource);
		
		bitmapData._source = source._source;
		
		return bitmapData;
		
	}
	
	
	public static function load (url:String, bitmapDataLoadOptions:BitmapDataLoadOptions = null, pixelRatio:Float = 1.0):Future<BitmapData> {
		
		if (bitmapDataLoadOptions == null) {
			
			bitmapDataLoadOptions = BitmapData.defaultLoadOptions;
			
		}
		
		if (Stage.autoHiDpi && bitmapDataLoadOptions.autoHiDpi) {
			
			if (url.contains("@1x.") && _devicePixelRatio >= 1.5) {
				
				pixelRatio = pixelRatio * 2.0;
				url = url.replaceAll ("@1x.", "@2x.");
				
			}
			
		}
		
		var completer = new Completer<BitmapData> ();
		
		var imageElement:ImageElement = Browser.document.createElement ("image");
		var onLoadSubscription:StreamSubscription;
		var onErrorSubscription:StreamSubscription;
		
		onLoadSubscription = imageElement.onLoad.listen((event) {
			onLoadSubscription.cancel();
			onErrorSubscription.cancel();
			completer.complete(new BitmapData.fromImageElement(imageElement, pixelRatio));
		});

		onErrorSubscription = imageElement.onError.listen((event) {
			onLoadSubscription.cancel();
			onErrorSubscription.cancel();
			completer.completeError(new StateError("Error loading image."));
		});

		if (bitmapDataLoadOptions.webp == false) {
			imageElement.src = url;
			return completer.future;
		}

		//---------------------------

		_isWebpSupported.then((bool webpSupported) {

			var regex = new RegExp(r"(png|jpg|jpeg)$", multiLine:false, caseSensitive:true);
			var match = regex.firstMatch(url);

			if (webpSupported == false || match == null) {
				imageElement.src = url;
			} else {
				imageElement.src = url.substring(0, url.length - match.group(1).length) + "webp";
			}
		});

		return completer.future;
	}

	//-------------------------------------------------------------------------------------------------
	//-------------------------------------------------------------------------------------------------

	int get width => _width;
	int get height => _height;

	num get pixelRatio => _pixelRatio;

	//-------------------------------------------------------------------------------------------------

	ImageData getImageData(int x, int y, int width, int height, [num pixelRatio]) {

		if (pixelRatio != null && pixelRatio != _pixelRatio) {
			var tempBitmapData = new BitmapData(width, height, true, 0, pixelRatio);
			tempBitmapData.draw(this, new Matrix(1.0, 0.0, 0.0, 1.0, -x, -y));
			return tempBitmapData.getImageData(x, y, width, height);
		}

		_ensureContext();

		var pr = _pixelRatio;
		var prs = _pixelRatioSource;

		if (_backingStorePixelRatio > 1.0) {
			return _context.getImageDataHD(x * pr, y * pr, width * pr, height * pr);
		} else {
			return _context.getImageData(x * prs, y * prs, width * prs, height * prs);
		}
	}

	void putImageData(ImageData imageData, int x, int y) {

		_ensureContext();

		var pr = _pixelRatio;
		var prs = _pixelRatioSource;

		if (_backingStorePixelRatio > 1.0) {
			_context.putImageDataHD(imageData, x * pr, y * pr);
		} else {
			_context.putImageData(imageData, x * prs, y * prs);
		}
	}

	ImageData createImageData(int width, int height) {

		_ensureContext();

		var pr = _pixelRatio;
		var prs = _pixelRatioSource;

		return _context.createImageData(width * pr, height * pr);
	}

	//-------------------------------------------------------------------------------------------------

	BitmapData clone([num pixelRatio]) {

		pixelRatio = (pixelRatio != null) ? pixelRatio : _pixelRatio;

		var bitmapData = new BitmapData(_width, _height, true, 0, pixelRatio);
		bitmapData.draw(this);

		return bitmapData;
	}

	//-------------------------------------------------------------------------------------------------

	void applyFilter(BitmapData sourceBitmapData, Rectangle sourceRect, Point destPoint, BitmapFilter filter) {

		filter.apply(sourceBitmapData, sourceRect, this, destPoint);
	}

	//-------------------------------------------------------------------------------------------------

	void colorTransform(Rectangle rect, ColorTransform transform) {

		var imageData = getImageData(rect.x, rect.y, rect.width, rect.height);
		var data = imageData.data;
		var length = data.length;

		int r = transform.redOffset;
		int g = transform.greenOffset;
		int b = transform.blueOffset;
		int a = transform.alphaOffset;

		num rm = transform.redMultiplier;
		num gm = transform.greenMultiplier;
		num bm = transform.blueMultiplier;
		num am = transform.alphaMultiplier;

		if (_isLittleEndianSystem) {
			for (int i = 0; i <= length - 4; i += 4) {
				data[i + 0] = data[i + 0] * (1 - rm) + (r * rm);
				data[i + 1] = data[i + 1] * (1 - gm) + (g * gm);
				data[i + 2] = data[i + 2] * (1 - bm) + (b * bm);
				data[i + 3] = data[i + 3] * (1 - am) + (a * am);
			}
		} else {
			for (int i = 0; i <= length - 4; i += 4) {
				data[i + 0] = data[i + 0] * (1 - am) + (a * am);
				data[i + 1] = data[i + 1] * (1 - bm) + (b * bm);
				data[i + 2] = data[i + 2] * (1 - gm) + (g * gm);
				data[i + 3] = data[i + 3] * (1 - rm) + (r * rm);
			}
		}

		putImageData(imageData, rect.x, rect.y);
	}

	//-------------------------------------------------------------------------------------------------

	void copyPixels(BitmapData sourceBitmapData, Rectangle sourceRect, Point destPoint) {

		_ensureContext();

		var sourceImageData = sourceBitmapData.getImageData(
				sourceRect.x, sourceRect.y, sourceRect.width, sourceRect.height, _pixelRatio);

		_context.putImageData(sourceImageData, destPoint.x, destPoint.y);
	}

	//-------------------------------------------------------------------------------------------------

	void draw(BitmapDrawable source, [Matrix matrix = null]) {

		_ensureContext();

		matrix = (matrix == null) ? new Matrix.fromIdentity() : matrix.clone();
		matrix.scale(_pixelRatioSource, _pixelRatioSource);

		var renderState = new RenderState.fromCanvasRenderingContext2D(_context, matrix);
		source.render(renderState);

		_context.globalAlpha = 1.0;
		_context.globalCompositeOperation = CompositeOperation.SOURCE_OVER;
	}

	//-------------------------------------------------------------------------------------------------

	void fillRect(Rectangle rect, int color) {

		_ensureContext();

		_context.setTransform(_pixelRatioSource, 0.0, 0.0, _pixelRatioSource, 0.0, 0.0);
		_context.fillStyle = _color2rgba(color);
		_context.fillRect(rect.x, rect.y, rect.width, rect.height);
	}

	//-------------------------------------------------------------------------------------------------

	void clear() {

		_ensureContext();

		_context.setTransform(_pixelRatioSource, 0.0, 0.0, _pixelRatioSource, 0.0, 0.0);
		_context.clearRect(0, 0, _width, _height);
	}

	//-------------------------------------------------------------------------------------------------

	int getPixel(int x, int y) {
		return getPixel32(x, y) & 0x00FFFFFF;
	}

	void setPixel(int x, int y, int color) {
		setPixel32(x, y, color | 0xFF000000);
	}

	//-------------------------------------------------------------------------------------------------

	int getPixel32(int x, int y) {

		var imageData = getImageData(x, y, 1, 1);
		var pixels = imageData.width * imageData.height;
		var data = imageData.data;
		var r = 0, g = 0, b = 0, a = 0;

		for(int p = 0; p < pixels; p++) {
			r += _isLittleEndianSystem ? data[p * 4 + 0] : data[p * 4 + 3];
			g += _isLittleEndianSystem ? data[p * 4 + 1] : data[p * 4 + 2];
			b += _isLittleEndianSystem ? data[p * 4 + 2] : data[p * 4 + 1];
			a += _isLittleEndianSystem ? data[p * 4 + 3] : data[p * 4 + 0];
		}

		return ((a ~/ pixels) << 24) + ((r ~/ pixels) << 16) + ((g ~/ pixels) << 8) + ((b ~/ pixels) << 0);
	}

	void setPixel32(int x, int y, int color) {

		var imageData = createImageData(1, 1);
		var pixels = imageData.width * imageData.height;
		var data = imageData.data;

		for(int p = 0; p < pixels; p++) {
			data[p * 4 + 0] = _isLittleEndianSystem ? (color >> 16) & 0xFF : (color >> 24) & 0xFF;
			data[p * 4 + 1] = _isLittleEndianSystem ? (color >>	8) & 0xFF : (color >>	0) & 0xFF;
			data[p * 4 + 2] = _isLittleEndianSystem ? (color >>	0) & 0xFF : (color >>	8) & 0xFF;
			data[p * 4 + 3] = _isLittleEndianSystem ? (color >> 24) & 0xFF : (color >> 16) & 0xFF;
		}

		putImageData(imageData, x, y);
	}

	//-------------------------------------------------------------------------------------------------
	//-------------------------------------------------------------------------------------------------

	void render(RenderState renderState) {

		var renderStateContext = renderState.context;

		switch(_renderMode) {

			case 0:
				renderStateContext.drawImage(_source,
						_destinationX, _destinationY);
				break;

			case 1:
				renderStateContext.drawImageScaled(_source,
						_destinationX, _destinationY, _destinationWidth, _destinationHeight);
				break;

			case 2:
				renderStateContext.drawImageScaledFromSource(_source,
						_sourceX, _sourceY, _sourceWidth, _sourceHeight,
						_destinationX, _destinationY, _destinationWidth, _destinationHeight);
				break;

			case 3:
				renderStateContext.transform(0.0, -1.0, 1.0, 0.0, _destinationX, _destinationY + _destinationHeight);
				renderStateContext.drawImageScaledFromSource(_source,
						_sourceX, _sourceY, _sourceHeight, _sourceWidth,
						0.0 , 0.0, _destinationHeight, _destinationWidth);
				break;
		}
	}

	//-------------------------------------------------------------------------------------------------

	void renderClipped(RenderState renderState, Rectangle clipRectangle) {

		if (clipRectangle.width == 0 ||	clipRectangle.height == 0) return;

		var renderStateContext = renderState.context;

		// Drawing a clipped BitmapData with a _renderMode other than 0 is pretty complicated.
		// Therefore we convert all BitmapDatas to _renderMode 0 and use a simple drawing method.

		if (_renderMode != 0) {
			_ensureContext();
		}

		var sourceX = (clipRectangle.x - _destinationX) * _pixelRatioSource;
		var sourceY = (clipRectangle.y - _destinationY) * _pixelRatioSource;
		var sourceWidth = clipRectangle.width * _pixelRatioSource;
		var sourceHeight = clipRectangle.height * _pixelRatioSource;
		var destinationX = clipRectangle.x + _destinationX;
		var destinationY = clipRectangle.y + _destinationY;
		var destinationWidth = clipRectangle.width;
		var destinationHeight = clipRectangle.height;

		renderStateContext.drawImageScaledFromSource(_source,
				sourceX, sourceY, sourceWidth, sourceHeight,
				destinationX, destinationY, destinationWidth, destinationHeight);
	}

	//-------------------------------------------------------------------------------------------------
	//-------------------------------------------------------------------------------------------------

	void _ensureContext() {

		if (_context == null) {

			var pixelRatioSource = _pixelRatio / _backingStorePixelRatio;
			var sourceWidth = (_width * pixelRatioSource).ceil();
			var sourceHeight = (_height * pixelRatioSource).ceil();

			var canvas = new CanvasElement(width: sourceWidth, height: sourceHeight);
			var matrix = new Matrix(pixelRatioSource, 0.0, 0.0, pixelRatioSource, 0.0, 0.0);
			var renderState = new RenderState.fromCanvasRenderingContext2D(canvas.context2D, matrix);
			this.render(renderState);

			_pixelRatio = _pixelRatio;
			_pixelRatioSource = pixelRatioSource;

			_renderMode = ((1.0 - _pixelRatioSource).abs() < 0.001) ? 0 : 1;
			_destinationX = 0;
			_destinationY = 0;
			_destinationWidth = _width;
			_destinationHeight = _height;
			_sourceX = 0;
			_sourceY = 0;
			_sourceWidth = sourceWidth;
			_sourceHeight = sourceHeight;

			_source = canvas;
			_context = canvas.context2D;
		}
	}
}
