package;

import kha.Scheduler;
import kha.System;

class Main {
	public static function main() {
		System.init({ title : "ArmorUI", width : 1240, height : 640 }, initialized);
	}
	
	private static function initialized(): Void {
		var game = new Elements();
		System.notifyOnRender(game.render);
		Scheduler.addTimeTask(game.update, 0, 1 / 60);
	}
}
