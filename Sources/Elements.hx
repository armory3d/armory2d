package ;

import kha.math.Vector2;
import kha.input.KeyCode;
import zui.*;
import zui.Zui;
import zui.Canvas;

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
		return Std.int(100 * ui.SCALE);
	}
	static var coffX = 70.0;
	static var coffY = 50.0;

	var dropPath = "";
	var drag = false;
	var dragLeft = false;
	var dragTop = false;
	var dragRight = false;
	var dragBottom = false;
	var grab = false;
	var grabX = false;
	var grabY = false;
	var size = false;
	var sizeX = false;
	var sizeY = false;
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
	var gridSize:Int = 20;
	static var grid:kha.Image = null;
	static var timeline:kha.Image = null;

	var selectedFrame = 0;

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
		cui = new Zui({scaleFactor: 1.0, font: kha.Assets.fonts.font_default, autoNotifyInput: true, theme: zui.Themes.light});
		uimodal = new Zui( { font: kha.Assets.fonts.font_default, scaleFactor: Main.prefs.scaleFactor } );

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

	function unique(s:String):String {
		// for (e in canvas.elements) {
		// 	if (s == e.name) {
		// 		return unique(s + '.001');
		// 	}
		// }
		return s;
	}

	function makeElem(type:ElementType) {
		var name = "";
		var height = cui.t.ELEMENT_H;
		switch (type) {
		case ElementType.Text:
			name = unique("Text");
		case ElementType.Button:
			name = unique("Button");
		case ElementType.Image:
			name = unique("Image");
			height = 100;
		case ElementType.FRectangle:
			name = unique("Filled_Rectangle");
			height = 100;
		case ElementType.FCircle:
			name = unique("Filled_Circle");
		case ElementType.Rectangle:
			name = unique("Rectangle");
			height = 100;
		case ElementType.FTriangle:
			name = unique("Filled_Triangle");
		case ElementType.Triangle:
			name = unique("Triangle");
		case ElementType.Circle:
			name = unique("Circle");
		case ElementType.Check:
			name = unique("Check");
		case ElementType.Radio:
			name = unique("Radio");
		case ElementType.Combo:
			name = unique("Combo");
		case ElementType.Slider:
			name = unique("Slider");
		case ElementType.Input:
			name = unique("Input");
		case ElementType.ProgressBar:
			name = unique("Progress_bar");
		case ElementType.CProgressBar:
			name = unique("CProgress_bar");
		case ElementType.Empty:
			name = unique("Empty");
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
			color_bg: 0xff484848,
			color_text: 0xffe8e7e5,
			color_hover: 0xff3b3b3b,
			color_press: 0xff1b1b1b,
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
				color_bg: elem.color_bg,
				color_text: elem.color_text,
				color_hover: elem.color_hover,
				color_press: elem.color_press,
				progress_at: elem.progress_at,
				progress_total: elem.progress_total,
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

	function drawTimeline() {
		var sc = ui.SCALE;
		timeline = kha.Image.createRenderTarget(kha.System.windowWidth() - uiw - toolbarw, Std.int(60 * sc));
		var g = timeline.g2;
		g.begin(true, 0xff222222);
		g.font = kha.Assets.fonts.font_default;
		g.fontSize = Std.int(16 * sc);

		// Labels
		var frames = Std.int(timeline.width / (11 * sc));
		for (i in 0...Std.int(frames / 5) + 1) {
			g.drawString(i * 5 + "", i * 55 * sc, 0);
		}

		// Frames
		for (i in 0...frames) {
			g.color = i % 5 == 0 ? 0xff444444 : 0xff333333;
			g.fillRect(i * 11 * sc, 30 * sc, 10 * sc, 30 * sc);
		}

		g.end();
	}

	public function onFrames(framebuffers: Array<kha.Framebuffer>): Void {
		var framebuffer = framebuffers[0];

		if (dropPath != "") {
			importAsset(dropPath);
			dropPath = "";
		}

		// Bake
		if (grid == null) drawGrid();
		if (timeline == null) drawTimeline();

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
			g.pushRotation(selectedElem.rotation, canvas.x + ex + ew / 2, canvas.y + ey + eh / 2);

			g.drawRect(canvas.x + ex, canvas.y + ey, ew, eh);
			g.color = 0xff000000;
			g.drawRect(canvas.x + ex + 1, canvas.y + ey + 1, ew, eh);
			g.color = 0xffffffff;

			// Draw corner drag handles
			var handleSize = 8;
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
					g.drawRect(hX, hY, handleSize, handleSize);

					// Hover
					// Rotate mouse coords in opposite direction as the element
					var hoverPoint:Vector2 = rotatePoint(ui.inputX, ui.inputY, canvas.x + ex + ew / 2, canvas.y + ey + eh / 2, -selectedElem.rotation);

					if (hoverPoint.x > hX && hoverPoint.x < hX + handleSize) {
						if (hoverPoint.y > hY && hoverPoint.y < hY + handleSize) {
							g.color = 0xff205d9c;
							g.fillRect(hX, hY, handleSize, handleSize);
							g.color = 0xffffffff;
						}
					}
				}
			}
			g.popTransformation();
		}

		// Timeline
		var showTimeline = true;
		if (showTimeline) {
			g.color = 0xffffffff;
			var ty = kha.System.windowHeight() - timeline.height;
			g.drawImage(timeline, toolbarw, ty);

			g.color = 0xff205d9c;
			var sc = ui.SCALE;
			g.fillRect(toolbarw + selectedFrame * 11 * sc, ty + 30 * sc, 10 * sc, 30 * sc);
		}

		g.end();

		ui.begin(g);

		if (ui.window(Id.handle(), 0, 0, toolbarw, kha.System.windowHeight())) {
			ui._y = 50;
			if (ui.button("Empty")) {
				selectedElem = makeElem(ElementType.Empty);
			}
			// ui.button("VLayout");
			// ui.button("HLayout");
			if (ui.panel(Id.handle(), "Shapes")){
				ui.indent();
				if (ui.button("Rect")) {
					selectedElem = makeElem(ElementType.Rectangle);
				}
				if (ui.button("Fill Rect")) {
					selectedElem = makeElem(ElementType.FRectangle);
				}
				if (ui.button("Circle")){
					selectedElem = makeElem(ElementType.Circle);
				}
				if (ui.button("Fill Circle")){
					selectedElem = makeElem(ElementType.FCircle);
				}
				if (ui.button("Triangle")){
					selectedElem = makeElem(ElementType.Triangle);
				}
				if (ui.button("Fill Triangle")){
					selectedElem = makeElem(ElementType.FTriangle);
				}
				ui.unindent();
			}
			if (ui.panel(Id.handle(), "Texts")){
				ui.indent();
				if (ui.button("Text")) {
					selectedElem = makeElem(ElementType.Text);
				}
				if (ui.button("Input")) {
					selectedElem = makeElem(ElementType.Input);
				}
				ui.unindent();
			}
			if (ui.panel(Id.handle(), "ProgressBars")){
				ui.indent();
				if (ui.button("RectPB")) {
					selectedElem = makeElem(ElementType.ProgressBar);
				}
				if (ui.button("CircularPB")) {
					selectedElem = makeElem(ElementType.CProgressBar);
				}
				ui.unindent();
			}
			if (ui.button("Image")) {
				selectedElem = makeElem(ElementType.Image);
			}
			if (ui.button("Button")) {
				selectedElem = makeElem(ElementType.Button);
			}
			if (ui.button("Check")) {
				selectedElem = makeElem(ElementType.Check);
			}
			if (ui.button("Radio")) {
				selectedElem = makeElem(ElementType.Radio);
			}
			if (ui.button("Combo")) {
				selectedElem = makeElem(ElementType.Combo);
			}
			if (ui.button("Slider")) {
				selectedElem = makeElem(ElementType.Slider);
			}
		}

		if (ui.window(Id.handle(), toolbarw, 0, kha.System.windowWidth() - uiw - toolbarw, Std.int((ui.t.ELEMENT_H + 2) * ui.SCALE))) {
			ui.tab(Id.handle(), canvas.name);
		}

		if (ui.window(hwin, kha.System.windowWidth() - uiw, 0, uiw, kha.System.windowHeight())) {

			var htab = Id.handle();
			if (ui.tab(htab, "Project")) {

				if (ui.button("Save")) {

					// Unpan
					canvas.x = 0;
					canvas.y = 0;
					#if kha_krom
					Krom.fileSaveBytes(Main.prefs.path, haxe.io.Bytes.ofString(haxe.Json.stringify(canvas)).getData());
					#elseif kha_debug_html5
					var fs = untyped __js__('require("fs");');
					var path = untyped __js__('require("path")');
					var filePath = path.resolve(untyped __js__('__dirname'), Main.prefs.path);
					try { fs.writeFileSync(filePath, haxe.Json.stringify(canvas)); }
					catch (x: Dynamic) { trace('saving "${filePath}" failed'); }
					#end

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

					canvas.x = coffX;
					canvas.y = coffY;
				}

				if (ui.panel(Id.handle({selected: false}), "Canvas")) {

					if (ui.button("New")) {
						canvas.elements = [];
						selectedElem = null;
					}

					canvas.name = ui.textInput(Id.handle({text: canvas.name}), "Name", Right);
					ui.row([1/2, 1/2]);

					
					var handlecw = Id.handle({text: canvas.width + ""});
					var handlech = Id.handle({text: canvas.height + ""});
					handlecw.text = canvas.width + "";
					handlech.text = canvas.height + "";
					var strw = ui.textInput(handlecw, "Width", Right);
					var strh = ui.textInput(handlech, "Height", Right);
					canvas.width = Std.parseInt(strw);
					canvas.height = Std.parseInt(strh);
				}

				if (ui.panel(Id.handle({selected: true}), "Outliner")) {

					function drawList(h:zui.Zui.Handle, elem:TElement) {
						var b = false;
						// Highlight
						if (selectedElem == elem) {
							ui.g.color = 0xff205d9c;
							ui.g.fillRect(0, ui._y, ui._windowW, ui.t.ELEMENT_H * ui.SCALE);
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
							b = ui.panel(h.nest(elem.id, {selected: true}), "", 0, true);
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
					if (ui.button("Down") && selectedElem != null) {
						moveElem(-1);
					}
					if (ui.button("Remove") && selectedElem != null) {
						removeSelectedElem();
					}
					if (ui.button("Duplicate") && selectedElem != null) {
						selectedElem = duplicateElem(selectedElem);
					}
				}

				if (selectedElem != null) {
					var elem = selectedElem;
					var id = elem.id;

					if (ui.panel(Id.handle({selected: true}), "Properties")) {
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
							var handles = Id.handle().nest(id, {text: "1"});
							var strs = ui.textInput(handles, "Line Strength", Right);
							elem.strength = Std.int(Std.parseFloat(strs));
						}
						if (elem.type == ElementType.ProgressBar || elem.type == ElementType.CProgressBar){
							var handlep = Id.handle().nest(id, {text: "1"});
							var strp = ui.textInput(handlep, "Progress", Right);
							var handlespt = Id.handle().nest(id, {text: "1"});
							var strpt = ui.textInput(handlespt, "Total Progress", Right);
							elem.progress_total = Std.int(Std.parseFloat(strpt));
							elem.progress_at = Std.int(Std.parseFloat(strp));
						}
						var handlerot = Id.handle().nest(id, {value: toDegrees(elem.rotation == null ? 0 : elem.rotation)});
						elem.rotation = toRadians(ui.slider(handlerot, "Rotation", 0.0, 360.0, true));
						var assetPos = ui.combo(Id.handle().nest(id, {position: getAssetIndex(elem.asset)}), getEnumTexts(), "Asset", true, Right);
						elem.asset = getEnumTexts()[assetPos];
					}
					if (ui.panel(Id.handle({selected: false}), "Color")){
						if (elem.type == ElementType.Text){
							ui.text("Text:");
							elem.color_text = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_text}), true, null, true);
						}else if (elem.type == ElementType.Button){
							ui.text("Text:");
							elem.color_text = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_text}), true, null, true);
							ui.text("Background:");
							elem.color_bg = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_bg}), true, null, true);
							ui.text("On Hover:");
							elem.color_hover = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_hover}), true, null, true);
							ui.text("On Pressed:");
							elem.color_press = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_press}), true, null, true);
						}else if (elem.type == ElementType.FRectangle || elem.type == ElementType.FCircle || 
							elem.type == ElementType.Rectangle || elem.type == ElementType.Circle || 
							elem.type == ElementType.Triangle || elem.type == ElementType.FTriangle|| 
							elem.type == ElementType.ProgressBar|| elem.type == ElementType.CProgressBar){
							ui.text("Color:");
							elem.color_bg = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_bg}), true, null, true);	
						}else if (elem.type == ElementType.Empty){
							ui.text("No color for element type empty");
						}else{
							ui.text("Text:");
							elem.color_text = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_text}), true, null, true);
							ui.text("Background:");
							elem.color_bg = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_bg}), true, null, true);
							ui.text("On Hover:");
							elem.color_hover = Ext.colorWheel(ui, Id.handle().nest(id, {color: elem.color_hover}), true, null, true);
						}
					}

					if (ui.panel(Id.handle({selected: false}), "Align")) {
					}

					if (ui.panel(Id.handle({selected: false}), "Anchor")) {
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
					}

					if (ui.panel(Id.handle({selected: false}), "Script")) {
						elem.event = ui.textInput(Id.handle().nest(id, {text: elem.event}), "Event", Right);
					}

					if (ui.panel(Id.handle({selected: false}), "Timeline")) {
						// ui.row([1/2,1/2]);
						// ui.button("Insert");
						// ui.button("Remove");
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
				var selectMouseHandle = Id.handle({position: 0});
				ui.combo(selectMouseHandle, ["Left Click", "Right Click"], "Select Elements With", true);
				if (selectMouseHandle.changed) {
					Main.prefs.selectMouseButton = ["Left", "Right"][selectMouseHandle.position];
				}

				var hscale = Id.handle({value: 1.0});
				ui.slider(hscale, "UI Scale", 0.5, 4.0, true);
				var gsize = Id.handle({value: 20});
				ui.slider(gsize, "Grid Size", 1, 128, true, 1);
				gridSnapPos = ui.check(Id.handle({selected: true}), "Grid Snap Position");
				gridSnapBounds = ui.check(Id.handle({selected: false}), "Grid Snap Bounds");
				if (ui.changed && !ui.inputDown) {
					gridSize = Std.int(gsize.value);
					ui.setScale(hscale.value);
					windowW = Std.int(defaultWindowW * hscale.value);
				}

				Main.prefs.window_vsync = ui.check(Id.handle({selected: true}), "VSync");
				// if (ui.button("Save")) {
				// 	#if kha_krom
				// 	Krom.fileSaveBytes("config.arm", haxe.io.Bytes.ofString(haxe.Json.stringify(armory.data.Config.raw)).getData());
				// 	#end
				// }
				// ui.text("armory2d");

				if (ui.panel(Id.handle({selected: true}), "Console")) {
					//ui.text(lastTrace);
					ui.text("Mouse X: "+ ui.inputX);
					ui.text("Mouse Y: "+ ui.inputY);
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
		var hoverPoint:Vector2 = rotatePoint(ui.inputX, ui.inputY, x + w / 2, y + h / 2, -rotation);
		return hoverPoint.x > x && hoverPoint.x < x + w && hoverPoint.y > y && hoverPoint.y < y + h;
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
				selectedFrame = Std.int((ui.inputX - toolbarw) / 11 / ui.SCALE);
			}
		}

		if (selectedElem != null) {
			var elem = selectedElem;
			var ex = scaled(absx(elem));
			var ey = scaled(absy(elem));
			var ew = scaled(elem.width);
			var eh = scaled(elem.height);

			// Drag selected elem
			if (ui.inputStarted && ui.inputDown && 
			hitbox(canvas.x + ex - 4, canvas.y + ey - 4, ew + 4, eh + 4, selectedElem.rotation)) {
				var hoverPoint:Vector2 = rotatePoint(ui.inputX, ui.inputY, canvas.x + ex + ew / 2, canvas.y + ey + eh / 2, -elem.rotation);

				drag = true;
				// Resize
				dragLeft = dragRight = dragTop = dragBottom = false;
				if (hoverPoint.x > canvas.x + ex + ew - 4) dragRight = true;
				else if (hoverPoint.x < canvas.x + ex + 4) dragLeft = true;
				if (hoverPoint.y > canvas.y + ey + eh - 4) dragBottom = true;
				else if (hoverPoint.y < canvas.y + ey + 4) dragTop = true;

			}

			if (ui.inputReleased) {
				if (grab || drag){
					drag = false;
					grab = false;
					if (gridSnapBounds) {
						elem.width = Math.round(elem.width / gridSize) * gridSize;
						elem.height = Math.round(elem.height / gridSize) * gridSize;
					}
					if (gridSnapPos) {
						elem.x = Math.round(elem.x / gridSize) * gridSize;
						elem.y = Math.round(elem.y / gridSize) * gridSize;
					}
				}
			}

			if (drag) {
				hwin.redraws = 2;

				if (dragRight) elem.width += Std.int(ui.inputDX);
				else if (dragLeft) { elem.x += Std.int(ui.inputDX); elem.width -= Std.int(ui.inputDX); }
				if (dragBottom) elem.height += Std.int(ui.inputDY);
				else if (dragTop) { elem.y += Std.int(ui.inputDY); elem.height -= Std.int(ui.inputDY); }
			
				if (elem.type != ElementType.Image) {
					if (elem.width < 1) elem.width = 1;
					if (elem.height < 1) elem.height = 1;
				}

				if (!dragLeft && !dragRight && !dragBottom && !dragTop) {
					elem.x += ui.inputDX;
					elem.y += ui.inputDY;
				}
			}
			if(grab){
				hwin.redraws = 2;
				size = false;
				if (!grabX && !grabY){
					elem.x += Std.int(ui.inputDX); 
					elem.y += Std.int(ui.inputDY);
				}else if (grabX){
					elem.x += Std.int(ui.inputDX);
				}else if (grabY){
					elem.y += Std.int(ui.inputDY);
				}
			}
			if(size){
				hwin.redraws = 2;
				grab = false;
				if (!sizeX && !sizeY){
					elem.height += Std.int(ui.inputDY);
					elem.width += Std.int(ui.inputDX);
				}else if (sizeX){
					elem.width += Std.int(ui.inputDX);
				}else if (sizeY){
					elem.height += Std.int(ui.inputDY);
				}
			}
			if (ui.inputStarted){
				if (grab || size){
					grab = false; 
					size = false;
				}
			}

			// Move with arrows
			if (ui.isKeyDown && !ui.isTyping) {
				if (ui.key == KeyCode.Left) gridSnapPos ? elem.x -= gridSize : elem.x--;
				if (ui.key == KeyCode.Right) gridSnapPos ? elem.x += gridSize : elem.x++;
				if (ui.key == KeyCode.Up) gridSnapPos ? elem.y -= gridSize : elem.y--;
				if (ui.key == KeyCode.Down) gridSnapPos ? elem.y += gridSize : elem.y++;

				if (ui.key == KeyCode.G) {grab = true; grabX = false; grabY = false;}
				if (grab && ui.key == KeyCode.X){grabX = true; grabY = false;}
				if (grab && ui.key == KeyCode.Y){grabY = true; grabX = false;}

				if (ui.key == KeyCode.S) {size = true; sizeX = false; sizeY = false;}
				if (size && ui.key == KeyCode.X){sizeX = true; sizeY = false;}
				if (size && ui.key == KeyCode.Y){sizeY = true; sizeX = false;}

				if (ui.key == KeyCode.Backspace || ui.key == KeyCode.Delete) removeSelectedElem();
				if (ui.key == KeyCode.D) selectedElem = duplicateElem(elem);

				hwin.redraws = 2;
			}
		}

		updateFiles();
	}

	function updateCanvas() {
		if (showFiles || ui.inputX > kha.System.windowWidth() - uiw) return;

		// Select elem
		var selectButton = Main.prefs.selectMouseButton;
		if ((selectButton == "Left" || selectButton == null) && ui.inputStarted && ui.inputDown ||
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
			cui.SCALE = cui.ops.scaleFactor * zoom;
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
			path = zui.Ext.fileBrowser(uimodal, pathHandle, foldersOnly);
		}
		uimodal.end(false);
		
		g.begin(false);
		
		uimodal.beginLayout(g, rightRect - 100, bottomRect - 30, 100);
		if (uimodal.button("OK")) {
			showFiles = false;
			filesDone(path);
		}
		uimodal.endLayout(false);

		uimodal.beginLayout(g, rightRect - 200, bottomRect - 30, 100);
		if (uimodal.button("Cancel")) {
			showFiles = false;
		}
		uimodal.endLayout();

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

	function rotatePoint(pointX: Float, pointY: Float, centerX: Float, centerY: Float, angle:Float): Vector2 {
		pointX -= centerX;
		pointY -= centerY;

		var x = pointX * Math.cos(angle) - pointY * Math.sin(angle);
		var y = pointX * Math.sin(angle) + pointY * Math.cos(angle);

		return new Vector2(centerX + x, centerY + y);
	}

	inline function scaled(f: Float): Int { return Std.int(f * cui.SCALE); }
}
