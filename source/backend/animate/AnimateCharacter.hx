package backend.animate;

import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import sys.io.File;
import openfl.display.PNGDecoder;
import flixel.FlxSprite;
import haxe.Json;

class AnimateCharacter extends FlxSprite
{
    public var frames:Array<BitmapData> = [];
    public var curFrame:Int = 0;
    public var timer:Float = 0;
    public var frameRate:Int = 24;

    var reader:AnimateZipReader;

    public function new(zipPath:String)
    {
        super();

        reader = new AnimateZipReader(zipPath);
        buildFrames();

        if (frames.length > 0)
            pixels = frames[0];
    }

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
                var mat = new Matrix();
                mat.translate(t.x, t.y);
                mat.scale(t.sx, t.sy);

                canvas.draw(bmp, mat);
            }

            frames.push(canvas);
        }
    }

    override function update(elapsed:Float)
    {
        timer += elapsed;

        if (timer >= 1 / frameRate)
        {
            timer = 0;
            curFrame = (curFrame + 1) % frames.length;
            pixels = frames[curFrame];
            dirty = true;
        }

        super.update(elapsed);
    }
}
