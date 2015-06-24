var Store         = require('uow-store');
var RethinkDriver = require('./lib/driver.js');

module.exports    = function(config) {
  var rethinkDriver = new RethinkDriver(config);

  return new Store({ driver: rethinkDriver });
};
