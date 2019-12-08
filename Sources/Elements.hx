package ;

import kha.math.Vector2;
import kha.input.KeyCode;
import zui.*;
import zui.Zui;
import zui.Canvas;
import zui.Popup;


using kha.graphics2.GraphicsExtension;
using zui.Ext;

@:access(zui.Zui)
class Elements {
	var ui:Zui;
	var cui:Zui;
	var canvas:TCanvas;

	static var defaultWindowW = 240;
	static var windowW = defaultWindowW;
	static var uiw(get, null):Int;
	static function get_uiw():Int {
		return Std.int(windowW * Main.prefs.scaleFactor);
	}
	var toolbarw(get, null):Int;
	function get_toolbarw():Int {
		return Std.int(140 * ui.SCALE());
	}
	var handleSize(get, null):Int;
	inline function get_handleSize():Int {
		return Std.int(8 * ui.SCALE());
	}
	static var coffX = 70.0;
	static var coffY = 50.0;

	var dropPath = "";
	var currentOperation = "";
	var isManipulating = false;
	var transformInitInput:Vector2;
	var transformInitPos:Vector2;
	var transformInitRot:Float;
	var transformInitSize:Vector2;
	// Was the transformation editing started by dragging the mouse
	var transformStartedMouse = false;
	var drag = false;
	var dragLeft = false;
	var dragTop = false;
	var dragRight = false;
	var dragBottom = false;
	var grab = false;
	var grabX = false;
	var grabY = false;
	var rotate = false;
	var assetNames:Array<String> = [""];
	var dragAsset:TAsset = null;
	var resizeCanvas = false;
	var zoom = 1.0;

	var showFiles = false;
	var foldersOnly = false;
	var filesDone:String->Void = null;
	var uimodal:Zui;

	var gridSnapBounds:Bool = false;
	var gridSnapPos:Bool = true;
	var gridUseRelative:Bool = true;
	var useRotationSteps:Bool = false;
	var gridSize:Int = 20;
	var rotationSteps:Float = toRadians(15);
	static var grid:kha.Image = null;
	static var timeline:kha.Image = null;

	var selectedFrame = 0;
	var selectedTheme:zui.Themes.TTheme = null;
	var selectedElem:TElement = null;
	var hwin = Id.handle();
	var lastW = 0;
	var lastH = 0;
	var lastCanvasW = 0;
	var lastCanvasH = 0;

	public function new(canvas:TCanvas) {
		this.canvas = canvas;

		// Reimport assets
		if (canvas.assets.length > 0) {
			var assets = canvas.assets;
			canvas.assets = [];
			for (a in assets) importAsset(a.file);
		}

		// Import themes
		importThemes();

		kha.Assets.loadEverything(loaded);
	}

	static function toRelative(path:String, cwd:String):String {
		path = haxe.io.Path.normalize(path);
		cwd = haxe.io.Path.normalize(cwd);

		var ar:Array<String> = [];
		var ar1 = path.split("/");
		var ar2 = cwd.split("/");

		var index = 0;
		while (ar1[index] == ar2[index]) index++;

		for (i in 0...ar2.length - index) ar.push("..");

		for (i in index...ar1.length) ar.push(ar1[i]);

		return ar.join("/");
	}

	static function toAbsolute(path:String, cwd:String):String {
		return haxe.io.Path.normalize(cwd + "/" + path);
	}

	static inline function toDegrees(radians:Float):Float { return radians * 57.29578; }
	static inline function toRadians(degrees:Float):Float { return degrees * 0.0174532924; }

	function loaded() {
		var t = Reflect.copy(Themes.dark);
		t.FILL_WINDOW_BG = true;
		ui = new Zui({scaleFactor: Main.prefs.scaleFactor, font: kha.Assets.fonts.font_default, theme: t, color_wheel: kha.Assets.images.color_wheel});
		cui = new Zui({scaleFactor: 1.0, font: kha.Assets.fonts.font_default, autoNotifyInput: true, theme: Canvas.getTheme(canvas.theme)});
		uimodal = new Zui( { font: kha.Assets.fonts.font_default, scaleFactor: Main.prefs.scaleFactor } );

		if (Canvas.getTheme(canvas.theme) == null) {
			Popup.showMessage(new Zui(ui.ops), "Error!",
				'Theme "${canvas.theme}" was not found!'
				+ '\nUsing first theme in list instead: "${Canvas.themes[0].NAME}"');
			canvas.theme = Canvas.themes[0].NAME;
		}

		kha.System.notifyOnDropFiles(function(path:String) {
			dropPath = StringTools.rtrim(path);
			dropPath = toRelative(dropPath, Main.cwd);
		});

		kha.System.notifyOnFrames(onFrames);
		kha.Scheduler.addTimeTask(update, 0, 1 / 60);
	}

	function importAsset(path:String) {
		var isImage = StringTools.endsWith(path, ".jpg") ||
					  StringTools.endsWith(path, ".png") ||
					  StringTools.endsWith(path, ".k") ||
					  StringTools.endsWith(path, ".hdr");

		var isFont = StringTools.endsWith(path, ".ttf");

		var abspath = toAbsolute(path, Main.cwd);
		abspath = kha.System.systemId == "Windows" ? StringTools.replace(abspath, "/", "\\") : abspath;

		if (isImage) {
			kha.Assets.loadImageFromPath(abspath, false, function(image:kha.Image) {
				var ar = path.split("/");
				var name = ar[ar.length - 1];
				var asset:TAsset = { name: name, file: path, id: Canvas.getAssetId(canvas) };
				canvas.assets.push(asset);
				Canvas.assetMap.set(asset.id, image);

				assetNames.push(name);
				hwin.redraws = 2;
			});
		}
		else if (isFont) {
			kha.Assets.loadFontFromPath(abspath, function(font:kha.Font) {
				var ar = path.split("/");
				var name = ar[ar.length - 1];
				var asset:TAsset = { name: name, file: path, id: Canvas.getAssetId(canvas) };
				canvas.assets.push(asset);
				Canvas.assetMap.set(asset.id, font);

				assetNames.push(name);
				hwin.redraws = 2;
			});
		}
	}

	function importThemes() {
		var themesDir = haxe.io.Path.directory(Main.prefs.path);
		var themesPath = haxe.io.Path.join([themesDir, "_themes.json"]);

		kha.Assets.loadBlobFromPath(themesPath, function(b:kha.Blob) {
			Canvas.themes = haxe.Json.parse(b.toString());

			if (Canvas.themes.length == 0) {
				Canvas.themes.push(Reflect.copy(zui.Themes.light));
			}
			selectedTheme = Canvas.themes[0];

		}, function(a:kha.AssetError) {
			Canvas.themes.push(Reflect.copy(zui.Themes.light));
			selectedTheme = Canvas.themes[0];
		});
	}

	/**
	 * Generates a unique string for a given array based on the string s.
	 *
	 * @param s The string that is returned in a unique form
	 * @param data The array where the string should be unique
	 * @param elemAttr The name of the attribute of the data elements to be compared with the string.
	 * @param counter=-1 Internal use only, do not overwrite!
	 * @return String A unique string in the given array
	 */
	function unique(s:String, data:Array<Dynamic>, elemAttr:String, counter=-1): String {
		var originalName = s;

		// Reconstruct the original name
		var split = s.lastIndexOf(".");
		if (split != -1) {
			// .001, .002...
			var suffix = s.substring(split);
			if (suffix.length == 4) {
				originalName = s.substring(0, split);
			}
		}

		for (elem in data) {
			if (Reflect.getProperty(elem, elemAttr) == s) {
				if (counter > -1) {
					counter++;
					var counterLen = Std.string(counter).length;
					if (counterLen > 3) counterLen = 3;
					var padding = ".";
					for (i in 0...3 - counterLen) {
						padding += "0";
					}

					return unique(originalName + padding + Std.string(counter), data, elemAttr, counter);

				} else {
					return unique(originalName, data, elemAttr, 0);
				}
			}
		}
		return s;
	}

	function makeElem(type:ElementType) {
		var name = "";
		var height = cui.t.ELEMENT_H;
		var alignment = Align.Left;

		switch (type) {
		case ElementType.Text:
			name = unique("Text", canvas.elements, "name");
		case ElementType.Button:
			name = unique("Button", canvas.elements, "name");
			alignment = Align.Center;
		case ElementType.Image:
			name = unique("Image", canvas.elements, "name");
			height = 100;
		case ElementType.FRectangle:
			name = unique("Filled_Rectangle", canvas.elements, "name");
			height = 100;
		case ElementType.FCircle:
			name = unique("Filled_Circle", canvas.elements, "name");
		case ElementType.Rectangle:
			name = unique("Rectangle", canvas.elements, "name");
			height = 100;
		case ElementType.FTriangle:
			name = unique("Filled_Triangle", canvas.elements, "name");
		case ElementType.Triangle:
			name = unique("Triangle", canvas.elements, "name");
		case ElementType.Circle:
			name = unique("Circle", canvas.elements, "name");
		case ElementType.Check:
			name = unique("Check", canvas.elements, "name");
		case ElementType.Radio:
			name = unique("Radio", canvas.elements, "name");
		case ElementType.Combo:
			name = unique("Combo", canvas.elements, "name");
		case ElementType.Slider:
			name = unique("Slider", canvas.elements, "name");
			alignment = Align.Right;
		case ElementType.TextInput:
			name = unique("TextInput", canvas.elements, "name");
		case ElementType.KeyInput:
			name = unique("KeyInput", canvas.elements, "name");
		case ElementType.ProgressBar:
			name = unique("Progress_bar", canvas.elements, "name");
		case ElementType.CProgressBar:
			name = unique("CProgress_bar", canvas.elements, "name");
		case ElementType.Empty:
			name = unique("Empty", canvas.elements, "name");
			height = 100;
		}
		var elem:TElement = {
			id: Canvas.getElementId(canvas),
			type: type,
			name: name,
			event: "",
			x: 0,
			y: 0,
			width: 150,
			height: height,
			rotation: 0,
			text: "My " + name,
			asset: "",
			progress_at: 0,
			progress_total: 100,
			strength: 1,
			alignment: cast(alignment, Int),
			anchor: 0,
			parent: null,
			children: [],
			visible: true
		};
		canvas.elements.push(elem);
		return elem;
	}

	function unparent(elem:TElement) {
		var parent = elemById(elem.parent);
		if (parent != null) {
			elem.x += absx(parent);
			elem.y += absy(parent);
			elem.parent = null;
			parent.children.remove(elem.id);
		}
	}

	function setParent(elem:TElement, parent:TElement) {
		var oldParent = elemById(elem.parent);
		if (oldParent == parent) return;
		unparent(elem); //Unparent first if we already have a parent

		if (parent != null) { //Parent
			if (parent.children == null) elem.children = [];
			parent.children.push(elem.id);
			elem.parent = parent.id;
			elem.x -= absx(parent);
			elem.y -= absy(parent);
		}
	}

	function duplicateElem(elem:TElement, parentId:Null<Int> = null):TElement {
		if (elem != null) {
			if (parentId == null) parentId = elem.parent;
			var dupe:TElement = {
				id: Canvas.getElementId(canvas),
				type: elem.type,
				name: elem.name,
				event: elem.event,
				x: elem.x + 10,
				y: elem.y + 10,
				width: elem.width,
				height: elem.height,
				rotation: elem.rotation,
				text: elem.text,
				asset: elem.asset,
				color: elem.color,
				color_text: elem.color_text,
				color_hover: elem.color_hover,
				color_press: elem.color_press,
				color_progress: elem.color_progress,
				progress_at: elem.progress_at,
				progress_total: elem.progress_total,
				strength: elem.strength,
				anchor: elem.anchor,
				parent: parentId,
				children: [],
				visible: elem.visible
			};
			canvas.elements.push(dupe);
			if (parentId != null) {
				var parentElem = elemById(parentId);
				parentElem.children.push(dupe.id);
				if (elem.parent != parentId) {
					dupe.x = elem.x;
					dupe.y = elem.y;
				}
			}
			for(child in elem.children) {
				duplicateElem(elemById(child), dupe.id);
			}

			return dupe;
		}
		return null;
	}

	function getEnumTexts():Array<String> {
		return assetNames.length > 0 ? assetNames : [""];
	}

	function getAssetIndex(asset:String):Int {
		for (i in 0...canvas.assets.length) if (asset == canvas.assets[i].name) return i + 1; // assetNames[0] = ""
		return 0;
	}

	function resize() {
		if (grid != null) {
			grid.unload();
			grid = null;
		}
		if (timeline != null) {
			timeline.unload();
			timeline = null;
		}
	}

	function drawGrid() {
		var doubleGridSize = gridSize * 2;
		var ww = kha.System.windowWidth();
		var wh = kha.System.windowHeight();
		var w = ww + doubleGridSize * 2;
		var h = wh + doubleGridSize * 2;
		grid = kha.Image.createRenderTarget(w, h);
		grid.g2.begin(true, 0xff242424);
		for (i in 0...Std.int(h / doubleGridSize) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(0, i * doubleGridSize, w, i * doubleGridSize);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(0, i * doubleGridSize + gridSize, w, i * doubleGridSize + gridSize);
		}
		for (i in 0...Std.int(w / doubleGridSize) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(i * doubleGridSize, 0, i * doubleGridSize, h);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(i * doubleGridSize + gridSize, 0, i * doubleGridSize + gridSize, h);
		}

		grid.g2.end();
	}

	function drawTimeline(timelineLabelsHeight:Int, timelineFramesHeight:Int) {
		var sc = ui.SCALE();

		var timelineHeight = timelineLabelsHeight + timelineFramesHeight;

		timeline = kha.Image.createRenderTarget(kha.System.windowWidth() - uiw - toolbarw, timelineHeight);

		var g = timeline.g2;
		g.begin(true, 0xff222222);
		g.font = kha.Assets.fonts.font_default;
		g.fontSize = Std.int(16 * sc);

		// Labels
		var frames = Std.int(timeline.width / (11 * sc));
		for (i in 0...Std.int(frames / 5) + 1) {
			var frame = i * 5;

			var frameTextWidth = kha.Assets.fonts.font_default.width(g.fontSize, frame + "");
			g.drawString(frame + "", i * 55 * sc + 5 * sc - frameTextWidth / 2, timelineLabelsHeight / 2 - g.fontSize / 2);
		}

		// Frames
		for (i in 0...frames) {
			g.color = i % 5 == 0 ? 0xff444444 : 0xff333333;
			g.fillRect(i * 11 * sc, timelineHeight - timelineFramesHeight, 10 * sc, timelineFramesHeight);
		}

		g.end();
	}

	public function onFrames(framebuffers: Array<kha.Framebuffer>): Void {
		var framebuffer = framebuffers[0];

		// Disable UI if a popup is displayed
		if (Popup.show && ui.inputRegistered) {
			ui.unregisterInput();
			cui.unregisterInput();
		} else if (!Popup.show && !ui.inputRegistered) {
			ui.registerInput();
			cui.registerInput();
		}

		// Update preview when choosing a color
		if (Popup.show) hwin.redraws = 1;

		if (dropPath != "") {
			importAsset(dropPath);
			dropPath = "";
		}

		var sc = ui.SCALE();
		var timelineLabelsHeight = Std.int(30 * sc);
		var timelineFramesHeight = Std.int(40 * sc);

		// Bake and redraw if the UI scale has changed
		if (grid == null) drawGrid();
		if (timeline == null || timeline.height != timelineLabelsHeight + timelineFramesHeight) drawTimeline(timelineLabelsHeight, timelineFramesHeight);

		var g = framebuffer.g2;
		g.begin();

		g.color = 0xffffffff;
		g.drawImage(grid, coffX % 40 - 40, coffY % 40 - 40);

		// Canvas outline
		canvas.x = coffX;
		canvas.y = coffY;
		g.drawRect(canvas.x, canvas.y, scaled(canvas.width), scaled(canvas.height), 1.0);
		// Canvas resize
		g.drawRect(canvas.x + scaled(canvas.width) - 3, canvas.y + scaled(canvas.height) - 3, 6, 6, 1);

		Canvas.screenW = canvas.width;
		Canvas.screenH = canvas.height;
		Canvas.draw(cui, canvas, g);

		// Outline selected elem
		if (selectedElem != null) {
			g.color = 0xffffffff;
			// Resize rects
			var ex = scaled(absx(selectedElem));
			var ey = scaled(absy(selectedElem));
			var ew = scaled(selectedElem.width);
			var eh = scaled(selectedElem.height);
			// Element center
			var cx = canvas.x + ex + ew / 2;
			var cy = canvas.y + ey + eh / 2;
			g.pushRotation(selectedElem.rotation, cx, cy);

			g.drawRect(canvas.x + ex, canvas.y + ey, ew, eh);
			g.color = 0xff000000;
			g.drawRect(canvas.x + ex + 1, canvas.y + ey + 1, ew, eh);
			g.color = 0xffffffff;

			// Rotate mouse coords in opposite direction as the element
			var rotatedInput:Vector2 = rotatePoint(ui.inputX, ui.inputY, cx, cy, -selectedElem.rotation);

			// Draw corner drag handles
			for (handlePosX in 0...3) {
				// 0 = Left, 0.5 = Center, 1 = Right
				var handlePosX:Float = handlePosX / 2;

				for (handlePosY in 0...3) {
					// 0 = Top, 0.5 = Center, 1 = Bottom
					var handlePosY:Float = handlePosY / 2;

					if (handlePosX == 0.5 && handlePosY == 0.5) {
						continue;
					}

					var hX = canvas.x + ex + ew * handlePosX - handleSize / 2;
					var hY = canvas.y + ey + eh * handlePosY - handleSize / 2;

					// Check if the handle is currently dragged (not necessarily hovered!)
					var dragged = false;

					if (handlePosX == 0 && dragLeft) {
						if (handlePosY == 0 && dragTop) dragged = true;
						else if (handlePosY == 0.5 && !(dragTop || dragBottom)) dragged = true;
						else if (handlePosY == 1 && dragBottom) dragged = true;
					} else if (handlePosX == 0.5 && !(dragLeft || dragRight)) {
						if (handlePosY == 0 && dragTop) dragged = true;
						else if (handlePosY == 1 && dragBottom) dragged = true;
					} else if (handlePosX == 1 && dragRight) {
						if (handlePosY == 0 && dragTop) dragged = true;
						else if (handlePosY == 0.5 && !(dragTop || dragBottom)) dragged = true;
						else if (handlePosY == 1 && dragBottom) dragged = true;
					}
					dragged = dragged && drag;


					// Hover
					if (rotatedInput.x > hX && rotatedInput.x < hX + handleSize || dragged) {
						if (rotatedInput.y > hY && rotatedInput.y < hY + handleSize || dragged) {
							g.color = 0xff205d9c;
							g.fillRect(hX, hY, handleSize, handleSize);
							g.color = 0xffffffff;
						}
					}

					g.drawRect(hX, hY, handleSize, handleSize);
				}
			}

			// Draw rotation handle
			g.drawLine(cx, canvas.y + ey, cx, canvas.y + ey - handleSize * 2);

			var rotHandleCenter = new Vector2(cx, canvas.y + ey - handleSize * 2);
			if (rotatedInput.sub(rotHandleCenter).length <= handleSize / 2 || rotate) {
				g.color = 0xff205d9c;
				g.fillCircle(rotHandleCenter.x, rotHandleCenter.y, handleSize / 2);
				g.color = 0xffffffff;
			}
			g.drawCircle(rotHandleCenter.x, rotHandleCenter.y, handleSize / 2);

			g.popTransformation();
		}

		if (currentOperation != "") {
			g.fontSize = Std.int(14 * ui.SCALE());
			g.color = 0xffaaaaaa;
			g.drawString(currentOperation, toolbarw, kha.System.windowHeight() - timeline.height - g.fontSize);
		}

		// Timeline
		var showTimeline = true;
		if (showTimeline) {
			g.color = 0xffffffff;
			var ty = kha.System.windowHeight() - timeline.height;
			g.drawImage(timeline, toolbarw, ty);

			g.color = 0xff205d9c;
			g.fillRect(toolbarw + selectedFrame * 11 * sc, ty + timelineLabelsHeight, 10 * sc, timelineFramesHeight);

			// Show selected frame number
			g.font = kha.Assets.fonts.font_default;
			g.fontSize = Std.int(16 * sc);

			var frameIndicatorMargin = 4 * sc;
			var frameIndicatorPadding = 4 * sc;
			var frameIndicatorWidth = 30 * sc;
			var frameIndicatorHeight = timelineLabelsHeight - frameIndicatorMargin * 2;
			var frameTextWidth = kha.Assets.fonts.font_default.width(g.fontSize, "" + selectedFrame);

			// Scale the indicator if the contained text is too long
			if (frameTextWidth > frameIndicatorWidth + frameIndicatorPadding) {
				frameIndicatorWidth = frameTextWidth + frameIndicatorPadding;
			}

			g.fillRect(toolbarw + selectedFrame * 11 * sc + 5 * sc - frameIndicatorWidth / 2, ty + frameIndicatorMargin, frameIndicatorWidth, frameIndicatorHeight);
			g.color = 0xffffffff;
			g.drawString("" + selectedFrame, toolbarw + selectedFrame * 11 * sc + 5 * sc - frameTextWidth / 2, ty + timelineLabelsHeight / 2 - g.fontSize / 2);
		}

		g.end();

		ui.begin(g);

		if (ui.window(Id.handle(), 0, 0, toolbarw, kha.System.windowHeight())) {
			ui.text("Add Elements:");

			if (ui.panel(Id.handle({selected: true}), "Basic")) {
				ui.indent();

				if (ui.button("Empty")) {
					selectedElem = makeElem(ElementType.Empty);
				}
				if (ui.isHovered) ui.tooltip("Creates empty element");
				if (ui.button("Text")) {
					selectedElem = makeElem(ElementType.Text);
				}
				if (ui.isHovered) ui.tooltip("Create text element");
				if (ui.button("Image")) {
					selectedElem = makeElem(ElementType.Image);
				}
				if (ui.isHovered) ui.tooltip("Creates image element");

				ui.unindent();
			}

			// ui.button("VLayout");
			// ui.button("HLayout");
			if (ui.panel(Id.handle({selected: true}), "Buttons")){
				ui.indent();

				if (ui.button("Button")) {
				selectedElem = makeElem(ElementType.Button);
				}
				if (ui.isHovered) ui.tooltip("Creates button element");
				if (ui.button("Check")) {
					selectedElem = makeElem(ElementType.Check);
				}
				if (ui.isHovered) ui.tooltip("Creates check box element");
				if (ui.button("Radio")) {
					selectedElem = makeElem(ElementType.Radio);
				}
				if (ui.isHovered) ui.tooltip("Creates inline-radio element");

				ui.unindent();
			}

			if (ui.panel(Id.handle({selected: true}), "Inputs")){
				ui.indent();

				if (ui.button("Text Input")) {
					selectedElem = makeElem(ElementType.TextInput);
				}
				if (ui.isHovered) ui.tooltip("Creates text input element");
				if (ui.button("Key Input")) {
					selectedElem = makeElem(ElementType.KeyInput);
				}
				if (ui.isHovered) ui.tooltip("Creates key input element");
				if (ui.button("Combo Box")) {
					selectedElem = makeElem(ElementType.Combo);
				}
				if (ui.isHovered) ui.tooltip("Creates combo box element");
				if (ui.button("Slider")) {
					selectedElem = makeElem(ElementType.Slider);
				}
				if (ui.isHovered) ui.tooltip("Creates slider element");

				ui.unindent();
			}

			if (ui.panel(Id.handle({selected: true}), "Shapes")){
				ui.indent();
				if (ui.button("Rect")) {
					selectedElem = makeElem(ElementType.Rectangle);
				}
				if (ui.isHovered) ui.tooltip("Creates rectangle shaped element");
				if (ui.button("Fill Rect")) {
					selectedElem = makeElem(ElementType.FRectangle);
				}
				if (ui.isHovered) ui.tooltip("Creates filled rectangle shaped element");
				if (ui.button("Circle")){
					selectedElem = makeElem(ElementType.Circle);
				}
				if (ui.isHovered) ui.tooltip("Creates circle shaped element");
				if (ui.button("Fill Circle")){
					selectedElem = makeElem(ElementType.FCircle);
				}
				if (ui.isHovered) ui.tooltip("Creates filled circle shaped element");
				if (ui.button("Triangle")){
					selectedElem = makeElem(ElementType.Triangle);
				}
				if (ui.isHovered) ui.tooltip("Creates triangle shaped element");
				if (ui.button("Fill Triangle")){
					selectedElem = makeElem(ElementType.FTriangle);
				}
				if (ui.isHovered) ui.tooltip("Creates filled triangle shaped element");

				ui.unindent();
			}

			if (ui.panel(Id.handle({selected: true}), "ProgressBars")){
				ui.indent();
				if (ui.button("RectPB")) {
					selectedElem = makeElem(ElementType.ProgressBar);
				}
				if (ui.isHovered) ui.tooltip("Creates rectangular progress bar");
				if (ui.button("CircularPB")) {
					selectedElem = makeElem(ElementType.CProgressBar);
				}
				if (ui.isHovered) ui.tooltip("Creates circular progress bar");
				ui.unindent();
			}
		}

		if (ui.window(Id.handle(), toolbarw, 0, kha.System.windowWidth() - uiw - toolbarw, Std.int((ui.t.ELEMENT_H + 2) * ui.SCALE()))) {
			ui.tab(Id.handle(), canvas.name);
		}

		if (ui.window(hwin, kha.System.windowWidth() - uiw, 0, uiw, kha.System.windowHeight())) {

			var htab = Id.handle();
			if (ui.tab(htab, "Project")) {

				if (ui.button("Save")) {
					// Unpan
					canvas.x = 0;
					canvas.y = 0;

					// Save canvas to file
					#if kha_krom
					Krom.fileSaveBytes(Main.prefs.path, haxe.io.Bytes.ofString(haxe.Json.stringify(canvas)).getData());
					#elseif kha_debug_html5
					var fs = untyped __js__('require("fs");');
					var path = untyped __js__('require("path")');
					var filePath = path.resolve(untyped __js__('__dirname'), Main.prefs.path);
					try { fs.writeFileSync(filePath, haxe.Json.stringify(canvas)); }
					catch (x: Dynamic) { trace('saving "${filePath}" failed'); }
					#end

					// Save assets to files
					var filesPath = Main.prefs.path.substr(0, Main.prefs.path.length - 5); // .json
					filesPath += '.files';
					var filesList = '';
					for (a in canvas.assets) filesList += a.file + '\n';
					#if kha_krom
					Krom.fileSaveBytes(filesPath, haxe.io.Bytes.ofString(filesList).getData());
					#elseif kha_debug_html5
					var fs = untyped __js__('require("fs")');
					var path = untyped __js__('require("path")');
					var filePath = path.resolve(untyped __js__('__dirname'), filesPath);
					try { fs.writeFileSync(filePath, filesList); }
					catch (x: Dynamic) { trace('saving "${filePath}" failed'); }
					#end

					// Save themes to file
					var themesPath = haxe.io.Path.join([haxe.io.Path.directory(Main.prefs.path), "_themes.json"]);
					#if kha_krom
					Krom.fileSaveBytes(themesPath, haxe.io.Bytes.ofString(haxe.Json.stringify(Canvas.themes)).getData());
					#elseif kha_debug_html5
					var fs = untyped __js__('require("fs");');
					var path = untyped __js__('require("path")');
					var filePath = path.resolve(untyped __js__('__dirname'), themesPath);
					try { fs.writeFileSync(filePath, haxe.Json.stringify(Canvas.themes)); }
					catch (x: Dynamic) { trace('saving "${filePath}" failed'); }
					#end

					canvas.x = coffX;
					canvas.y = coffY;
				}

				if (ui.panel(Id.handle({selected: false}), "Canvas")) {
					ui.indent();

					if (ui.button("New")) {
						canvas.elements = [];
						selectedElem = null;
					}
					if (ui.isHovered) ui.tooltip("Create new canvas");

					var handleName = Id.handle({text: canvas.name});
					ui.textInput(handleName, "Name", Right);
					if (handleName.changed) {
						// Themes file is called _themes.json, so canvases should not be named like that
						if (handleName.text == "_themes") {
							Popup.showMessage(new Zui(ui.ops), "Sorry!", "\"_themes\" is not a valid canvas name as it is reserved!");
							handleName.text = canvas.name;
						} else {
							canvas.name = handleName.text;
						}
					}

					ui.row([1/2, 1/2]);


					var handlecw = Id.handle({text: canvas.width + ""});
					var handlech = Id.handle({text: canvas.height + ""});
					handlecw.text = canvas.width + "";
					handlech.text = canvas.height + "";
					var strw = ui.textInput(handlecw, "Width", Right);
					var strh = ui.textInput(handlech, "Height", Right);
					canvas.width = Std.parseInt(strw);
					canvas.height = Std.parseInt(strh);

					ui.unindent();
				}

				if (ui.panel(Id.handle({selected: true}), "Outliner")) {
					ui.indent();

					function drawList(h:zui.Zui.Handle, elem:TElement) {
						var b = false;
						// Highlight
						if (selectedElem == elem) {
							ui.g.color = 0xff205d9c;
							ui.g.fillRect(0, ui._y, ui._windowW, ui.t.ELEMENT_H * ui.SCALE());
							ui.g.color = 0xffffffff;
						}
						var started = ui.getStarted();
						// Select
						if (started && !ui.inputDownR) {
							selectedElem = elem;
						}
						// Parenting
						if (started && ui.inputDownR) {
							if (elem == selectedElem) {
								unparent(elem);
							}
							else {
								setParent(selectedElem, elem);
							}
						}
						// Draw
						if (elem.children != null && elem.children.length > 0) {
							ui.row([1/13, 12/13]);
							b = ui.panel(h.nest(elem.id, {selected: true}), "", true);
							ui.text(elem.name);
						}
						else {
							ui._x += 18; // Sign offset
							ui.text(elem.name);
							ui._x -= 18;
						}
						// Draw children
						if (b) {
							var i = elem.children.length;
							while(i > 0) {
								i--; //Iterate backwards to avoid reparenting issues.
								var id = elem.children[elem.children.length - 1 - i];
								ui.indent();
								drawList(h, elemById(id));
								ui.unindent();
							}
						}
					}
					for (i in 0...canvas.elements.length) {
						var elem = canvas.elements[canvas.elements.length - 1 - i];
						if (elem.parent == null) drawList(Id.handle(), elem);
					}

					ui.row([1/4, 1/4, 1/4, 1/4]);
					var elems = canvas.elements;
					if (ui.button("Up") && selectedElem != null) {
						moveElem(1);
					}
					if (ui.isHovered) ui.tooltip("Move element up");

					if (ui.button("Down") && selectedElem != null) {
						moveElem(-1);
					}
					if (ui.isHovered) ui.tooltip("Move element down");

					if (ui.button("Remove") && selectedElem != null) {
						removeSelectedElem();
					}
					if (ui.isHovered) ui.tooltip("Delete element");

					if (ui.button("Duplicate") && selectedElem != null) {
						selectedElem = duplicateElem(selectedElem);
					}
					if (ui.isHovered) ui.tooltip("Create duplicate of element");

					ui.unindent();
				}

				if (selectedElem != null) {
					var elem = selectedElem;
					var id = elem.id;

					if (ui.panel(Id.handle({selected: true}), "Properties")) {
						ui.indent();
						elem.visible = ui.check(Id.handle().nest(id, {selected: elem.visible == null ? true : elem.visible}), "Visible");
						elem.name = ui.textInput(Id.handle().nest(id, {text: elem.name}), "Name", Right);
						elem.text = ui.textInput(Id.handle().nest(id, {text: elem.text}), "Text", Right);
						ui.row([1/4, 1/4, 1/4, 1/4]);
						var handlex = Id.handle().nest(id, {text: elem.x + ""});
						var handley = Id.handle().nest(id, {text: elem.y + ""});
						// if (drag) {
							handlex.text = elem.x + "";
							handley.text = elem.y + "";
						// }
						var strx = ui.textInput(handlex, "X", Right);
						var stry = ui.textInput(handley, "Y", Right);
						elem.x = Std.parseFloat(strx);
						elem.y = Std.parseFloat(stry);
						// ui.row([1/2, 1/2]);
						var handlew = Id.handle().nest(id, {text: elem.width + ""});
						var handleh = Id.handle().nest(id, {text: elem.height + ""});
						// if (drag) {
							handlew.text = elem.width + "";
							handleh.text = elem.height + "";
						// }
						var strw = ui.textInput(handlew, "W", Right);
						var strh = ui.textInput(handleh, "H", Right);
						elem.width = Std.int(Std.parseFloat(strw));
						elem.height = Std.int(Std.parseFloat(strh));
						if (elem.type == ElementType.Rectangle || elem.type == ElementType.Circle || elem.type == ElementType.Triangle || elem.type == ElementType.ProgressBar || elem.type == ElementType.CProgressBar){
							var handles = Id.handle().nest(id, {text: elem.strength+""});
							var strs = ui.textInput(handles, "Line Strength", Right);
							elem.strength = Std.int(Std.parseFloat(strs));
						}
						if (elem.type == ElementType.ProgressBar || elem.type == ElementType.CProgressBar){
							var handlep = Id.handle().nest(id, {text: elem.progress_at+""});
							var strp = ui.textInput(handlep, "Progress", Right);
							var handlespt = Id.handle().nest(id, {text: elem.progress_total+""});
							var strpt = ui.textInput(handlespt, "Total Progress", Right);
							elem.progress_total = Std.int(Std.parseFloat(strpt));
							elem.progress_at = Std.int(Std.parseFloat(strp));
						}
						var handlerot = Id.handle().nest(id, {value: roundPrecision(toDegrees(elem.rotation == null ? 0 : elem.rotation), 2)});
						handlerot.value = roundPrecision(toDegrees(elem.rotation), 2);
						// Small fix for radian/degree precision errors
						if (handlerot.value >= 360) handlerot.value = 0;
						elem.rotation = toRadians(ui.slider(handlerot, "Rotation", 0.0, 360.0, true));
						var assetPos = ui.combo(Id.handle().nest(id, {position: getAssetIndex(elem.asset)}), getEnumTexts(), "Asset", true, Right);
						elem.asset = getEnumTexts()[assetPos];
						ui.unindent();
					}
					if (ui.panel(Id.handle({selected: false}), "Color")){
						function drawColorSelection(idMult: Int, color:Null<Int>, defaultColor:Int) {
							ui.row([1/2, 1/2]);

							var handleCol = Id.handle().nest(id).nest(idMult, {color: Canvas.getColor(color, defaultColor)});
							ui.colorField(handleCol, true);

							if (handleCol.changed) {
								color = handleCol.color;
							}

							// Follow theme color
							if (ui.button("Reset") || color == null) {
								color = null;
								handleCol.color = defaultColor;
								handleCol.changed = false;
							}

							return color;
						}

						ui.indent();
						if (elem.type == ElementType.Text) {
							ui.text("Text:");
							elem.color_text = drawColorSelection(1, elem.color_text, Canvas.getTheme(canvas.theme).TEXT_COL);

						} else if (elem.type == ElementType.Button) {
							ui.text("Text:");
							elem.color_text = drawColorSelection(1, elem.color_text, Canvas.getTheme(canvas.theme).BUTTON_TEXT_COL);
							ui.text("Background:");
							elem.color = drawColorSelection(2, elem.color, Canvas.getTheme(canvas.theme).BUTTON_COL);
							ui.text("On Hover:");
							elem.color_hover = drawColorSelection(3, elem.color_hover, Canvas.getTheme(canvas.theme).BUTTON_HOVER_COL);
							ui.text("On Pressed:");
							elem.color_press = drawColorSelection(4, elem.color_press, Canvas.getTheme(canvas.theme).BUTTON_PRESSED_COL);

						} else if (elem.type == ElementType.FRectangle || elem.type == ElementType.FCircle ||
								  elem.type == ElementType.Rectangle || elem.type == ElementType.Circle ||
								  elem.type == ElementType.Triangle || elem.type == ElementType.FTriangle) {
							ui.text("Color:");
							elem.color = drawColorSelection(1, elem.color, Canvas.getTheme(canvas.theme).BUTTON_COL);

						} else if (elem.type == ElementType.ProgressBar || elem.type == ElementType.CProgressBar) {
							ui.text("Progress:");
							elem.color_progress = drawColorSelection(1, elem.color_progress, Canvas.getTheme(canvas.theme).TEXT_COL);
							ui.text("Background:");
							elem.color = drawColorSelection(2, elem.color, Canvas.getTheme(canvas.theme).BUTTON_COL);

						} else if (elem.type == ElementType.Empty) {
							ui.text("No color for element type empty");

						} else {
							ui.text("Text:");
							elem.color_text = drawColorSelection(1, elem.color, Canvas.getTheme(canvas.theme).TEXT_COL);
							ui.text("Background:");
							elem.color = drawColorSelection(2, elem.color, Canvas.getTheme(canvas.theme).BUTTON_COL);
							ui.text("On Hover:");
							elem.color_hover = drawColorSelection(3, elem.color, Canvas.getTheme(canvas.theme).BUTTON_HOVER_COL);
						}
						ui.unindent();
					}

					if (ui.panel(Id.handle({selected: false}), "Align")) {
						ui.indent();

						var alignmentHandle = Id.handle().nest(id, {position: elem.alignment});
						ui.row([1/3, 1/3, 1/3]);
						ui.radio(alignmentHandle, 0, "Left");
						ui.radio(alignmentHandle, 1, "Center");
						ui.radio(alignmentHandle, 2, "Right");
						selectedElem.alignment = alignmentHandle.position;

						ui.unindent();
					}

					if (ui.panel(Id.handle({selected: false}), "Anchor")) {
						ui.indent();
						var hanch = Id.handle().nest(id, {position: elem.anchor});
						ui.row([4/11,3/11,4/11]);
						ui.radio(hanch, 0, "Top-Left");
						ui.radio(hanch, 1, "Top");
						ui.radio(hanch, 2, "Top-Right");
						ui.row([4/11,3/11,4/11]);
						ui.radio(hanch, 3, "Left");
						ui.radio(hanch, 4, "Center");
						ui.radio(hanch, 5, "Right");
						ui.row([4/11,3/11,4/11]);
						ui.radio(hanch, 6, "Bot-Left");
						ui.radio(hanch, 7, "Bottom");
						ui.radio(hanch, 8, "Bot-Right");
						elem.anchor = hanch.position;
						ui.unindent();
					}

					if (ui.panel(Id.handle({selected: false}), "Script")) {
						ui.indent();
						elem.event = ui.textInput(Id.handle().nest(id, {text: elem.event}), "Event", Right);
						ui.unindent();
					}

					if (ui.panel(Id.handle({selected: false}), "Timeline")) {
						// ui.indent();
						// ui.row([1/2,1/2]);
						// ui.button("Insert");
						// ui.button("Remove");
						// ui.unindent();
					}
				}
			}

			if (ui.tab(htab, "Themes")) {
				// Must be accesible all over this place because when deleting themes,
				// the color handle's child handle at that theme index must be reset.
				var handleThemeColor = Id.handle();
				var handleThemeName = Id.handle();
				var iconSize = 16;

				function drawList(h:zui.Zui.Handle, theme:zui.Themes.TTheme) {
					// Highlight
					if (selectedTheme == theme) {
						ui.g.color = 0xff205d9c;
						ui.g.fillRect(0, ui._y, ui._windowW, ui.t.ELEMENT_H * ui.SCALE());
						ui.g.color = 0xffffffff;
					}
					// Highlight default theme
					if (theme == Canvas.getTheme(canvas.theme)) {
						var iconMargin = (ui.t.BUTTON_H - iconSize) / 2;
						ui.g.drawSubImage(kha.Assets.images.icons, ui._x + iconMargin, ui._y + iconMargin, 0, 0, 16, 16);
					}

					var started = ui.getStarted();
					// Select
					if (started && !ui.inputDownR) {
						selectedTheme = theme;
					}

					// Draw
					ui._x += iconSize; // Icon offset
					ui.text(theme.NAME);
					ui._x -= iconSize;
				}

				for (theme in Canvas.themes) {
					drawList(Id.handle(), theme);
				}

				ui.row([1/4, 1/4, 1/4, 1/4]);
				if (ui.button("Add")) {
					var newTheme = Reflect.copy(zui.Themes.light);
					newTheme.NAME = unique("New Theme", Canvas.themes, "NAME");

					Canvas.themes.push(newTheme);
					selectedTheme = newTheme;
				}

				if (selectedTheme == null) ui.enabled = false;
				if (ui.button("Copy")) {
					var newTheme = Reflect.copy(selectedTheme);
					newTheme.NAME = unique(newTheme.NAME, Canvas.themes, "NAME");

					Canvas.themes.push(newTheme);
					selectedTheme = newTheme;
				}
				ui.enabled = true;

				if (selectedTheme == null) ui.enabled = false;
				var hName = handleThemeName.nest(Canvas.themes.indexOf(selectedTheme));
				if (ui.button("Rename")) {
					hName.text = selectedTheme.NAME;
					Popup.showCustom(
						new Zui(ui.ops),
						function(ui:Zui) {
							ui.textInput(hName);
							if (ui.button("OK")) {
								Popup.show = false;
								hwin.redraws = 2;
							}
						},
						Std.int(ui.inputX), Std.int(ui.inputY), 200, 60);
				}
				if (selectedTheme != null) {
					var name = selectedTheme.NAME;
					if (hName.changed && selectedTheme.NAME != hName.text) {
						name = unique(hName.text, Canvas.themes, "NAME");
						if (canvas.theme == selectedTheme.NAME) {
							canvas.theme = name;
						}
						selectedTheme.NAME = name;
					}
				}
				ui.enabled = true;

				if (Canvas.themes.length == 1 || selectedTheme == null) ui.enabled = false;
				if (ui.button("Delete")) {
					handleThemeColor.unnest(Canvas.themes.indexOf(selectedTheme));
					handleThemeName.unnest(Canvas.themes.indexOf(selectedTheme));

					Canvas.themes.remove(selectedTheme);

					// Canvas default theme was deleted
					if (Canvas.getTheme(canvas.theme) == null) {
						canvas.theme = Canvas.themes[0].NAME;
					}
					selectedTheme = null;
				}
				ui.enabled = true;

				if (selectedTheme == null) ui.enabled = false;
				if (ui.button("Apply to Canvas")) {
					canvas.theme = selectedTheme.NAME;
				}
				ui.enabled = true;

				if (selectedTheme == null) {
					ui.text("Please select a Theme!");
				} else {
					// A Map would be way better, but its order is not guaranteed.
					var themeColorOptions:Array<Array<String>> = [
						["Text", "TEXT_COL"],
						["Elements", "BUTTON_COL", "BUTTON_TEXT_COL", "BUTTON_HOVER_COL", "BUTTON_PRESSED_COL", "ACCENT_COL", "ACCENT_HOVER_COL", "ACCENT_SELECT_COL"],
					];

					for (idxCategory in 0...themeColorOptions.length) {
						if (ui.panel(Id.handle().nest(idxCategory, {selected: true}), themeColorOptions[idxCategory][0])) {
							ui.indent();

							var attributes = themeColorOptions[idxCategory].slice(1);

							for (idxElemAttribs in 0...attributes.length) {
								var themeColorOption = attributes[idxElemAttribs];
								// is getField() better?
								ui.row([2/3, 1/3]);
								ui.text(themeColorOption);

								var themeColor = Reflect.getProperty(selectedTheme, themeColorOption);

								var handleCol = handleThemeColor.nest(Canvas.themes.indexOf(selectedTheme)).nest(idxCategory).nest(idxElemAttribs, {color: themeColor});
								var col = ui.colorField(handleCol, true);
								Reflect.setProperty(selectedTheme, themeColorOption, col);
							}

							ui.unindent();
						}
					}
				}
			}

			if (ui.tab(htab, "Assets")) {
				if (ui.button("Import Asset")) {
					showFiles = true;
					foldersOnly = false;
					filesDone = function(path:String) {
						path = StringTools.rtrim(path);
						path = toRelative(path, Main.cwd);
						importAsset(path);
					}
				}

				if (canvas.assets.length > 0) {
					ui.text("(Drag and drop assets to canvas)", zui.Zui.Align.Center);

					var i = canvas.assets.length - 1;
					while (i >= 0) {
						var asset = canvas.assets[i];
						var isFont = StringTools.endsWith(asset.name, ".ttf");
						if (!isFont && ui.image(getImage(asset)) == State.Started) {
							dragAsset = asset;
						}
						ui.row([7/8, 1/8]);
						asset.name = ui.textInput(Id.handle().nest(asset.id, {text: asset.name}), "", Right);
						assetNames[i + 1] = asset.name; // assetNames[0] == ""
						if (ui.button("X")) {
							getImage(asset).unload();
							canvas.assets.splice(i, 1);
							assetNames.splice(i + 1, 1);
						}
						i--;
					}
				}
				else {
					ui.text("(Drag and drop images and fonts here)", zui.Zui.Align.Center);
				}
			}

			if (ui.tab(htab, "Preferences")) {
				if (ui.panel(Id.handle({selected: true}), "Application")) {
					ui.indent();

					var hscale = Id.handle({value: 1.0});
					ui.slider(hscale, "UI Scale", 0.5, 4.0, true);
					if (hscale.changed && !ui.inputDown) {
						ui.setScale(hscale.value);
						windowW = Std.int(defaultWindowW * hscale.value);
					}

					Main.prefs.window_vsync = ui.check(Id.handle({selected: true}), "VSync");

					ui.unindent();
				}

				if (ui.panel(Id.handle({selected: true}), "Grid")) {
					ui.indent();
					var gsize = Id.handle({value: 20});
					ui.slider(gsize, "Grid Size", 1, 128, true, 1);
					gridSnapPos = ui.check(Id.handle({selected: true}), "Grid Snap Position");
					if (ui.isHovered) ui.tooltip("Snap the element's position to the grid");
					gridSnapBounds = ui.check(Id.handle({selected: false}), "Grid Snap Bounds");
					if (ui.isHovered) ui.tooltip("Snap the element's bounds to the grid");
					gridUseRelative = ui.check(Id.handle({selected: true}), "Use Relative Grid");
					if (ui.isHovered) ui.tooltip("Use a grid that's relative to the selected element");

					if (gsize.changed && !ui.inputDown) {
						gridSize = Std.int(gsize.value);
					}

					useRotationSteps = ui.check(Id.handle({selected: false}), "Use Fixed Rotation Steps");
					if (ui.isHovered) ui.tooltip("Rotate elements by a fixed step size");
					var rotStepHandle = Id.handle({value: 15});
					if (useRotationSteps) {
						ui.slider(rotStepHandle, "Rotation Step Size", 1, 180, true, 1);
					}

					if (rotStepHandle.changed && !ui.inputDown) {
						rotationSteps = toRadians(rotStepHandle.value);
					}

					ui.unindent();
				}

				// if (ui.button("Save")) {
				// 	#if kha_krom
				// 	Krom.fileSaveBytes("config.arm", haxe.io.Bytes.ofString(haxe.Json.stringify(armory.data.Config.raw)).getData());
				// 	#end
				// }
				// ui.text("armory2d");

				if (ui.panel(Id.handle({selected: true}), "Shortcuts")){
					ui.indent();

					ui.row([1/2, 1/2]);
					ui.text("Select");
					var selectMouseHandle = Id.handle({position: 0});
					ui.combo(selectMouseHandle, ["Left Click", "Right Click"], "");
					if (ui.isHovered) ui.tooltip("Mouse button used for element selection.");
					if (selectMouseHandle.changed) {
						Main.prefs.keyMap.selectMouseButton = ["Left", "Right"][selectMouseHandle.position];
					}

					ui.separator(8, false);
					ui.row([1/2, 1/2]);
					ui.text("Grab");
					Main.prefs.keyMap.grabKey = ui.keyInput(Id.handle({value: KeyCode.G}), "Key");
					if (ui.isHovered) ui.tooltip("Key used for grabbing elements");

					ui.row([1/2, 1/2]);
					ui.text("Rotate");
					Main.prefs.keyMap.rotateKey = ui.keyInput(Id.handle({value: KeyCode.R}), "Key");
					if (ui.isHovered) ui.tooltip("Key used for rotating elements");

					ui.row([1/2, 1/2]);
					ui.text("Size");
					Main.prefs.keyMap.sizeKey = ui.keyInput(Id.handle({value: KeyCode.S}), "Key");
					if (ui.isHovered) ui.tooltip("Key used for resizing elements");

					ui.separator(8, false);
					ui.row([1/2, 1/2]);
					ui.text("Precision Transform");
					Main.prefs.keyMap.slowMovement = ui.keyInput(Id.handle({value: KeyCode.Shift}), "Key");
					if (ui.isHovered) ui.tooltip("More precise transformations");

					ui.row([1/2, 1/2]);
					ui.text("Invert Grid");
					Main.prefs.keyMap.gridInvert = ui.keyInput(Id.handle({value: KeyCode.Control}), "Key");
					if (ui.isHovered) ui.tooltip("Invert the grid setting");

					ui.row([1/2, 1/2]);
					ui.text("Invert Rel. Grid");
					Main.prefs.keyMap.gridInvertRelative = ui.keyInput(Id.handle({value: KeyCode.Alt}), "Key");
					if (ui.isHovered) ui.tooltip("Invert the relative grid setting");

					ui.unindent();
				}

				if (ui.panel(Id.handle({selected: false}), "Console")) {
					ui.indent();

					//ui.text(lastTrace);
					ui.text("Mouse X: "+ ui.inputX);
					ui.text("Mouse Y: "+ ui.inputY);

					ui.unindent();
				}
			}
		}
		ui.end();

		if (ui.changed && !ui.inputDown) {
			drawGrid();
		}

		g.begin(false);

		if (dragAsset != null) {
			var w = Math.min(128, getImage(dragAsset).width);
			var ratio = w / getImage(dragAsset).width;
			var h = getImage(dragAsset).height * ratio;
			g.drawScaledImage(getImage(dragAsset), ui.inputX, ui.inputY, w, h);
		}

		g.end();

		if (lastW > 0 && (lastW != kha.System.windowWidth() || lastH != kha.System.windowHeight())) {
			resize();
		}
		else if (lastCanvasW > 0 && (lastCanvasW != canvas.width || lastCanvasH != canvas.height)) {
			resize();
		}
		lastW = kha.System.windowWidth();
		lastH = kha.System.windowHeight();
		lastCanvasW = canvas.width;
		lastCanvasH = canvas.height;

		if (showFiles) renderFiles(g);
		if (Popup.show) Popup.render(g);
	}

	function elemById(id: Int): TElement {
		for (e in canvas.elements) if (e.id == id) return e;
		return null;
	}

	function moveElem(d:Int) {
		var ar = canvas.elements;
		var i = ar.indexOf(selectedElem);
		var p = selectedElem.parent;

		while (true) {
			i += d;
			if (i < 0 || i >= ar.length) break;

			if (ar[i].parent == p) {
				ar.remove(selectedElem);
				ar.insert(i, selectedElem);
				break;
			}
		}
	}

	function getImage(asset:TAsset):kha.Image {
		return Canvas.assetMap.get(asset.id);
	}

	function removeElem(elem:TElement) {
		if (elem.children != null) for (id in elem.children) removeElem(elemById(id));
		canvas.elements.remove(elem);
		if (elem.parent != null) {
			elemById(elem.parent).children.remove(elem.id);
			elem.parent = null;
		}
	}

	function removeSelectedElem() {
		removeElem(selectedElem);
		selectedElem = null;
	}

	function acceptDrag(index:Int) {
		var elem = makeElem(ElementType.Image);
		elem.asset = assetNames[index + 1]; // assetNames[0] == ""
		elem.x = ui.inputX - canvas.x;
		elem.y = ui.inputY - canvas.y;
		elem.width = getImage(canvas.assets[index]).width;
		elem.height = getImage(canvas.assets[index]).height;
		selectedElem = elem;
	}

	function hitbox(x:Float, y:Float, w:Float, h:Float, ?rotation:Float):Bool {
		var rotatedInput:Vector2 = rotatePoint(ui.inputX, ui.inputY, x + w / 2, y + h / 2, -rotation);
		return rotatedInput.x > x && rotatedInput.x < x + w && rotatedInput.y > y && rotatedInput.y < y + h;
	}

	public function update() {

		// Drag from assets panel
		if (ui.inputReleased && dragAsset != null) {
			if (ui.inputX < kha.System.windowWidth() - uiw) {
				var index = 0;
				for (i in 0...canvas.assets.length) if (canvas.assets[i] == dragAsset) { index = i; break; }
				acceptDrag(index);
			}
			dragAsset = null;
		}
		if (dragAsset != null) return;

		updateCanvas();

		// Select frame
		if (timeline != null) {
			var ty = kha.System.windowHeight() - timeline.height;
			if (ui.inputDown && ui.inputY > ty && ui.inputX < kha.System.windowWidth() - uiw && ui.inputX > toolbarw) {
				selectedFrame = Std.int((ui.inputX - toolbarw) / 11 / ui.SCALE());
			}
		}

		if (selectedElem != null) {
			var elem = selectedElem;
			var ex = scaled(absx(elem));
			var ey = scaled(absy(elem));
			var ew = scaled(elem.width);
			var eh = scaled(elem.height);
			var rotatedInput:Vector2 = rotatePoint(ui.inputX, ui.inputY, canvas.x + ex + ew / 2, canvas.y + ey + eh / 2, -elem.rotation);

			if (ui.inputStarted && ui.inputDown) {
				// Drag selected element
				if (hitbox(canvas.x + ex - handleSize / 2, canvas.y + ey - handleSize / 2, ew + handleSize, eh + handleSize, selectedElem.rotation)) {
					drag = true;
					// Resize
					dragLeft = dragRight = dragTop = dragBottom = false;
					if (rotatedInput.x > canvas.x + ex + ew - handleSize) dragRight = true;
					else if (rotatedInput.x < canvas.x + ex + handleSize) dragLeft = true;
					if (rotatedInput.y > canvas.y + ey + eh - handleSize) dragBottom = true;
					else if (rotatedInput.y < canvas.y + ey + handleSize) dragTop = true;

					startElementManipulation(true);

				} else {
					var rotHandleCenter = new Vector2(canvas.x + ex + ew / 2, canvas.y + ey - handleSize * 2);
					var inputPos = rotatedInput.sub(rotHandleCenter);

					// Rotate selected element
					if (inputPos.length <= handleSize) {
						rotate = true;
						startElementManipulation(true);
					}
				}
			}

			if (isManipulating) {
				hwin.redraws = 2;

				// Confirm
				if ((transformStartedMouse && ui.inputReleased) || (!transformStartedMouse && ui.inputStarted)) {
					endElementManipulation();

				// Reset
				} else if ((ui.isKeyPressed && ui.isEscapeDown) || ui.inputStartedR) {
					endElementManipulation(true);

				} else if (drag) {
					var transformDelta = new Vector2(ui.inputX, ui.inputY).sub(transformInitInput);

					if (!transformStartedMouse) {
						if (ui.isKeyPressed && ui.key == KeyCode.X) {
							elem.width = Std.int(transformInitSize.x);
							elem.height = Std.int(transformInitSize.y);
							dragRight = true;
							dragBottom = !dragBottom;
						}
						if (ui.isKeyPressed && ui.key == KeyCode.Y) {
							elem.width = Std.int(transformInitSize.x);
							elem.height = Std.int(transformInitSize.y);
							dragBottom = true;
							dragRight = !dragRight;
						}
					}

					if (dragRight) {
						transformDelta.x = calculateTransformDelta(transformDelta.x, transformInitPos.x + transformInitSize.x);
						elem.width = Std.int(transformInitSize.x + transformDelta.x);
					} else if (dragLeft) {
						transformDelta.x = calculateTransformDelta(transformDelta.x, transformInitPos.x);
						elem.x = transformInitPos.x + transformDelta.x;
						elem.width = Std.int(transformInitSize.x - transformDelta.x);
					}
					if (dragBottom) {
						transformDelta.y = calculateTransformDelta(transformDelta.y, transformInitPos.y + transformInitSize.y);
						elem.height = Std.int(transformInitSize.y + transformDelta.y);
					}
					else if (dragTop) {
						transformDelta.y = calculateTransformDelta(transformDelta.y, transformInitPos.y);
						elem.y = transformInitPos.y + transformDelta.y;
						elem.height = Std.int(transformInitSize.y - transformDelta.y);
					}

					if (elem.type != ElementType.Image) {
						if (elem.width < 1) elem.width = 1;
						if (elem.height < 1) elem.height = 1;
					}

					if (!dragLeft && !dragRight && !dragBottom && !dragTop) {
						grab = true;
						grabX = true;
						grabY = true;
						drag = false;
					} else {
						// Ensure there the delta is 0 on unused axes
						if (!dragBottom && !dragTop) transformDelta.y = 0;
						else if (!dragLeft && !dragRight) transformDelta.y = 0;

						currentOperation = ' x: ${elem.x}  y: ${elem.y}  w: ${elem.width}  h: ${elem.height}  (dx: ${transformDelta.x}  dy: ${transformDelta.y})';
					}

				} else if (grab) {
					var transformDelta = new Vector2(ui.inputX, ui.inputY).sub(transformInitInput);

					if (ui.isKeyPressed && ui.key == KeyCode.X) {
						elem.x = transformInitPos.x;
						elem.y = transformInitPos.y;
						grabX = true;
						grabY = !grabY;
					}
					if (ui.isKeyPressed && ui.key == KeyCode.Y) {
						elem.x = transformInitPos.x;
						elem.y = transformInitPos.y;
						grabY = true;
						grabX = !grabX;
					}

					if (grabX) {
						transformDelta.x = calculateTransformDelta(transformDelta.x, transformInitPos.x);
						elem.x = Std.int(transformInitPos.x + transformDelta.x);
					}
					if (grabY) {
						transformDelta.y = calculateTransformDelta(transformDelta.y, transformInitPos.y);
						elem.y = Std.int(transformInitPos.y + transformDelta.y);
					}

					// Ensure there the delta is 0 on unused axes
					if (!grabX) transformDelta.x = 0;
					else if (!grabY) transformDelta.y = 0;

					currentOperation = ' x: ${elem.x}  y: ${elem.y}  (dx: ${transformDelta.x}  dy: ${transformDelta.y})';

				} else if (rotate) {
					var elemCenter = new Vector2(canvas.x + ex + ew / 2, canvas.y + ey + eh / 2);
					var inputPos = new Vector2(ui.inputX, ui.inputY).sub(elemCenter);

					// inputPos.x and inputPos.y are both positive when the mouse is in the lower right
					// corner of the elements center, so the positive x axis used for the angle calculation
					// in atan2() is equal to the global negative y axis. That's why we have to invert the
					// angle and add Pi to get the correct rotation. atan2() also returns an angle in the
					// intervall (-PI, PI], so we don't have to calculate the angle % PI*2 anymore.
					var inputAngle = -Math.atan2(inputPos.x, inputPos.y) + Math.PI;

					// Ctrl toggles rotation step mode
					if ((ui.isKeyDown && ui.key == Main.prefs.keyMap.gridInvert) != useRotationSteps) {
						inputAngle = Math.round(inputAngle / rotationSteps) * rotationSteps;
					}

					elem.rotation = inputAngle;
					currentOperation = " Rot: " + roundPrecision(toDegrees(inputAngle), 2) + "deg";
				}
			}

			if (ui.isKeyPressed && !ui.isTyping) {
				if (!grab && ui.key == Main.prefs.keyMap.grabKey){startElementManipulation(); grab = true; grabX = true; grabY = true;}
				if (!drag && ui.key == Main.prefs.keyMap.sizeKey) {startElementManipulation(); drag = true; dragLeft = false; dragTop = false; dragRight = true; dragBottom = true;}
				if (!rotate && ui.key == Main.prefs.keyMap.rotateKey) {startElementManipulation(); rotate = true;}

				if (!isManipulating) {
					// Move with arrows
					if (ui.key == KeyCode.Left) gridSnapPos ? elem.x -= gridSize : elem.x--;
					if (ui.key == KeyCode.Right) gridSnapPos ? elem.x += gridSize : elem.x++;
					if (ui.key == KeyCode.Up) gridSnapPos ? elem.y -= gridSize : elem.y--;
					if (ui.key == KeyCode.Down) gridSnapPos ? elem.y += gridSize : elem.y++;

					if (ui.isBackspaceDown || ui.isDeleteDown) removeSelectedElem();
					else if (ui.key == KeyCode.D) selectedElem = duplicateElem(elem);
				}
			}
		} else {
			endElementManipulation();
		}

		if (Popup.show) Popup.update();

		updateFiles();
	}

	function startElementManipulation(?mousePressed=false) {
		if (isManipulating) endElementManipulation(true);

		transformInitInput = new Vector2(ui.inputX, ui.inputY);
		transformInitPos = new Vector2(selectedElem.x, selectedElem.y);
		transformInitSize = new Vector2(selectedElem.width, selectedElem.height);
		transformInitRot = selectedElem.rotation;
		transformStartedMouse = mousePressed;

		isManipulating = true;
	}

	function endElementManipulation(reset=false) {
		if (reset) {
			selectedElem.x = transformInitPos.x;
			selectedElem.y = transformInitPos.y;
			selectedElem.width = Std.int(transformInitSize.x);
			selectedElem.height = Std.int(transformInitSize.y);
			selectedElem.rotation = transformInitRot;
		}

		isManipulating = false;

		grab = false;
		drag = false;
		rotate = false;

		transformStartedMouse = false;
		currentOperation = "";
	}

	function updateCanvas() {
		if (showFiles || ui.inputX > kha.System.windowWidth() - uiw) return;

		// Select elem
		var selectButton = Main.prefs.keyMap.selectMouseButton;
		if (selectButton == "Left" && ui.inputStarted && ui.inputDown ||
				selectButton == "Right" && ui.inputStartedR && ui.inputDownR) {
			var i = canvas.elements.length;
			for (elem in canvas.elements) {
				var ex = scaled(absx(elem));
				var ey = scaled(absy(elem));
				var ew = scaled(elem.width);
				var eh = scaled(elem.height);

				if (hitbox(canvas.x + ex, canvas.y + ey, ew, eh, elem.rotation) &&
						selectedElem != elem) {
					selectedElem = elem;
					break;
				}
			}
		}

		if (!isManipulating) {
			// Pan canvas
			if (ui.inputDownR) {
				coffX += Std.int(ui.inputDX);
				coffY += Std.int(ui.inputDY);
			}

			// Zoom canvas
			if (ui.inputWheelDelta != 0) {
				zoom += -ui.inputWheelDelta / 10;
				if (zoom < 0.4) zoom = 0.4;
				else if (zoom > 1.0) zoom = 1.0;
				zoom = Math.round(zoom * 10) / 10;
				cui.ops.scaleFactor = zoom;
			}
		}

		// Canvas resize
		if (ui.inputStarted && hitbox(canvas.x + scaled(canvas.width) - 3, canvas.y + scaled(canvas.height) - 3, 6, 6)) {
			resizeCanvas = true;
		}
		if (ui.inputReleased && resizeCanvas) {
			resizeCanvas = false;
		}
		if (resizeCanvas) {
			canvas.width += Std.int(ui.inputDX);
			canvas.height += Std.int(ui.inputDY);
			if (canvas.width < 1) canvas.width = 1;
			if (canvas.height < 1) canvas.height = 1;
		}
	}

	function updateFiles() {
		if (!showFiles) return;

		if (ui.inputReleased) {
			var appw = kha.System.windowWidth();
			var apph = kha.System.windowHeight();
			var left = appw / 2 - modalRectW / 2;
			var right = appw / 2 + modalRectW / 2;
			var top = apph / 2 - modalRectH / 2;
			var bottom = apph / 2 + modalRectH / 2;
			if (ui.inputX < left || ui.inputX > right || ui.inputY < top + modalHeaderH || ui.inputY > bottom) {
				showFiles = false;
			}
		}
	}

	static var modalW = 625;
	static var modalH = 545;
	static var modalHeaderH = 66;
	static var modalRectW = 625; // No shadow
	static var modalRectH = 545;

	static var path = '/';
	function renderFiles(g:kha.graphics2.Graphics) {
		var appw = kha.System.windowWidth();
		var apph = kha.System.windowHeight();
		var left = appw / 2 - modalW / 2;
		var top = apph / 2 - modalH / 2;

		g.begin(false);
		g.color = 0xff202020;
		g.fillRect(left, top, modalW, modalH);
		g.end();

		var leftRect = Std.int(appw / 2 - modalRectW / 2);
		var rightRect = Std.int(appw / 2 + modalRectW / 2);
		var topRect = Std.int(apph / 2 - modalRectH / 2);
		var bottomRect = Std.int(apph / 2 + modalRectH / 2);
		topRect += modalHeaderH;

		uimodal.begin(g);
		if (uimodal.window(Id.handle(), leftRect, topRect, modalRectW, modalRectH - 100)) {
			var pathHandle = Id.handle();
			pathHandle.text = uimodal.textInput(pathHandle);
			path = uimodal.fileBrowser(pathHandle, foldersOnly);
		}
		uimodal.end(false);

		g.begin(false);

		uimodal.beginRegion(g, rightRect - 100, bottomRect - 30, 100);
		if (uimodal.button("OK")) {
			showFiles = false;
			filesDone(path);
		}
		uimodal.endRegion(false);

		uimodal.beginRegion(g, rightRect - 200, bottomRect - 30, 100);
		if (uimodal.button("Cancel")) {
			showFiles = false;
		}
		uimodal.endRegion();

		g.end();
	}

	function absx(e:TElement):Float {
		if (e == null) return 0;
		return e.x + absx(elemById(e.parent));
	}

	function absy(e:TElement):Float {
		if (e == null) return 0;
		return e.y + absy(elemById(e.parent));
	}

	function roundPrecision(v:Float, ?precision=0):Float {
		v *= Math.pow(10, precision);

		v = Std.int(v) * 1.0;
		v /= Math.pow(10, precision);

		return v;
	}

	function rotatePoint(pointX: Float, pointY: Float, centerX: Float, centerY: Float, angle:Float): Vector2 {
		pointX -= centerX;
		pointY -= centerY;

		var x = pointX * Math.cos(angle) - pointY * Math.sin(angle);
		var y = pointX * Math.sin(angle) + pointY * Math.cos(angle);

		return new Vector2(centerX + x, centerY + y);
	}

	function calculateTransformDelta(value:Float, ?offset=0.0):Float {
		var precisionMode = ui.isKeyDown && ui.key == Main.prefs.keyMap.slowMovement;
		var enabled = gridSnapPos != (ui.isKeyDown && (ui.key == Main.prefs.keyMap.gridInvert));
		var useOffset = gridUseRelative != (ui.isKeyDown && (ui.key == Main.prefs.keyMap.gridInvertRelative));

		if (!enabled) return precisionMode ? value / 2 : value;

		// Round the delta value to steps of gridSize
		value = Math.round(value / gridSize) * gridSize;

		if (precisionMode) value /= 2;

		// Apply an offset
		if (useOffset && offset != 0) {
			offset = offset % gridSize;

			// Round to nearest grid position instead of rounding off
			if (offset > gridSize / 2) {
				offset = -(gridSize - offset);
			}

			value -= offset;
		}
		return value;
	}

	inline function scaled(f: Float): Int { return Std.int(f * cui.SCALE()); }
}
