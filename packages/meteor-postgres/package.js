Package.describe({
  name: 'endykaufman:meteor-postgres',
  version: '0.2.5',
  summary: 'PostgreSQL support for Meteor',
  git: 'https://github.com/EndyKaufman/meteor-postgres',
  documentation: 'README.md'
});

Npm.depends({
  'pg': '4.3.0'
});

Package.onUse(function (api) {
  api.versionsFrom('1.1.0.2');
  api.use('coffeescript');
  api.use('underscore');
  api.use('tracker');
  api.use('ddp');
  api.use('agershun:alasql@0.2.0');

  api.addFiles([
    'lib/init.js',
    'lib/sql.coffee'
  ], ['client', 'server']);

  api.addFiles([
    'lib/client.coffee'
  ], 'client');

  api.addFiles([
    'lib/server.coffee'
  ], 'server');

  api.addFiles([
    'lib/collection.coffee'
  ]);

  api.export('SQL');
});