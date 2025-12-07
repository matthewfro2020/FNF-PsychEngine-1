
package objects;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;

import backend.animation.PsychAnimationController;
import backend.animate.AnimateCharacter;
import backend.animate.AnimateZipReader;
import backend.animate.AnimateFolderReader;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import openfl.utils.Assets;

// ==========================
// JSON typedefs
// ==========================
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
//   CHARACTER CLASS — CLEAN VERSION v11
// =============================================================
class Character extends FlxSprite
{
    public static final DEFAULT_CHARACTER:String = "bf";

    public var animOffsets:Map<String, Array<Dynamic>> = new Map();
	public var debugMode:Bool = false;
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

    #if flxanimate
    public var isAnimateAtlas:Bool = false;
    public var atlas:Dynamic;
    #end

    public var isAnimateFolder:Bool = false;
    public var isAnimateZIP:Bool = false;
    public var isAnimate:Bool = false;

    public var animateZIPChar:AnimateCharacter;
    public var animateData:Dynamic = null;
    public var animateLibrary:Dynamic = null;
    public var animateAtlas:FlxAtlasFrames = null;

    public var danceEveryNumBeats:Int = 2;
    public var danced:Bool = false;

    // =====================================================
    // CONSTRUCTOR
    // =====================================================
    public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false)
    {
        super(x, y);

        this.isPlayer = isPlayer;
        animation = new PsychAnimationController(this);

        changeCharacter(character);
    }

// ======================================================
// UNIVERSAL SAFE playAnim()
// Works with:
//  • PNG/MultiAtlas
//  • PsychFlxAnimate atlas
//  • ZIP AnimateCharacter
// ======================================================
public function playAnim(name:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void
{
    // ZIP
    if (isAnimateZIP && animateZIPChar != null)
    {
        animateZIPChar.play(name);
        return;
    }

    // ATLAS
    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
    {
        atlas.anim.play(name, forced);
        return;
    }
    #end

    // PNG
    if (animation != null)
        animation.play(name, forced, reversed, frame);

    if (animOffsets.exists(name))
        offset.set(animOffsets[name][0], animOffsets[name][1]);
}

    public function addOffset(name:String, x:Float = 0, y:Float = 0):Void {
        if (animOffsets == null) animOffsets = new Map();
        animOffsets.set(name, [x, y]);
    }


public inline function hasAnimation(name:String):Bool
{
    // ZIP animate
    if (isAnimateZIP && animateZIPChar != null)
        return animateZIPChar.hasAnimation(name);

    // PsychFlxAnimate (flxanimate)
    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
        return atlas.anim.exists(name);
    #end

    // PNG animations
    return animation != null && animation.exists(name);
}
public var animPaused(get, set):Bool;
private function get_animPaused():Bool
{
    if (isAnimateZIP && animateZIPChar != null)
        return animateZIPChar.animPaused;

    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
        return atlas.anim.paused;
    #end

    return hasCurAnim() ? animation.curAnim.paused : false;
}

private function set_animPaused(value:Bool):Bool
{
    if (isAnimateZIP && animateZIPChar != null)
    {
        animateZIPChar.animPaused = value;
        return value;
    }

    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
    {
        if (value) atlas.pauseAnimation();
        else atlas.resumeAnimation();
        return value;
    }
    #end

    if (hasCurAnim())
        animation.curAnim.paused = value;

    return value;
}

public inline function isAnimationNull():Bool
{
    if (isAnimateZIP && animateZIPChar != null)
        return animateZIPChar.getCurrentAnimation() == null;

    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
        return atlas.anim.curSymbol == null;
    #end

    return (animation == null || animation.curAnim == null);
}

public inline function getAnimationName():String
{
    if (isAnimateZIP && animateZIPChar != null)
        return animateZIPChar.getCurrentAnimation();

    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
        return atlas.anim.curSymbol;
    #end

    return hasCurAnim() ? animation.curAnim.name : "";
}

public inline function isAnimationFinished():Bool
{
    if (isAnimateZIP && animateZIPChar != null)
        return animateZIPChar.isFinished();

    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
        return atlas.anim.finished;
    #end

    return hasCurAnim() ? animation.curAnim.finished : true;
}


public function finishAnimation():Void
{
    if (isAnimateZIP && animateZIPChar != null)
    {
        animateZIPChar.finishAnimation();
        return;
    }

    #if flxanimate
    if (isAnimateAtlas && atlas != null && atlas.anim != null)
    {
        atlas.anim.finish();
        return;
    }
    #end

    if (animation != null && animation.curAnim != null)
        animation.curAnim.finish();
}

    // =====================================================
    // CHANGE CHARACTER
    // =====================================================
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
            missingCharacter = true;
            missingText = new FlxText(0, 0, 400, "Missing: " + char + ".json", 16);
            return;
        }

        var raw = #if MODS_ALLOWED File.getContent(path); #else Assets.getText(path); #end
        var json:Dynamic = Json.parse(raw);

        loadCharacterFile(json);
        hasMissAnimations = (
            hasAnimation("singLEFTmiss") ||
            hasAnimation("singDOWNmiss") ||
            hasAnimation("singUPmiss") ||
            hasAnimation("singRIGHTmiss")
        );

        recalculateDanceIdle();
        dance();
    }

    // =====================================================
    // RECALCULATE DANCE IDLE
    // =====================================================
    public function recalculateDanceIdle():Void
    {
        var last = danceIdle;

        danceIdle =
            hasAnimation("danceLeft" + idleSuffix) &&
            hasAnimation("danceRight" + idleSuffix);

        if (last != danceIdle)
            danceEveryNumBeats = danceIdle ? 1 : 2;
    }

    // =====================================================
    // DANCE
    // =====================================================
public function dance():Void
{
    if (skipDance || specialAnim)
        return;

    // Block early dance calls for ZIP or atlas until fully initialized
    if (isAnimateZIP)
    {
        if (animateZIPChar == null || animateZIPChar.getCurrentAnimation() == null)
            return; // do NOT play PNG animations
    }

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

    // =====================================================
    // LOAD CHARACTER FILE (JSON)
    // =====================================================
    public function loadCharacterFile(json:Dynamic):Void
    {
        isAnimateAtlas = false;
        isAnimateFolder = false;
        isAnimateZIP = false;
        isAnimate = false;

        // ZIP loader
        if (json.animateZip != null)
        {
            var zipPath = Paths.modFolders("animate/" + json.animateZip);
            #if MODS_ALLOWED
            if (FileSystem.exists(zipPath))
            {
                isAnimateZIP = true;
                isAnimate = true;
                animateZIPChar = new AnimateCharacter(zipPath);
                return;
            }
            #end
        }

        // Animate Atlas loader
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
            try Paths.loadAnimateAtlas(atlas, json.image) catch (e:Dynamic) {
                isAnimateAtlas = false;
            }
        }
        #end

        if (!isAnimateAtlas)
        {
            frames = Paths.getMultiAtlas(json.image.split(","));
        }

        // Basic JSON
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
            (json.healthbar_colors != null && json.healthbar_colors.length >= 3)
            ? json.healthbar_colors
            : [161, 161, 161];

        vocalsFile = (json.vocals_file != null) ? json.vocals_file : "";
        originalFlipX = (json.flip_x == true);
        editorIsPlayer = json._editor_isPlayer;

        noAntialiasing = (json.no_antialiasing == true);
        antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

        animationsArray = json.animations;

        // Build animation list
        for (anim in animationsArray)
        {
            var id = anim.anim;
            var name = anim.name;
            var fps = anim.fps;
            var loop = anim.loop;
            var inds = anim.indices;

            #if !flxanimate
            if (inds != null && inds.length > 0)
                animation.addByIndices(id, name, inds, "", fps, loop);
            else
                animation.addByPrefix(id, name, fps, loop);
            #end

            #if flxanimate
            if (isAnimateAtlas && atlas != null)
            {
                if (inds != null && inds.length > 0)
                    atlas.anim.addBySymbolIndices(id, name, inds, fps, loop);
                else
                    atlas.anim.addBySymbol(id, name, fps, loop);
            }
            #end

            if (anim.offsets != null && anim.offsets.length >= 2)
                addOffset(id, anim.offsets[0], anim.offsets[1]);
            else
                addOffset(id, 0, 0);
        }
    }

inline function hasCurAnim():Bool
{
    return animation != null && animation.curAnim != null;
}

}