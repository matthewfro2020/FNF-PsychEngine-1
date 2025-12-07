
package backend.animate;

import flxanimate.FlxAnimate;
import flxanimate.animate.io.AnimateLoader;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;

class AnimateFolderReader {
    public var valid:Bool = false;
    public var atlas:FlxAnimate;

    public function new(base:String) {
        if (!FileSystem.exists(base)) return;

        atlas = new FlxAnimate();
        atlas.showPivot = false;

        try {
            AnimateLoader.loadInto(atlas, base);
            valid = true;
        } catch (e) {
            trace("[AnimateFolderReader] FAILED: " + e);
            valid = false;
        }
    }
}
