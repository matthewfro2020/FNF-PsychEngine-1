
package backend.animate;

import flxanimate.animate.io.AnimateZipReader;

class AnimateZIP {
    public static function load(path:String) {
        return AnimateZipReader.readZip(path);
    }
}
