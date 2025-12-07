
package backend.animate;

import flxanimate.FlxAnimate;

class PsychFlxAnimate extends FlxAnimate {
    public function new() {
        super();
        showPivot = false;
    }

    public inline function safePlay(a:String) {
        try anim.play(a); catch(e) trace("[Animate] Missing animation: " + a);
    }
}
