let project = new Project('Elements');

project.addSources('Sources');
project.addAssets('Assets/**');
project.addLibrary('zui');

resolve(project);
