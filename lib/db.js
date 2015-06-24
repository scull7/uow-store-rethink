var bluebird    = require('bluebird');
var R           = require('ramda');
var r           = require('rethinkdb');
var Pool        = require('rethinkdb-pool');

var TABLE_TASK  = 'uow_task';

var defaults    = {
  host:         'localhost',
  port:         28015,
  authKey:      '',
  r:            r,
  Promise:      bluebird
};

/**
 * Obtain a pooled connection to the database.
 * -------------------------------------------
 * @param {Object} config {
 *    host: <string> - default: 'localhost'
 *    port: <int> - default: 28015
 *    db: <string> - alias: database
 *    authKey: <string> - default: '', alias: password
 *    r: <rethinkdb> - default: rethinkdb
 *    Promise: <Promise> - default: bluebird
 * }
 * @return {Pool}
 * @throws {TypeError}
 */
function init(config) {
  if (!config || (!config.db && !config.database)) {
    throw new TypeError('DatabaseNotSpecified');
  }

  if (config.database) {
    config.db       = config.database;
  }

  if (config.hasOwnProperty('password')) {
    config.authKey  = config.password;
  }

  var options         = R.merge(defaults, config);

  /* jshint newcap: false */
  return Pool(options);
  /* jshint newcap: true */
}

/**
 * Create the task table.
 * ----------------------
 * @param {Pool} db
 * @return {Promise::Cursor}
 */
function createTaskTable(db) {
  var r                 = db.r;
  var createQuery       = r.tableCreate(TABLE_TASK);
  var statusIndexQuery  = r.table(TABLE_TASK).indexCreate('status');

  return db.run(createQuery)

  .then(function() {
    return db.run(statusIndexQuery);
  })

  .then(function() {
    return db;
  });
}

/**
 * drop the task table.
 * --------------------
 * @param {Pool} db
 * @return {Promise::Cursor}
 */
function deleteTaskTable(db) {
  var existsQuery = db.r.tableList().contains(TABLE_TASK);
  var dropQuery   = db.r.tableDrop(TABLE_TASK);

  return db.run(existsQuery)

  .then(function(exists) {

    if (exists) {
      return db.run(dropQuery).then(function() { return db; });
    }

    return db;
  });
}

/**
 * Install the task table.
 * -----------------------
 * @param {Pool} db
 * @return {Promise::Pool}
 */
function install(db) {
  var r             = db.r;
  var hasTableQuery = r.tableList().contains(TABLE_TASK);

  return db.run(hasTableQuery)

  .then(function(hasTable) {
    if (!hasTable) {
      return createTaskTable(db).then(function() { return db; });
    }

    return db;
  });
}

module.exports  = function(config) {
  var pool      = init(config);
  pool.r        = r;

  return {
    acquire:          pool.acquire.bind(pool),
    r:                r,
    run:              pool.run.bind(pool),
    install:          install.bind(null, pool),
    clean:            deleteTaskTable.bind(null, pool)
  };
};
