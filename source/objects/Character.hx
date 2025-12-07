package objects;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxAtlasFrames;
import backend.animation.PsychAnimationController;
import backend.animate.AnimateCharacter;
import backend.animate.AnimateFolderReader;
import backend.Song;
import backend.Conductor;
import states.stages.objects.TankmenBG;
import states.PlayState;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import haxe.ds.Lambda;
#if flxanimate
import flxanimate._PsychFlxAnimate.FlxAnimate;
#end
// Needed for Paths.getPath, Paths.getMultiAtlas, etc.
import backend.Paths;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;
	var position:Array<Float>;
	var camera_position:Array<Float>;
	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var _editor_isPlayer:Null<Bool>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxSprite {
	public static final DEFAULT_CHARACTER:String = "bf";

	public var animOffsets:Map<String, Array<Float>> = new Map();
	public var extraData:Map<String, Dynamic> = new Map();
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var stunned:Bool = false;
	public var singDuration:Float = 4;
	public var idleSuffix:String = "";
	public var danceIdle:Bool = false;
	public var skipDance:Bool = false;

	public var healthIcon:String = "face";
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var vocalsFile:String = "";
	public var missingCharacter:Bool = false;
	public var missingText:FlxText;

	// REQUIRED: you used this but never defined it
	public var hasMissAnimations:Bool = false;

	// For Character Editor
	public var imageFile:String = "";
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	// ANIMATE FOLDER SUPPORT
	public var isAnimateFolder:Bool = false;
	public var animateData:Dynamic = null;
	public var animateLibrary:Dynamic = null;
	public var animateAtlas:FlxAtlasFrames = null;

	// ANIMATE ATLAS (FlxAnimate)
	@:allow(states.editors.CharacterEditorState)
	public var isAnimateAtlas(default, null):Bool = false;

	#if flxanimate
	public var atlas:FlxAnimate = null;
	#end

	// ZIP-BASED ANIMATE SUPPORT
	public var isAnimateZIP:Bool = false;
	public var animateZIPChar:AnimateCharacter = null;

	// NEW FIELD YOU REQUESTED
	public var isAnimate:Bool = false;

	var _lastPlayedAnimation:String = "";

	public var animationNotes:Array<Dynamic> = [];
	public var danced:Bool = false;
	public var danceEveryNumBeats:Int = 2;

	var settingCharacterUp:Bool = true;

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false) {
		super(x, y);
		animation = new PsychAnimationController(this);
		this.isPlayer = isPlayer;

		changeCharacter(character);

		switch (curCharacter) {
			case "pico-speaker":
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");

			case "pico-blazin", "darnell-blazin":
				skipDance = true;
		}
	}

	// ----------------------------------------------------
	// CHANGE CHARACTER
	// ----------------------------------------------------
	public function changeCharacter(character:String):Void {
		animationsArray = [];
		animOffsets = new Map();
		curCharacter = character;
		missingCharacter = false;

		// Try Animate Folder FIRST
		if (tryLoadAnimateFolder(character)) {
			recalculateDanceIdle();
			dance();
			registerAnimateAnimations();
			return;
		}

		var charPath:String = "characters/" + character + ".json";
		var path:String = Paths.getPath(charPath, TEXT);

		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			missingCharacter = true;
			path = Paths.getSharedPath("characters/" + DEFAULT_CHARACTER + ".json");

			missingText = new FlxText(0, 0, 300, "ERROR:\n" + character + ".json", 16);
			missingText.alignment = CENTER;
		}

		try {
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(File.getContent(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		} catch (e:Dynamic) {
			trace('[Character] Failed to load JSON for "' + character + '": ' + e);
		}

		skipDance = false;

		// Auto-detect msing variants
		hasMissAnimations = Lambda.exists(animationsArray, a -> a.anim.startsWith("msing"));

		recalculateDanceIdle();
		dance();
	}

	// ----------------------------------------------------
	// LOAD CHARACTER JSON
	// ----------------------------------------------------
	public function loadCharacterFile(json:Dynamic):Void {
		isAnimateAtlas = false;

		#if flxanimate
		var animJson = Paths.getPath("images/" + json.image + "/Animation.json", TEXT);
		if ((#if MODS_ALLOWED FileSystem.exists(animJson) #else Assets.exists(animJson) #end))
			isAnimateAtlas = true;
		#end

		scale.set(1, 1);
		updateHitbox();

		// PNG fallback
		if (!isAnimateAtlas) {
			frames = Paths.getMultiAtlas(json.image.split(","));
		}
		#if flxanimate
		else {
			atlas = new FlxAnimate();
			atlas.showPivot = false;

			try {
				Paths.loadAnimateAtlas(atlas, json.image);
			} catch (e:haxe.Exception) {
				FlxG.log.warn("Could not load Animate Atlas: " + e);
			}
		}
		#end

		imageFile = json.image;
		jsonScale = json.scale;

		if (json.scale != 1) {
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		positionArray = json.position;
		cameraPosition = json.camera_position;

		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);

		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];

		vocalsFile = (json.vocals_file != null) ? json.vocals_file : "";
		originalFlipX = json.flip_x;
		editorIsPlayer = json._editor_isPlayer;

		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		parseAnimations(json);

		#if flxanimate
		if (isAnimateAtlas)
			copyAtlasValues();
		registerAnimateAnimations();
		#end
	}

	// ----------------------------------------------------
	// PARSE ANIMATIONS ARRAY
	// ----------------------------------------------------
	function parseAnimations(json:Dynamic):Void {
		animationsArray = json.animations;
		if (animationsArray == null || animationsArray.length == 0)
			return;

		for (anim in animationsArray) {
			if (!isAnimateAtlas) {
				if (anim.indices != null && anim.indices.length > 0)
					animation.addByIndices(anim.anim, anim.name, anim.indices, "", anim.fps, anim.loop);
				else
					animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
			}
			#if flxanimate
			else {
				if (anim.indices != null && anim.indices.length > 0)
					atlas.anim.addBySymbolIndices(anim.anim, anim.name, anim.indices, anim.fps, anim.loop);
				else
					atlas.anim.addBySymbol(anim.anim, anim.name, anim.fps, anim.loop);
			}
			#end

			if (anim.offsets != null && anim.offsets.length > 1)
				addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			else
				addOffset(anim.anim, 0, 0);
		}
	}

	// ----------------------------------------------------
	// ANIMATE FOLDER LOADING
	// ----------------------------------------------------
	public function tryLoadAnimateFolder(character:String):Bool {
		var base = Paths.modFolders("characters") + "animate/" + character;
		var data = base + "/data.json";
		var lib = base + "/library.json";
		var sym = base + "/symbols";

		if (!FileSystem.exists(data) || !FileSystem.exists(lib) || !FileSystem.exists(sym))
			return false;

		var reader = new AnimateFolderReader(base);
		if (!reader.valid)
			return false;

		isAnimateFolder = true;
		isAnimate = true; // Your requested fix

		animateData = reader.dataJson;
		animateLibrary = reader.libJson;
		animateAtlas = reader.toAtlas();

		if (animateAtlas != null)
			frames = animateAtlas;

		return true;
	}

	// ============================================================
	// AUTO-REGISTER ANIMATE SYMBOLS AS CHARACTER ANIMATIONS
	// ============================================================
	public function registerAnimateAnimations():Void {
		if (!isAnimateFolder && !isAnimateAtlas)
			return;

		#if flxanimate
		// Animate Atlas case (Animation.json)
		if (atlas != null && atlas.anim != null) {
			var keys = atlas.anim.symbolMap.keys();
			for (name in keys) {
				var animName:String = Std.string(name);
				animationsArray.push({
					anim: animName,
					name: animName,
					fps: 24,
					loop: false,
					indices: [],
					offsets: [0, 0]
				});

				// Create offset map placeholder
				animOffsets.set(animName, [0.0, 0.0]);
			}
		}
		#end

		// Animate Folder (AnimateFolderReader)
		if (isAnimateFolder && animateLibrary != null) {
			var symbols = animateLibrary.symbolDictionary;

			for (key in symbols.keys()) {
				var symbol = symbols[key];
				if (symbol.className != null && symbol.className != "") {
					var animName = symbol.className;

					animationsArray.push({
						anim: animName,
						name: animName,
						fps: 24,
						loop: false,
						indices: [],
						offsets: [0, 0]
					});

					animOffsets[animName] = [0, 0];
				}
			}
		}
	}

	// ----------------------------------------------------
	// UPDATE LOOP
	// ----------------------------------------------------
	override function update(elapsed:Float):Void {
		#if flxanimate
		if (isAnimateAtlas && atlas != null)
			atlas.update(elapsed);
		#end

		if (isAnimateZIP && animateZIPChar != null)
			animateZIPChar.update(elapsed);

		if (debugMode
			|| (!isAnimateAtlas && animation.curAnim == null)
			|| (isAnimateAtlas && (atlas == null || atlas.anim.curInstance == null))) {
			super.update(elapsed);
			return;
		}

		// HEY timer
		if (heyTimer > 0) {
			var rate = (PlayState.instance != null ? PlayState.instance.playbackRate : 1);
			heyTimer -= elapsed * rate;

			if (heyTimer <= 0) {
				if (specialAnim && (getAnimationName() == "hey" || getAnimationName() == "cheer"))
					specialAnim = false;

				dance();
				heyTimer = 0;
			}
		} else if (specialAnim && isAnimationFinished()) {
			specialAnim = false;
			dance();
		} else if (getAnimationName().endsWith("miss") && isAnimationFinished()) {
			dance();
			finishAnimation();
		}

		switch (curCharacter) {
			case "pico-speaker":
				if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0]) {
					var note = animationNotes.shift();
					var nd = (note[1] > 2 ? 3 : 1) + FlxG.random.int(0, 1);
					playAnim("shoot" + nd, true);
				}

				if (isAnimationFinished())
					playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if (getAnimationName().startsWith("sing"))
			holdTimer += elapsed;
		else if (isPlayer)
			holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration) {
			dance();
			holdTimer = 0;

			var nm = getAnimationName();
			if (isAnimationFinished() && hasAnimation(nm + "-loop"))
				playAnim(nm + "-loop");
		}

		super.update(elapsed);
	}

	// ----------------------------------------------------
	// UTILITY
	// ----------------------------------------------------
	inline public function isAnimationNull():Bool {
		#if flxanimate
		return !isAnimateAtlas ? animation.curAnim == null : atlas == null || atlas.anim.curInstance == null;
		#else
		return animation.curAnim == null;
		#end
	}

	inline public function getAnimationName():String {
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool {
		if (isAnimationNull())
			return false;

		#if flxanimate
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
		#else
		return animation.curAnim.finished;
		#end
	}

	public function finishAnimation():Void {
		if (isAnimationNull())
			return;

		if (!isAnimateAtlas)
			animation.curAnim.finish();
		#if flxanimate
		else
			atlas.anim.curFrame = atlas.anim.length - 1;
		#end
	}

	public function hasAnimation(a:String):Bool {
		return animOffsets.exists(a);
	}

	// ----------------------------------------------------
	// PAUSE HANDLING
	// ----------------------------------------------------
	public var animPaused(get, set):Bool;

	private function get_animPaused():Bool {
		if (isAnimationNull())
			return false;

		#if flxanimate
		return !isAnimateAtlas ? animation.curAnim.paused : !atlas.anim.isPlaying;
		#else
		return animation.curAnim.paused;
		#end
	}

	private function set_animPaused(v:Bool):Bool {
		if (isAnimationNull())
			return v;

		if (!isAnimateAtlas)
			animation.curAnim.paused = v;
		#if flxanimate
		else if (v)
			atlas.anim.isPlaying = !value;
		else
			atlas.anim.isPlaying = !value;
		#end

		return v;
	}

	// ----------------------------------------------------
	// DANCING
	// ----------------------------------------------------
	public function dance():Void {
		if (debugMode || skipDance || specialAnim)
			return;

		if (danceIdle) {
			danced = !danced;
			playAnim(danced ? "danceRight" + idleSuffix : "danceLeft" + idleSuffix);
		} else if (hasAnimation("idle" + idleSuffix)) {
			playAnim("idle" + idleSuffix);
		}
	}

	public function recalculateDanceIdle():Void {
		var last = danceIdle;

		danceIdle = hasAnimation("danceLeft" + idleSuffix) && hasAnimation("danceRight" + idleSuffix);

		if (settingCharacterUp) {
			danceEveryNumBeats = danceIdle ? 1 : 2;
		} else if (last != danceIdle) {
			var calc = danceEveryNumBeats;
			if (danceIdle)
				calc = Std.int(calc / 2);
			else
				calc *= 2;
			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}

		settingCharacterUp = false;
	}

	// ----------------------------------------------------
	// PLAY ANIMATION
	// ----------------------------------------------------
	public function playAnim(n:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
		_lastPlayedAnimation = n;

		// ZIP system
		if (isAnimateZIP && animateZIPChar != null) {
			animateZIPChar.play(n);
			return;
		}

		#if flxanimate
		if (isAnimateAtlas && atlas != null) {
			atlas.anim.play(n, forced);

			if (animOffsets.exists(n))
				offset.set(animOffsets[n][0], animOffsets[n][1]);

			return;
		}
		#end

		if (animation != null) {
			animation.play(n, forced, reversed, frame);

			if (animOffsets.exists(n))
				offset.set(animOffsets[n][0], animOffsets[n][1]);
		}
	}

	// ----------------------------------------------------
	// PICO SPEAKER UTIL
	// ----------------------------------------------------
	function loadMappedAnims():Void {
		try {
			var d = Song.getChart("picospeaker", Paths.formatToSongPath(Song.loadedSongName));

			if (d != null)
				for (section in d.notes)
					for (note in section.sectionNotes)
						animationNotes.push(note);

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		} catch (e) {}
	}

	function sortAnims(a:Array<Dynamic>, b:Array<Dynamic>):Int {
		return FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]);
	}

	// ----------------------------------------------------
	// OFFSETS
	// ----------------------------------------------------
	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String):Void {
		animation.addByPrefix(name, anim, 24, false);
	}

	// ----------------------------------------------------
	// ATLAS DRAW PARAMETER COPY
	// ----------------------------------------------------
	#if flxanimate
	public function copyAtlasValues():Void {
		@:privateAccess {
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
			atlas.origin = origin;
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}
	#end

	// ----------------------------------------------------
	// DRAW OVERRIDE
	// ----------------------------------------------------
	#if flxanimate
	override public function draw():Void {
		var lastAlpha = alpha;
		var lastColor = color;

		// ZIP RENDER
		if (isAnimateZIP && animateZIPChar != null) {
			animateZIPChar.x = x;
			animateZIPChar.y = y;
			animateZIPChar.flipX = flipX;
			animateZIPChar.flipY = flipY;
			animateZIPChar.scale = scale;
			animateZIPChar.alpha = alpha;
			animateZIPChar.color = color;
			animateZIPChar.visible = visible;
			animateZIPChar.cameras = cameras;

			animateZIPChar.draw();

			if (missingCharacter)
				drawMissing(lastColor, lastAlpha);

			return;
		}

		// Missing tint
		if (missingCharacter) {
			alpha *= 0.6;
			color = FlxColor.BLACK;
		}

		// ATLAS DRAW
		if (isAnimateAtlas && atlas != null && atlas.anim.curInstance != null) {
			copyAtlasValues();
			atlas.draw();

			alpha = lastAlpha;
			color = lastColor;

			if (missingCharacter)
				drawMissing(lastColor, lastAlpha);
			return;
		}

		// PNG fallback
		super.draw();

		if (missingCharacter)
			drawMissing(lastColor, lastAlpha);
	}

	function drawMissing(lastColor:FlxColor, lastAlpha:Float):Void {
		alpha = lastAlpha;
		color = lastColor;

		missingText.x = getMidpoint().x - 150;
		missingText.y = getMidpoint().y - 10;
		missingText.draw();
	}
	#end

	// ----------------------------------------------------
	// HITBOX + DESTROY
	// ----------------------------------------------------
	override public function updateHitbox():Void {
		frameWidth = Std.int(width);
		frameHeight = Std.int(height);
	}

	#if flxanimate
	override public function destroy():Void {
		atlas = FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}
	#end
}
