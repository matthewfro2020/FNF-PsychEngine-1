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

// =====================
// Character JSON formats
// =====================
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
};

typedef AnimArray = {
    var anim:String;
    var name:String;
    var fps:Int;
    var loop:Bool;
    var indices:Array<Int>;
    var offsets:Array<Int>;
};


// =============================================================
//   CHARACTER CLASS — HYBRID FLXANIMATE / PSYCHFLXANIMATE SUPPORT
// =============================================================
class Character extends FlxSprite
{
    public static final DEFAULT_CHARACTER:String = "bf";

    // JSON data
    public var animOffsets:Map<String, Array<Dynamic>> = new Map();
    public var animationsArray:Array<AnimArray> = [];
    public var extraData:Map<String, Dynamic> = new Map();

    // Character state
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

    // ================================
    //      ANIMATE — HYBRID SYSTEM
    // ================================
    public var isAnimateAtlas:Bool = false;
    public var isAnimateFolder:Bool = false;
    public var isAnimateZIP:Bool = false;
    public var isAnimate:Bool = false;

    // auto-detect PsychFlxAnimate OR standard FlxAnimate
    #if flxanimate
    // Declared as Dynamic — allows PsychFlxAnimate OR FlxAnimate
    public var atlas:Dynamic;
    #end

    public var animateZIPChar:AnimateCharacter;
    public var animateData:Dynamic = null;
    public var animateLibrary:Dynamic = null;
    public var animateAtlas:FlxAtlasFrames = null;

    // GF dance logic
    public var danceEveryNumBeats:Int = 2;
    public var danced:Bool = false;
    // =============================================================
    //   CONSTRUCTOR
    // =============================================================
    public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
    {
        super(x, y);

        this.isPlayer = isPlayer;
        animation = new PsychAnimationController(this);
        animOffsets = new Map<String, Array<Dynamic>>();

        changeCharacter(character);
    }


    // =============================================================
    //   CHANGE CHARACTER (Loads JSON + animations)
    // =============================================================
    public function changeCharacter(char:String):Void
    {
        curCharacter = char;
        animationsArray = [];
        animOffsets = new Map();

        var path = Paths.getPath("characters/" + char + ".json", TEXT);

        #if MODS_ALLOWED
        var exists = FileSystem.exists(path);
        #else
        var exists = Assets.exists(path);
        #end

        if (!exists)
        {
            path = Paths.getSharedPath("characters/" + DEFAULT_CHARACTER + ".json");
            missingCharacter = true;
            missingText = new FlxText(0, 0, 300, "ERROR:\n" + char + ".json", 16);
        }

        try
        {
            var raw =
                #if MODS_ALLOWED
                File.getContent(path);
                #else
                Assets.getText(path);
                #end

            var json:Dynamic = Json.parse(raw);
            loadCharacterFile(json);
        }
        catch (e:Dynamic)
        {
            trace("[Character] Error loading '" + char + "': " + e);
        }

        // detect miss animations
        hasMissAnimations =
            hasAnimation("singLEFTmiss") ||
            hasAnimation("singDOWNmiss") ||
            hasAnimation("singUPmiss") ||
            hasAnimation("singRIGHTmiss");

        recalculateDanceIdle();
        dance();
    }


    // =============================================================
    //   RECALCULATE DANCE IDLE
    //   Fixes your earlier error: this function was missing!
    // =============================================================
    public function recalculateDanceIdle():Void
    {
        var last = danceIdle;

        danceIdle =
            hasAnimation("danceLeft" + idleSuffix) &&
            hasAnimation("danceRight" + idleSuffix);

        // set default beat rate
        if (last != danceIdle)
        {
            danceEveryNumBeats = danceIdle ? 1 : 2;
        }
    }


    // =============================================================
    //   DANCE FUNCTION
    // =============================================================
    public function dance():Void
    {
        if (debugMode || skipDance || specialAnim)
            return;

        if (danceIdle)
        {
            danced = !danced;
            if (danced)
                playAnim("danceRight" + idleSuffix);
            else
                playAnim("danceLeft" + idleSuffix);
        }
        else if (hasAnimation("idle" + idleSuffix))
        {
            playAnim("idle" + idleSuffix);
        }
    }
    // =============================================================
    //   LOAD CHARACTER FILE (JSON)
    // =============================================================
    public function loadCharacterFile(json:Dynamic):Void
    {
        // Reset animate modes
        isAnimateAtlas = false;
        isAnimateFolder = false;
        isAnimateZIP = false;
        isAnimate = false;

        // ------------------------------
        //  ZIP-BASED ANIMATE LOADING
        // ------------------------------
        if (json.animateZip != null)
        {
            var zipPath = Paths.modFolders("animate/" + json.animateZip);

            #if MODS_ALLOWED
            if (FileSystem.exists(zipPath))
            #else
            if (false)
            #end
            {
                isAnimateZIP = true;
                isAnimate = true;

                animateZIPChar = new AnimateCharacter(zipPath);
                return; // STOP normal PNG or Atlas loading
            }
        }

        // ------------------------------
        //   DETECT ANIMATE ATLAS
        // ------------------------------
        #if flxanimate
        var animPath = Paths.getPath("images/" + json.image + "/Animation.json", TEXT);

        #if MODS_ALLOWED
        var atlasExists = FileSystem.exists(animPath);
        #else
        var atlasExists = Assets.exists(animPath);
        #end

        if (atlasExists)
        {
            isAnimateAtlas = true;
            isAnimate = true;

            atlas = new PsychFlxAnimate();
            try {
                Paths.loadAnimateAtlas(atlas, json.image);
            }
            catch (e:Dynamic) {
                FlxG.log.warn("[Character] Failed to load Animate atlas '" + json.image + "': " + e);
                isAnimateAtlas = false;
            }
        }
        #end


        // ------------------------------
        //   FALLBACK: NORMAL PNG MULTI-ATLAS
        // ------------------------------
        if (!isAnimateAtlas)
        {
            frames = Paths.getMultiAtlas(json.image.split(","));
        }

        // ------------------------------
        //  BASIC JSON PARAMETERS
        // ------------------------------
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

        flipX = (json.flip_x != isPlayer); // Psych logic


        // health bar colors
        if (json.healthbar_colors != null && json.healthbar_colors.length >= 3)
            healthColorArray = json.healthbar_colors;
        else
            healthColorArray = [161, 161, 161];


        // vocals
        vocalsFile = (json.vocals_file != null) ? json.vocals_file : "";

        originalFlipX = (json.flip_x == true);
        editorIsPlayer = json._editor_isPlayer;


        // antialiasing
        noAntialiasing = (json.no_antialiasing == true);
        antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;


        // ------------------------------
        //  LOAD ANIMATIONS LIST
        // ------------------------------
        animationsArray = json.animations;

        if (animationsArray != null)
        {
            for (anim in animationsArray)
            {
                var id = anim.anim;
                var name = anim.name;
                var fps = anim.fps;
                var loop = anim.loop;
                var inds = anim.indices;

                // PNG/MultiAtlas mode
                if (!isAnimateAtlas)
                {
                    if (inds != null && inds.length > 0)
                        animation.addByIndices(id, name, inds, "", fps, loop);
                    else
                        animation.addByPrefix(id, name, fps, loop);
                }

                // Animate Atlas mode
                #if flxanimate
                if (isAnimateAtlas && atlas != null)
                {
                    if (inds != null && inds.length > 0)
                        atlas.anim.addBySymbolIndices(id, name, inds, fps, loop);
                    else
                        atlas.anim.addBySymbol(id, name, fps, loop);
                }
                #end

                // offset
                if (anim.offsets != null && anim.offsets.length >= 2)
                    addOffset(id, anim.offsets[0], anim.offsets[1]);
                else
                    addOffset(id, 0, 0);
            }
        }
    }
    // =============================================================
    //   LOAD CHARACTER FILE (JSON)
    // =============================================================
    public function loadCharacterFile(json:Dynamic):Void
    {
        // Reset animate modes
        isAnimateAtlas = false;
        isAnimateFolder = false;
        isAnimateZIP = false;
        isAnimate = false;

        // ------------------------------
        //  ZIP-BASED ANIMATE LOADING
        // ------------------------------
        if (json.animateZip != null)
        {
            var zipPath = Paths.modFolders("animate/" + json.animateZip);

            #if MODS_ALLOWED
            if (FileSystem.exists(zipPath))
            #else
            if (false)
            #end
            {
                isAnimateZIP = true;
                isAnimate = true;

                animateZIPChar = new AnimateCharacter(zipPath);
                return; // STOP normal PNG or Atlas loading
            }
        }

        // ------------------------------
        //   DETECT ANIMATE ATLAS
        // ------------------------------
        #if flxanimate
        var animPath = Paths.getPath("images/" + json.image + "/Animation.json", TEXT);

        #if MODS_ALLOWED
        var atlasExists = FileSystem.exists(animPath);
        #else
        var atlasExists = Assets.exists(animPath);
        #end

        if (atlasExists)
        {
            isAnimateAtlas = true;
            isAnimate = true;

            atlas = new PsychFlxAnimate();
            try {
                Paths.loadAnimateAtlas(atlas, json.image);
            }
            catch (e:Dynamic) {
                FlxG.log.warn("[Character] Failed to load Animate atlas '" + json.image + "': " + e);
                isAnimateAtlas = false;
            }
        }
        #end


        // ------------------------------
        //   FALLBACK: NORMAL PNG MULTI-ATLAS
        // ------------------------------
        if (!isAnimateAtlas)
        {
            frames = Paths.getMultiAtlas(json.image.split(","));
        }

        // ------------------------------
        //  BASIC JSON PARAMETERS
        // ------------------------------
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

        flipX = (json.flip_x != isPlayer); // Psych logic


        // health bar colors
        if (json.healthbar_colors != null && json.healthbar_colors.length >= 3)
            healthColorArray = json.healthbar_colors;
        else
            healthColorArray = [161, 161, 161];


        // vocals
        vocalsFile = (json.vocals_file != null) ? json.vocals_file : "";

        originalFlipX = (json.flip_x == true);
        editorIsPlayer = json._editor_isPlayer;


        // antialiasing
        noAntialiasing = (json.no_antialiasing == true);
        antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;


        // ------------------------------
        //  LOAD ANIMATIONS LIST
        // ------------------------------
        animationsArray = json.animations;

        if (animationsArray != null)
        {
            for (anim in animationsArray)
            {
                var id = anim.anim;
                var name = anim.name;
                var fps = anim.fps;
                var loop = anim.loop;
                var inds = anim.indices;

                // PNG/MultiAtlas mode
                if (!isAnimateAtlas)
                {
                    if (inds != null && inds.length > 0)
                        animation.addByIndices(id, name, inds, "", fps, loop);
                    else
                        animation.addByPrefix(id, name, fps, loop);
                }

                // Animate Atlas mode
                #if flxanimate
                if (isAnimateAtlas && atlas != null)
                {
                    if (inds != null && inds.length > 0)
                        atlas.anim.addBySymbolIndices(id, name, inds, fps, loop);
                    else
                        atlas.anim.addBySymbol(id, name, fps, loop);
                }
                #end

                // offset
                if (anim.offsets != null && anim.offsets.length >= 2)
                    addOffset(id, anim.offsets[0], anim.offsets[1]);
                else
                    addOffset(id, 0, 0);
            }
        }
    }
    // =============================================================
    //  ANIMATE FOLDER LOADING (AnimateFolderReader)
    // =============================================================
    public function tryLoadAnimateFolder(char:String):Bool
    {
        var base = Paths.modFolders("characters/animate/" + char);
        var data = base + "/data.json";
        var lib = base + "/library.json";
        var sym = base + "/symbols";

        #if MODS_ALLOWED
        if (!FileSystem.exists(data) || !FileSystem.exists(lib) || !FileSystem.exists(sym))
            return false;
        #else
        return false;
        #end

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


    // =============================================================
    //   AUTO-REGISTER ANIMATIONS FROM ATLAS AND FOLDER
    // =============================================================
    public function registerAnimateAnimations():Void
    {
        if (!isAnimateFolder && !isAnimateAtlas)
            return;

        var collected:Array<String> = [];

        // ----------------------------------------------
        // 1. FlxAnimate (Atlas Animate)
        // We only iterate public fields of atlas.anim
        // (No nameMap / animsMap — private!)
        // ----------------------------------------------
        #if flxanimate
        if (isAnimateAtlas && atlas != null && atlas.anim != null)
        {
            var fields = Reflect.fields(atlas.anim);
            for (f in fields)
            {
                if (f != null)
                    collected.push(f);
            }
        }
        #end

        // ----------------------------------------------
        // 2. Animate Folder symbols
        // ----------------------------------------------
        if (isAnimateFolder && animateLibrary != null)
        {
            if (Reflect.hasField(animateLibrary, "symbolDictionary"))
            {
                var dict:Dynamic = Reflect.field(animateLibrary, "symbolDictionary");

                if (dict != null && Reflect.hasField(dict, "keys"))
                {
                    var keys = dict.keys();
                    for (name in keys)
                    {
                        if (name != null)
                            collected.push(name);
                    }
                }
            }
        }

        // ----------------------------------------------
        // 3. Register new AnimArray entries
        // ----------------------------------------------
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
                animationsArray.push(newAnim);
                addOffset(name, 0, 0);
            }
        }
    }


    // =============================================================
    //  DANCE + IDLE LOGIC
    // =============================================================
    public function recalculateDanceIdle():Void
    {
        var leftExists  = hasAnimation("danceLeft"  + idleSuffix);
        var rightExists = hasAnimation("danceRight" + idleSuffix);

        danceIdle = (leftExists && rightExists);

        // Default for characters with no dance anims = slow idle
        danceEveryNumBeats = danceIdle ? 1 : 2;
    }

    public function dance():Void
    {
        if (debugMode || skipDance || specialAnim)
            return;

        if (danceIdle)
        {
            danced = !danced;
            playAnim(danced ? "danceRight" + idleSuffix : "danceLeft" + idleSuffix);
        }
        else if (hasAnimation("idle" + idleSuffix))
        {
            playAnim("idle" + idleSuffix);
        }
    }


    // =============================================================
    //   HELPER FUNCTIONS USED BY PlayState + Editor
    // =============================================================
    public function hasAnimation(name:String):Bool
    {
        return animOffsets.exists(name);
    }

    public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
    {
        animOffsets[name] = [x, y];
    }

    public function quickAnimAdd(id:String, prefix:String):Void
    {
        animation.addByPrefix(id, prefix, 24, false);
    }


    // =============================================================
    // Animation name retrieval — Editor & PlayState safe
    // =============================================================
    inline public function getAnimationName():String
    {
        return (animation.curAnim != null) ? animation.curAnim.name : "";
    }

    inline public function isAnimationNull():Bool
    {
        return animation.curAnim == null;
    }

    inline public function isAnimationFinished():Bool
    {
        return animation.curAnim != null && animation.curAnim.finished;
    }

    public function finishAnimation():Void
    {
        if (animation.curAnim != null)
            animation.curAnim.finish();
    }
    // =============================================================
    // UPDATE (Psych 1.0.4 Safe Hybrid Animate)
    // =============================================================
    override function update(elapsed:Float):Void
    {
        // ---------------------------------------------------------
        // Animate Atlas update
        // ---------------------------------------------------------
        #if flxanimate
        if (isAnimateAtlas && atlas != null)
        {
            atlas.update(elapsed);
        }
        #end

        // ---------------------------------------------------------
        // ZIP Animate update
        // ---------------------------------------------------------
        if (isAnimateZIP && animateZIPChar != null)
        {
            animateZIPChar.update(elapsed);
        }

        super.update(elapsed);

        // ---------------------------------------------------------
        // Hey timer logic
        // ---------------------------------------------------------
        if (heyTimer > 0)
        {
            var rate = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
            heyTimer -= elapsed * rate;

            if (heyTimer <= 0)
            {
                heyTimer = 0;

                var nm = getAnimationName();
                if (specialAnim && (nm == "hey" || nm == "cheer"))
                {
                    specialAnim = false;
                    dance();
                }
            }
        }
        else if (specialAnim && isAnimationFinished())
        {
            specialAnim = false;
            dance();
        }

        // ---------------------------------------------------------
        // Miss animation auto-recovery
        // ---------------------------------------------------------
        if (getAnimationName().endsWith("miss") && isAnimationFinished())
        {
            finishAnimation();
            dance();
        }

        // ---------------------------------------------------------
        // Hold timer for opponent vocals
        // ---------------------------------------------------------
        if (getAnimationName().startsWith("sing"))
            holdTimer += elapsed;
        else if (isPlayer)
            holdTimer = 0;

        if (!isPlayer && holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration)
        {
            holdTimer = 0;
            dance();

            var nm = getAnimationName();
            if (isAnimationFinished() && hasAnimation(nm + "-loop"))
                playAnim(nm + "-loop");
        }
    }


    // =============================================================
    // PLAY ANIMATION (ZIP + Atlas + PNG)
    // =============================================================
    public function playAnim(name:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void
    {
        // ZIP Animate
        if (isAnimateZIP && animateZIPChar != null)
        {
            animateZIPChar.play(name);
            return;
        }

        // Atlas Animate
        #if flxanimate
        if (isAnimateAtlas && atlas != null)
        {
            atlas.anim.play(name, forced);
            return;
        }
        #end

        // PNG / XML animations (default Psych)
        if (animation != null)
            animation.play(name, forced, reversed, frame);

        // Apply offsets
        if (animOffsets.exists(name))
            offset.set(animOffsets[name][0], animOffsets[name][1]);
    }


    // =============================================================
    // DESTROY
    // =============================================================
    public override function destroy():Void
    {
        #if flxanimate
        atlas = FlxDestroyUtil.destroy(atlas);
        #end

        animateZIPChar = FlxDestroyUtil.destroy(animateZIPChar);
        animateAtlas = FlxDestroyUtil.destroy(animateAtlas);

        super.destroy();
    }
    // =============================================================
    // ANIMATION HELPERS
    // =============================================================

    public inline function isAnimationFinished():Bool
    {
        if (animation == null || animation.curAnim == null)
            return false;
        return animation.curAnim.finished;
    }

    public inline function getAnimationName():String
    {
        return (animation != null && animation.curAnim != null)
            ? animation.curAnim.name
            : "";
    }

    // =============================================================
    // RE-CENTER & MIDPOINT HELPERS (Psych-Compatible)
    // =============================================================

    public inline function getMidpointX():Float
    {
        return x + (width * 0.5);
    }

    public inline function getMidpointY():Float
    {
        return y + (height * 0.5);
    }

    public inline function getScreenPosition(?pt:FlxPoint):FlxPoint
    {
        pt = (pt == null ? FlxPoint.get() : pt);
        pt.set(getMidpointX(), getMidpointY());
        return pt;
    }

    // =============================================================
    // FINAL DANCE LOGIC
    // =============================================================
    
    public function recalculateDanceIdle():Void
    {
        // If character has BOTH danceLeft/danceRight → use danceIdle mode.
        if (hasAnimation("danceLeft") || hasAnimation("danceRight"))
        {
            danceIdle = true;
        }
        else
        {
            danceIdle = false;
        }

        danced = false;
    }


    // Compatibility helper used by PlayState and editor
    public inline function resetDance():Void
    {
        danced = false;
    }

    public inline function doDance():Void
    {
        danced = true;
        dance();
    }


    // =============================================================
    // EDITOR-SAFE ANIMATION ACCESSORS
    // =============================================================

    public inline function isAnimationNull():Bool
    {
        return (animation == null || animation.curAnim == null);
    }

    public var animPaused(get, set):Bool;

    private function get_animPaused():Bool
    {
        return (animation != null && animation.curAnim != null)
            ? animation.curAnim.paused
            : false;
    }

    private function set_animPaused(v:Bool):Bool
    {
        if (animation != null && animation.curAnim != null)
            animation.curAnim.paused = v;
        return v;
    }

} // <--- FINAL CLOSING BRACE (NO MORE AFTER THIS)
