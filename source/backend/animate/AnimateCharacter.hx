
package backend.animate;

import flxanimate.FlxAnimate;

class AnimateCharacter {
    public var anim:FlxAnimate;
    public var current:String = null;

    public function new(path:String) {
        anim = new FlxAnimate();
        flxanimate.animate.io.AnimateLoader.loadInto(anim, path);
        anim.showPivot = false;
    }

    public function play(name:String) {
        if (!hasAnimation(name)) return;
        current = name;
        anim.anim.play(name, true);
    }

    public inline function hasAnimation(a:String):Bool {
        return anim.anim.exists(a);
    }

    public inline function getCurrentAnimation():String {
        return current;
    }

    public inline function isFinished():Bool {
        return anim.anim.finished;
    }

    public inline function finishAnimation():Void {
        anim.anim.finish();
    }
}
