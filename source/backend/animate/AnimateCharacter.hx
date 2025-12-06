package backend.animate;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import flixel.FlxSprite;

class AnimateCharacter extends FlxSprite {
	/** 
		We rename frames → bitmapFrames
		to avoid conflict with FlxSprite.frames
	**/
	public var bitmapFrames:Array<BitmapData> = [];

	public var animations:Map<String, Array<Int>> = new Map();
	public var animFPS:Map<String, Int> = new Map();
	public var animLoop:Map<String, Bool> = new Map();

	public var curAnim:String = "idle";
	public var curFrame:Int = 0;
	public var timer:Float = 0;

	var reader:AnimateZipReader;
	var fallbackFrame:BitmapData;
	var canvasWidth:Int = 2000;
	var canvasHeight:Int = 2000;

	public function new(zipPath:String) {
		super();

		reader = new AnimateZipReader(zipPath);

		if (reader == null || reader.data == null) {
			trace("Error: AnimateZipReader failed to initialize");
			fallbackFrame = new BitmapData(1, 1, true, 0x00000000);
			bitmapFrames.push(fallbackFrame);
			pixels = fallbackFrame;
			return;
		}

		fallbackFrame = new BitmapData(1, 1, true, 0x00000000);

		parseAnimationData();
		buildFrames();

		// Guarantee no null pixels EVER
		if (bitmapFrames.length == 0)
			bitmapFrames.push(fallbackFrame);

		pixels = bitmapFrames[0];

		// default animation
		var defaultAnim = reader.data.defaultAnim != null ? reader.data.defaultAnim : "idle";
		play(defaultAnim);
	}

	// --------------------------------------------------------
	// LOAD ANIMATION DEFINITIONS
	// --------------------------------------------------------
	function parseAnimationData() {
		if (reader.data == null)
			return;

		// animations {...}
		if (reader.data.animations != null) {
			var map:Map<String, Dynamic> = cast reader.data.animations;
			for (key in map.keys()) {
				var arr:Array<Int> = cast map.get(key);
				if (arr != null)
					animations.set(key, arr);
			}
		}

		// fps {...}
		if (reader.data.fps != null) {
			var mapFPS:Map<String, Dynamic> = cast reader.data.fps;
			for (key in mapFPS.keys()) {
				var fpsVal:Dynamic = mapFPS.get(key);
				if (fpsVal != null)
					animFPS.set(key, cast fpsVal);
			}
		}

		// loops {...}
		if (reader.data.loops != null) {
			var loopMap:Map<String, Dynamic> = cast reader.data.loops;
			for (key in loopMap.keys()) {
				var loopVal:Dynamic = loopMap.get(key);
				if (loopVal != null)
					animLoop.set(key, cast loopVal);
			}
		}
	}

	// --------------------------------------------------------
	// BUILD BITMAP FRAMES (SAFE)
	// --------------------------------------------------------
	function buildFrames() {
		if (reader.data == null || reader.data.frames == null)
			return;

		var framesList:Array<Dynamic> = cast reader.data.frames;

		for (frameData in framesList) {
			var layers:Array<Dynamic> = cast frameData;

			// Empty frame? → push blank frame to avoid crash
			if (layers == null || layers.length == 0) {
				bitmapFrames.push(fallbackFrame.clone());
				continue;
			}

			var canvas = new BitmapData(canvasWidth, canvasHeight, true, 0x00000000);

			for (layer in layers) {
				if (layer == null || layer.symbol == null)
					continue;

				var pngName = layer.symbol + ".png";
				var bytes = reader.getPNG(pngName);
				if (bytes == null)
					continue;

				var bmp:BitmapData = null;
				try {
					bmp = BitmapData.fromBytes(bytes);
				} catch (e:Dynamic) {
					trace("Error loading PNG: " + pngName);
					continue;
				}

				if (bmp == null)
					continue;

				var t = layer.transformation;
				if (t == null) {
					t = {
						sx: 1,
						sy: 1,
						x: 0,
						y: 0
					};
				}

				var m = new Matrix();
				m.a = t.sx != null ? t.sx : 1;
				m.d = t.sy != null ? t.sy : 1;
				m.tx = t.x != null ? t.x : 0;
				m.ty = t.y != null ? t.y : 0;

				canvas.draw(bmp, m);
				bmp.dispose();
			}

			bitmapFrames.push(canvas);
		}
	}

	// --------------------------------------------------------
	// PLAY ANIMATION
	// --------------------------------------------------------
	public function play(name:String) {
		if (name == null || !animations.exists(name)) {
			trace("Missing animation: " + name + ", falling back to idle");

			if (animations.exists("idle"))
				name = "idle";
			else
				name = animFallback();
		}

		curAnim = name;
		curFrame = 0;
		timer = 0;

		updateBitmap();
	}

	// fallback if idle doesn't exist either
	function animFallback():String {
		for (key in animations.keys())
			return key; // first available anim

		return "idle";
	}

	// --------------------------------------------------------
	// UPDATE ANIMATION
	// --------------------------------------------------------
	override function update(elapsed:Float) {
		var fps = animFPS.exists(curAnim) ? animFPS.get(curAnim) : 24;
		if (fps <= 0)
			fps = 24;

		timer += elapsed;
		var frameTime = 1 / fps;

		if (timer >= frameTime) {
			timer -= frameTime;

			var group = animations.get(curAnim);
			if (group == null || group.length == 0) {
				pixels = fallbackFrame;
				return;
			}

			curFrame++;

			if (curFrame >= group.length) {
				var looping = animLoop.exists(curAnim) ? animLoop.get(curAnim) : false;
				if (looping)
					curFrame = 0;
				else
					curFrame = group.length - 1;
			}

			updateBitmap();
		}

		super.update(elapsed);
	}

	// --------------------------------------------------------
	// UPDATE BITMAP
	// --------------------------------------------------------
	function updateBitmap() {
		var group = animations.get(curAnim);
		if (group == null || group.length == 0) {
			pixels = fallbackFrame;
			return;
		}

		var frameIndex = group[curFrame];
		if (frameIndex >= 0 && frameIndex < bitmapFrames.length)
			pixels = bitmapFrames[frameIndex];
		else
			pixels = fallbackFrame;
	}

	public function getFPS():Int {
		return animFPS.exists(curAnim) ? animFPS.get(curAnim) : 24;
	}
}
