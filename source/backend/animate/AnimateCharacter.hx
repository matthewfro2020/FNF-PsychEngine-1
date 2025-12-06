package backend.animate;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import flixel.FlxSprite;
import haxe.Json;

class AnimateCharacter extends FlxSprite
{
    public var bitmapFrames:Array<BitmapData> = [];   // renamed to avoid conflict
    public var animations:Map<String, Array<Int>> = new Map();
    public var animFPS:Map<String, Int> = new Map();
    public var animLoop:Map<String, Bool> = new Map();

    public var curAnim:String = "idle";
    public var curFrame:Int = 0;
    public var timer:Float = 0;

    var reader:AnimateZipReader;

    public function new(zipPath:String)
    {
        super();
        reader = new AnimateZipReader(zipPath);

        parseAnimationData();
        buildFrames();

        play("idle");
    }

    // --------------------------------------------------------
    // LOAD ANIMATION GROUPS
    // --------------------------------------------------------
    function parseAnimationData()
    {
        // animations
        if (reader.data.animations != null)
        {
            var animMap:Map<String, Dynamic> = cast reader.data.animations;
            for (key in animMap.keys())
            {
                var list:Array<Int> = cast animMap.get(key);
                animations.set(key, list);
            }
        }

        // fps
        if (reader.data.fps != null)
        {
            var fpsMap:Map<String, Dynamic> = cast reader.data.fps;
            for (key in fpsMap.keys())
            {
                animFPS.set(key, cast fpsMap.get(key));
            }
        }

        // loops
        if (reader.data.loops != null)
        {
            var loopMap:Map<String, Dynamic> = cast reader.data.loops;
            for (key in loopMap.keys())
            {
                animLoop.set(key, cast loopMap.get(key));
            }
        }
    }

    // --------------------------------------------------------
    // BUILD FRAMES (BITMAPS)
    // --------------------------------------------------------
    function buildFrames()
    {
        var framesList:Array<Dynamic> = cast reader.data.frames;

        for (frame in framesList)
        {
            var canvas = new BitmapData(2000, 2000, true, 0);

            var layers:Array<Dynamic> = cast frame;
            for (layer in layers)
            {
                var symbol = layer.symbol + ".png";
                var bytes = reader.getPNG(symbol);
                if (bytes == null) continue;

                var bmp = BitmapData.fromBytes(bytes);

                var t = layer.transformation;
                var m = new Matrix();
                m.a = t.sx;
                m.d = t.sy;
                m.tx = t.x;
                m.ty = t.y;

                canvas.draw(bmp, m);
            }

            bitmapFrames.push(canvas);
        }
    }

    // --------------------------------------------------------
    // PLAY ANIMATION
    // --------------------------------------------------------
    public function play(name:String)
    {
        if (!animations.exists(name))
        {
            trace('Missing animation: $name');
            return;
        }

        curAnim = name;
        curFrame = 0;
        timer = 0;

        updateBitmap();
    }

    // --------------------------------------------------------
    // UPDATE LOGIC
    // --------------------------------------------------------
    override function update(elapsed:Float)
    {
        var fps = animFPS.exists(curAnim) ? animFPS.get(curAnim) : 24;

        timer += elapsed;

        if (timer >= 1 / fps)
        {
            timer = 0;

            var group = animations.get(curAnim);

            curFrame++;

            if (curFrame >= group.length)
            {
                var loop = animLoop.exists(curAnim) ? animLoop.get(curAnim) : false;

                if (loop)
                    curFrame = 0;
                else
                    curFrame = group.length - 1;
            }

            updateBitmap();
        }

        super.update(elapsed);
    }

    function updateBitmap()
    {
        var group = animations.get(curAnim);
        var frameIndex = group[curFrame];

        if (frameIndex >= 0 && frameIndex < bitmapFrames.length)
        {
            pixels = bitmapFrames[frameIndex];
            dirty = true;
        }
    }
}
