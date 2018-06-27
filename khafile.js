let project = new Project('Armory2D');

project.addSources('Sources');
project.addAssets('Assets/**');
project.addLibrary('zui');

resolve(project);
