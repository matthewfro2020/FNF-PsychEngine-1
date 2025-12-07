package backend.animate;

import flxanimate.FlxAnimate;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import openfl.display.BitmapData;

/**
 * AnimateCharacter
 * ----------------
 * A universal wrapper that lets Psych Engine treat Animate
 * ZIP/FOLDER/ATLAS characters EXACTLY like PNG characters.
 *
 * Backends supported:
 *   - AnimateZipReader
 *   - AnimateFolderReader
 *   - PsychFlxAnimate atlas (Animation.json + spritemap1.json/png)
 *
 * Provides:
 *   play(), hasAnimation(), getCurrentAnimation(),
 *   isFinished(), finishAnimation(), animPaused,
 *   and update() integration.
 */
class AnimateCharacter extends FlxSprite
{
    public var readerZip:AnimateZipReader = null;
    public var readerFolder:AnimateFolderReader = null;

    public var isZip:Bool = false;
    public var isFolder:Bool = false;

    public var anim:FlxAnimate;

    public function new(source:String, ?isFolderMode:Bool = false)
    {
        super();

        if (isFolderMode)
        {
            isFolder = true;
            readerFolder = new AnimateFolderReader(source);

            if (!readerFolder.valid)
            {
                trace("[AnimateCharacter] Folder reader failed.");
                return;
            }

            anim = readerFolder.atlas;
        }
        else
        {
            isZip = true;
            readerZip = new AnimateZipReader(source);

            if (!readerZip.valid)
            {
                trace("[AnimateCharacter] ZIP reader failed.");
                return;
            }

            anim = readerZip.atlas;
        }

        // Sync FlxSprite transforms to FlxAnimate
        anim.cameras = cameras;
        anim.scrollFactor = scrollFactor;

        this.frames = anim.frames;
    }

    // ============================================================
    // PLAY ANIMATION
    // ============================================================
    public inline function play(name:String, force:Bool = true):Void
    {
        if (anim == null) return;
        anim.anim.play(name, force);
    }

    // ============================================================
    // ANIMATION EXISTS?
    // ============================================================
    public inline function hasAnimation(name:String):Bool
    {
        return (anim != null && anim.anim.exists(name));
    }

    // ============================================================
    // FINISHED PLAYING?
    // ============================================================
    public inline function isFinished():Bool
    {
        if (anim == null) return true;
        return anim.anim.finished;
    }

    // ============================================================
    // CURRENT ANIMATION NAME
    // ============================================================
    public inline function getCurrentAnimation():String
    {
        if (anim == null) return "";
        if (anim.anim.curAnim == null) return "";
        return anim.anim.curAnim.name;
    }

    // ============================================================
    // FORCE ANIMATION TO END
    // ============================================================
    public inline function finishAnimation():Void
    {
        if (anim == null) return;
        anim.anim.finish();
    }

    // ============================================================
    // PAUSE/RESUME
    // ============================================================
    public var animPaused(get, set):Bool;

    private function get_animPaused():Bool
    {
        if (anim == null) return false;
        return anim.anim.paused;
    }

    private function set_animPaused(v:Bool):Bool
    {
        if (anim != null)
        {
            if (v) anim.pauseAnimation();
            else anim.resumeAnimation();
        }
        return v;
    }

    // ============================================================
    // UPDATE — required for Animate animations
    // ============================================================
    override public function update(elapsed:Float):Void
    {
        if (anim != null)
            anim.update(elapsed);

        super.update(elapsed);
    }

    // ============================================================
    // DRAW — required for FlxAnimate instead of FlxSprite
    // ============================================================
    override public function draw():Void
    {
        if (anim != null)
        {
            @:privateAccess
            {
                anim.x = this.x;
                anim.y = this.y;
                anim.scale = this.scale;
                anim.offset = this.offset;
                anim.flipX = this.flipX;
                anim.flipY = this.flipY;
                anim.alpha = this.alpha;
                anim.angle = this.angle;
                anim.visible = this.visible;
                anim.antialiasing = this.antialiasing;
                anim.colorTransform = this.colorTransform;
                anim.color = this.color;
                anim.shader = this.shader;
            }
            anim.draw();
            return;
        }

        super.draw();
    }
}
