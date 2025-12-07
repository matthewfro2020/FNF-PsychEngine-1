package flxanimate;

import flxanimate.FlxAnimate;

class PsychFlxAnimate extends FlxAnimate {
    public function new() {
        super();
        showPivot = false;
    }

    /**
     * Safely plays an animation.
     * If it doesn't exist, it falls back to idle or first symbol.
     */
    public function safePlay(name:String):Void {
        try {
            anim.play(name);
        } catch (e:Dynamic) {
            trace("[PsychFlxAnimate] Missing animation: " + name);

            // Fallback 1 — idle
            if (anim.exists("idle")) {
                anim.play("idle");
                return;
            }

            // Fallback 2 — first available symbol
            var keys = anim.animations.animations.keys();
            if (keys.hasNext()) {
                var first = keys.next();
                trace("[PsychFlxAnimate] Fallback to: " + first);
                anim.play(first);
            }
        }
    }
}
