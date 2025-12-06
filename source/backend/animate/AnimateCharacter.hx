package backend.animate;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import flixel.FlxSprite;
import haxe.Json;

class AnimateCharacter extends FlxSprite
{
    public var frames:Array<BitmapData> = [];
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
    // LOAD ANIMATION GROUPS FROM data.json
    // --------------------------------------------------------
    function parseAnimationData()
    {
        if (reader.data.animations != null)
        {
            for (name => list in reader.data.animations)
                animations.set(name, list);
        }

        if (reader.data.fps != null)
        {
            for (name => fps in reader.data.fps)
                animFPS.set(name, fps);
        }

        if (reader.data.loops != null)
        {
            for (name => loop in reader.data.loops)
                animLoop.set(name, loop);
        }
    }


    // --------------------------------------------------------
    // REBUILD FRAME BITMAPS
    // --------------------------------------------------------
    function buildFrames()
    {
        for (frame in reader.data.frames)
        {
            var canvas = new BitmapData(2000, 2000, true, 0);

            for (layer in frame)
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

            frames.push(canvas);
        }
    }


    // --------------------------------------------------------
    // PLAY ANIMATION
    // --------------------------------------------------------
    public function play(name:String)
    {
        if (!animations.exists(name))
        {
            trace("Missing animation: " + name);
            return;
        }

        curAnim = name;
        curFrame = 0;
        timer = 0;

        updateBitmap();
    }


    // --------------------------------------------------------
    // UPDATE FRAME
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
                if (animLoop.get(curAnim))
                    curFrame = 0;
                else
                {
                    curFrame = group.length - 1; // stay on last frame
                }
            }

            updateBitmap();
        }

        super.update(elapsed);
    }


    // --------------------------------------------------------
    // DRAW FRAME
    // --------------------------------------------------------
    function updateBitmap()
    {
        var group = animations.get(curAnim);
        var frameIndex = group[curFrame];

        if (frameIndex >= 0 && frameIndex < frames.length)
        {
            pixels = frames[frameIndex];
            dirty = true;
        }
    }
}
