package objects;

import backend.animation.PsychAnimationController;
import backend.animate.AnimateCharacter;
import backend.animate.AnimateZipReader;
import backend.animate.AnimateFolderReader;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic; // safe to include
import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;
import backend.Song;
import states.stages.objects.TankmenBG;

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
	/**
	 * In case a character is missing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var animOffsets:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>()
	public var debugMode:Bool = false;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>()

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	// Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	// ------------------------------------------------------------
	// ANIMATE FOLDER SUPPORT (AnimateFolderReader format)
	// ------------------------------------------------------------
	public var isAnimateFolder:Bool = false;
	public var isAnimate:Bool = false;

	public var animateData:Dynamic = null;
	public var animateLibrary:Dynamic = null;
	public var animateAtlas:FlxAtlasFrames = null;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false) {
		super(x, y)

		animation = new PsychAnimationController(this)

		animOffsets = new Map<String, Array<Dynamic>>()
		this.isPlayer = isPlayer;
		changeCharacter(character)

		switch (curCharacter) {
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims()
				playAnim("shoot1")
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	public function changeCharacter(character:String) {
		animationsArray = [];
		animOffsets = new Map<String, Array<Dynamic>>()
		curCharacter = character;
		var characterPath:String = 'characters/$character.json';

		var path:String = Paths.getPath(characterPath, TEXT)
		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER +
				'.json') // If a character couldn't be found, change him to BF just to prevent a crash
			missingCharacter = true;
			missingText = new FlxText(0, 0, 300, 'ERROR:\n$character.json', 16)
			missingText.alignment = CENTER;
		}

		try {
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(File.getContent(path)))
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)))
			#end
		} catch (e:Dynamic) {
			trace('Error loading character file of "$character": $e')
		}

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss')
		recalculateDanceIdle()
		dance()
	}

	public function loadCharacterFile(json:Dynamic) {
		isAnimateAtlas = false;

		// -----------------------------------------------------
		// ZIP-based Animate support
		// -----------------------------------------------------
		if (json.animateZip != null) {
			var zipPath = Paths.modFolders("animate/" + json.animateZip)

			if (FileSystem.exists(zipPath)) {
				trace("Loading Animate ZIP character: " + zipPath)

				isAnimateZIP = true;
				animateZIPChar = new AnimateCharacter(zipPath)

				// apply Psych JSON settings
				animateZIPChar.x = this.x;
				animateZIPChar.y = this.y;

				if (json.scale != null)
					animateZIPChar.scale.set(json.scale, json.scale)

				// STOP NORMAL LOADING
				return;
			} else {
				trace("Animate ZIP not found at: " + zipPath)
			}
		}

		#if flxanimate
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT)
		if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			isAnimateAtlas = true;
		#end

		scale.set(1, 1)
		updateHitbox()

		if (!isAnimateAtlas) {
			frames = Paths.getMultiAtlas(json.image.split(','))
		}
		#if flxanimate
		else {
			atlas = new FlxAnimate()
			atlas.showPivot = false;

			try {
				Paths.loadAnimateAtlas(atlas, json.image)
			} catch (e:haxe.Exception) {
				FlxG.log.warn('Could not load atlas ${json.image}: $e')
				trace(e.stack)
			}
		}
		#end

		imageFile = json.image;
		jsonScale = json.scale;

		if (json.scale != 1) {
			scale.set(jsonScale, jsonScale)
			updateHitbox()
		}

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer)

		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];

		vocalsFile = (json.vocals_file != null) ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true)
		editorIsPlayer = json._editor_isPlayer;

		// antialiasing
		noAntialiasing = (json.no_antialiasing == true)
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;

		if (animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop;
				var animIndices:Array<Int> = anim.indices;

				if (!isAnimateAtlas) {
					if (animIndices != null && animIndices.length > 0)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop)
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop)
				}
				#if flxanimate
				else {
					if (animIndices != null && animIndices.length > 0)
						atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop)
					else
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop)
				}
				#end

				if (anim.offsets != null && anim.offsets.length > 1)
					addOffset(anim.anim, anim.offsets[0], anim.offsets[1])
				else
					addOffset(anim.anim, 0, 0)
			}
		} // <-- THIS BRACE WAS MISSING IN YOUR FILE
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

		var reader = new AnimateFolderReader(base)
		if (!reader.valid)
			return false;

		isAnimateFolder = true;
		isAnimate = true; // Your requested fix

		animateData = reader.dataJson;
		animateLibrary = reader.libJson;
		animateAtlas = reader.toAtlas()

		if (animateAtlas != null)
			frames = animateAtlas;

		return true;
	}

// ============================================================
// AUTO-REGISTER ANIMATE SYMBOLS AS CHARACTER ANIMATIONS
// ============================================================
public function registerAnimateAnimations():Void {
    // Only apply if animate folder OR animate atlas is in use
    if (!isAnimateFolder && !isAnimateAtlas)
        return;

    var collected:Array<String> = [];

    #if flxanimate
    // ----------------------------------------
    // Collect animation names from FlxAnimate
    // ----------------------------------------
    if (atlas != null && atlas.anim != null)
    {
        var animObj:Dynamic = atlas.anim;

        if (animObj != null)
        {
            var keys:Iterable<String> = [];

            if (Reflect.hasField(animObj, "animsMap"))
                keys = cast animObj.animsMap.keys()
            else if (Reflect.hasField(animObj, "nameMap"))
                keys = cast Reflect.field(animObj, "nameMap").keys()

            for (name in keys)
            {
                if (name != null)
                    collected.push(name)
            }
        }
    }
    #end

    // ----------------------------------------
    // Animate Folder (AnimateFolderReader)
    // ----------------------------------------
    if (isAnimateFolder && animateLibrary != null)
    {
        if (Reflect.hasField(animateLibrary, "symbolDictionary"))
        {
            var dict:Dynamic = Reflect.field(animateLibrary, "symbolDictionary")

            if (dict != null && Reflect.hasField(dict, "keys"))
            {
                for (name in dict.keys())
                {
                    if (name != null)
                        collected.push(name)
                }
            }
        }
    }

    // ----------------------------------------
    // Add all collected animations
    // ----------------------------------------
    for (name in collected)
    {
        if (!Lambda.exists(animationsArray, a -> a.anim == name))
        {
            var newAnim:AnimArray = {
                anim: name,
                name: name,
                fps: 24,
                loop: false,
                indices: [],
                offsets: [0, 0]
            };

            animationsArray.push(newAnim)
            addOffset(name, 0, 0)
        }
    }
}

} // ----------------------------------------------------
