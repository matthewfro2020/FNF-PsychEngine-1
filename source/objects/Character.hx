package objects;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.math.FlxPoint;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;

import backend.animation.PsychAnimationController;
import backend.animate.AnimateCharacter;
import backend.animate.AnimateZipReader;
import backend.animate.AnimateFolderReader;

import backend.Song;
import states.stages.objects.TankmenBG;

import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import openfl.utils.Assets;

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

class Character extends FlxSprite
{
	// ------------------------------------------------------------
	public static final DEFAULT_CHARACTER:String = "bf";

	public var animOffsets:Map<String, Array<Dynamic>> = new Map();
	public var animationsArray:Array<AnimArray> = [];
	public var extraData:Map<String, Dynamic> = new Map();

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var stunned:Bool = false;
	public var idleSuffix:String = "";
	public var danceIdle:Bool = false;
	public var skipDance:Bool = false;

	public var animationNotes:Array<Dynamic> = [];
	public var hasMissAnimations:Bool = false;
	public var missingCharacter:Bool = false;

	public var missingText:FlxText;
	public var healthIcon:String = "face";
	public var vocalsFile:String = "";
	public var singDuration:Float = 4;

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var imageFile:String = "";
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	public var debugMode:Bool = false;

	// ------------------------------------------------------------
	// ANIMATE (Psych Hybrid)
	// ------------------------------------------------------------
	public var isAnimateAtlas(default, null):Bool = false;
	public var isAnimateFolder:Bool = false;
	public var isAnimateZIP:Bool = false;
	public var isAnimate:Bool = false;

	public var atlas:PsychFlxAnimate;
	public var animateZIPChar:AnimateCharacter;
	public var animateData:Dynamic = null;
	public var animateLibrary:Dynamic = null;
	public var animateAtlas:FlxAtlasFrames = null;

	// ------------------------------------------------------------
	// Constructor
	// ------------------------------------------------------------
	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
	{
		super(x, y);

		this.isPlayer = isPlayer;
		animation = new PsychAnimationController(this);
		animOffsets = new Map();

		changeCharacter(character);
	}

	// ------------------------------------------------------------
	public function changeCharacter(char:String):Void
	{
		curCharacter = char;
		animationsArray = [];
		animOffsets = new Map();

		var path = Paths.getPath("characters/" + char + ".json", TEXT);

		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath("characters/" + DEFAULT_CHARACTER + ".json");
			missingCharacter = true;
			missingText = new FlxText(0, 0, 300, "ERROR:\n" + char + ".json", 16);
		}

		try {
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(File.getContent(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		}
		catch (e)
		{
			trace("Character load error for '" + char + "': " + e);
		}

		hasMissAnimations =
			hasAnimation("singLEFTmiss") ||
			hasAnimation("singDOWNmiss") ||
			hasAnimation("singUPmiss") ||
			hasAnimation("singRIGHTmiss");

		recalculateDanceIdle();
		dance();
	}

	// ------------------------------------------------------------
	// LOAD CHARACTER FILE
	// ------------------------------------------------------------
	public function loadCharacterFile(json:Dynamic):Void
	{
		isAnimateAtlas = false;
		isAnimateFolder = false;
		isAnimateZIP = false;

		// ZIP ANIMATE SUPPORT
		if (json.animateZip != null)
		{
			var zip = Paths.modFolders("animate/" + json.animateZip);

			if (FileSystem.exists(zip))
			{
				isAnimateZIP = true;
				isAnimate = true;

				animateZIPChar = new AnimateCharacter(zip);
				return;
			}
		}

		// ATLAS DETECT
		#if flxanimate
		var animPath = Paths.getPath("images/" + json.image + "/Animation.json", TEXT);
		if (#if MODS_ALLOWED FileSystem.exists(animPath) || #end Assets.exists(animPath))
			isAnimateAtlas = true;
		#end

		// NORMAL PNG MULTIATLAS
		if (!isAnimateAtlas)
			frames = Paths.getMultiAtlas(json.image.split(","));

		#if flxanimate
		if (isAnimateAtlas)
		{
			atlas = new PsychFlxAnimate();
			Paths.loadAnimateAtlas(atlas, json.image);
		}
		#end

		imageFile = json.image;
		jsonScale = json.scale;

		if (json.scale != 1)
		{
			scale.set(json.scale, json.scale);
			updateHitbox();
		}

		positionArray = json.position;
		cameraPosition = json.camera_position;
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);

		healthColorArray =
			(json.healthbar_colors != null && json.healthbar_colors.length > 2)
			? json.healthbar_colors : [161, 161, 161];

		vocalsFile = (json.vocals_file != null) ? json.vocals_file : "";
		originalFlipX = json.flip_x == true;
		editorIsPlayer = json._editor_isPlayer;

		noAntialiasing = json.no_antialiasing == true;
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		animationsArray = json.animations;

		if (animationsArray != null)
		{
			for (anim in animationsArray)
			{
				var id = anim.anim;
				var name = anim.name;
				var fps = anim.fps;
				var loop = anim.loop;
				var ind = anim.indices;

				if (!isAnimateAtlas)
				{
					if (ind != null && ind.length > 0)
						animation.addByIndices(id, name, ind, "", fps, loop);
					else
						animation.addByPrefix(id, name, fps, loop);
				}
				else
				{
					#if flxanimate
					if (ind != null && ind.length > 0)
						atlas.anim.addBySymbolIndices(id, name, ind, fps, loop);
					else
						atlas.anim.addBySymbol(id, name, fps, loop);
					#end
				}

				if (anim.offsets != null && anim.offsets.length >= 2)
					addOffset(id, anim.offsets[0], anim.offsets[1]);
				else
					addOffset(id, 0, 0);
			}
		}
	}

	// ------------------------------------------------------------
	// ANIMATE FOLDER LOADING
	// ------------------------------------------------------------
	public function tryLoadAnimateFolder(char:String):Bool
	{
		var base = Paths.modFolders("characters") + "animate/" + char;
		var data = base + "/data.json";
		var lib = base + "/library.json";
		var sym = base + "/symbols";

		if (!FileSystem.exists(data) || !FileSystem.exists(lib) || !FileSystem.exists(sym))
			return false;

		var reader = new AnimateFolderReader(base);
		if (!reader.valid)
			return false;

		isAnimateFolder = true;
		isAnimate = true;

		animateData = reader.dataJson;
		animateLibrary = reader.libJson;
		animateAtlas = reader.toAtlas();

		if (animateAtlas != null)
			frames = animateAtlas;

		return true;
	}

	// ------------------------------------------------------------
	// AUTO-REGISTER ANIMATIONS (Atlas + Folder)
	// ------------------------------------------------------------
	public function registerAnimateAnimations():Void
	{
		if (!isAnimateFolder && !isAnimateAtlas)
			return;

		var collected = new Array<String>();

		#if flxanimate
		// FROM PSYCH-FLXANIMATE
		if (isAnimateAtlas && atlas != null && atlas.anim != null)
		{
			var a:Dynamic = atlas.anim;

			if (Reflect.hasField(a, "animsMap"))
			{
				for (name in a.animsMap.keys())
					if (name != null) collected.push(name);
			}
			else if (Reflect.hasField(a, "nameMap"))
			{
				var nm:Dynamic = Reflect.field(a, "nameMap");
				for (name in nm.keys())
					if (name != null) collected.push(name);
			}
		}
		#end

		// FOLDER SYMBOLS
		if (isAnimateFolder && animateLibrary != null)
		{
			if (Reflect.hasField(animateLibrary, "symbolDictionary"))
			{
				var dict:Dynamic = Reflect.field(animateLibrary, "symbolDictionary");

				if (dict != null && Reflect.hasField(dict, "keys"))
				{
					for (name in dict.keys())
						if (name != null) collected.push(name);
				}
			}
		}

		for (name in collected)
		{
			if (!Lambda.exists(animationsArray, (a) -> a.anim == name))
			{
				var newAnim:AnimArray = {
					anim: name,
					name: name,
					fps: 24,
					loop: false,
					indices: [],
					offsets: [0, 0]
				};

				animationsArray.push(newAnim);
				addOffset(name, 0, 0);
			}
		}
	}

	// ------------------------------------------------------------
	// UPDATE
	// ------------------------------------------------------------
	override function update(elapsed:Float):Void
	{
		#if flxanimate
		if (isAnimateAtlas && atlas != null)
			atlas.update(elapsed);
		#end

		if (isAnimateZIP && animateZIPChar != null)
			animateZIPChar.update(elapsed);

		if (debugMode || (!isAnimateAtlas && animation.curAnim == null))
		{
			super.update(elapsed);
			return;
		}

		// Handle hey animation timeout
		if (heyTimer > 0)
		{
			var rate = (PlayState.instance != null ? PlayState.instance.playbackRate : 1);
			heyTimer -= elapsed * rate;

			if (heyTimer <= 0)
			{
				var an = getAnimationName();
				if (specialAnim && (an == "hey" || an == "cheer"))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if (specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith("miss") && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		// Hold timer logic
		if (getAnimationName().startsWith("sing"))
			holdTimer += elapsed;
		else if (isPlayer)
			holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration)
		{
			dance();
			holdTimer = 0;

			var nm = getAnimationName();
			if (isAnimationFinished() && hasAnimation(nm + "-loop"))
				playAnim(nm + "-loop");

			super.update(elapsed);
		}
	}

	// ------------------------------------------------------------
	inline public function getAnimationName():String
	{
		return animation.curAnim != null ? animation.curAnim.name : "";
	}

	inline public function isAnimationFinished():Bool
	{
		if (animation.curAnim == null)
			return false;
		return animation.curAnim.finished;
	}

	public function finishAnimation():Void
	{
		if (animation.curAnim != null)
			animation.curAnim.finish();
	}

	public function hasAnimation(name:String):Bool
	{
		return animOffsets.exists(name);
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		animOffsets[name] = [x, y];
	}

	public function playAnim(name:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		if (isAnimateZIP && animateZIPChar != null)
		{
			animateZIPChar.play(name);
			return;
		}

		if (isAnimateAtlas && atlas != null)
		{
			atlas.anim.play(name, forced);
			return;
		}

		if (animation != null)
			animation.play(name, forced, reversed, frame);

		if (animOffsets.exists(name))
			offset.set(animOffsets[name][0], animOffsets[name][1]);
	}

	public function dance():Void
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if (danceIdle)
			{
				var right = FlxG.random.bool();
				playAnim(right ? "danceRight" + idleSuffix : "danceLeft" + idleSuffix);
			}
			else if (hasAnimation("idle" + idleSuffix))
				playAnim("idle" + idleSuffix);
		}
	}

	public override function destroy():Void
	{
		atlas = FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}
}
