package ;

import zui.Canvas;

class Main {

	public static var prefs:Dynamic = null;
	static var inst:Elements;

	public static function main() {
		var w = kha.Display.width(0);
		var h = kha.Display.height(0);
		kha.System.init({ title : "ArmorUI", width : w, height : h, resizable: true }, initialized);
	}
	
	static function initialized() {

		kha.LoaderImpl.loadBlobFromDescription({ files: ["prefs.json"] }, function(blob:kha.Blob) {
			prefs = haxe.Json.parse(blob.toString());

			kha.LoaderImpl.loadBlobFromDescription({ files: [prefs.path] }, function(cblob:kha.Blob) {
				var raw:TCanvas = haxe.Json.parse(cblob.toString());
				inst = new Elements(raw);
			});
		});
	}
}
