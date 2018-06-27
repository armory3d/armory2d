# armory2d

![](img.jpg)

Stand-alone 2D editor focused on games. Used in Armory, written in Haxe and Kha.

Armory2D outputs a json or binary file representing the scene components. This file can be rendered through [Zui library](https://github.com/armory3d/zui/tree/master/examples/Canvas). Alternatively, it is possible to implement and read the [Canvas](https://github.com/armory3d/zui/blob/master/Sources/zui/Canvas.hx#L68) structure manually in any application.

## Run

- `git clone --recursive https://github.com/armory3d/armory2d`
- `cd armory2d`
- `git submodule foreach --recursive git pull origin master`
- `git pull origin master`
- Drop cloned `armory2d` folder into [KodeStudio](https://github.com/Kode/KodeStudio/releases)
