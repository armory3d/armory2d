let project = new Project('ArmorUI');

project.addSources('Sources');
project.addAssets('Assets/**');
project.addLibrary('zui');

resolve(project);
