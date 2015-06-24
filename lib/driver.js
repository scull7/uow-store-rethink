var R                     = require('ramda');
var bluebird              = require('bluebird');
var inherits              = require('util').inherits;
var EventEmitter          = require('events').EventEmitter;

var DB                    = require('./db.js');
var TABLE                 = 'uow_task';

var defaults              = {
  // Default search delay is 500ms.
  taskReadyDelay:         500,
  isTaskReady:            R.where({ status: R.equals('ready') }),
  runTaskSearch:          true
};

function RethinkDriver(options) {
  options = R.merge(defaults, options);

  this.db             = DB(options);
  this.r              = this.db.r;
  this.isTaskReady    = options.isTaskReady;
  this.taskReadyDelay = options.taskReadyDelay;
  this.runTaskSearch  = options.runTaskSearch;

  this.readyTaskQuery = this.r.table(TABLE).filter(
    this.r.row('status').eq('ready')
    .and(
      this.r.row.hasFields('semaphore').not().or(
        this.r.row('semaphore').eq(null)
      )
    )
  );

  if (this.runTaskSearch) {
    this.findReady(this.taskReadyDelay);
  }
}

inherits(RethinkDriver, EventEmitter);

/**
 * Search through the stored tasks to find any ready to proces tasks.
 * ------------------------------------------------------------------
 * @param {int} delay - number of milliseconds
 */
RethinkDriver.prototype.findReady = function(delay) {
  if (delay) {
    return setTimeout(this.findReady.bind(this), delay);
  }

  this.db.run(this.readyTaskQuery)

  .then(function(readyTaskList) {

    for (var i = 0; i < readyTaskList.length; i += 1) {

      this.emit('task::ready', readyTaskList[i].id);

    }
  }.bind(this));

  if (this.runTaskSearch) {
    this.findReady(this.taskReadyDelay);
  }
};

/**
 * Store the given task object.
 * ----------------------------
 * @param {Task} task
 * @return {Promise::Task}
 * @throws {TypeError}
 */
RethinkDriver.prototype.create  = function(task) {

  return bluebird.resolve(task.id)

  .then(function(taskId) {

    if (!taskId) {
      throw new TypeError('TaskIdNotPresent');
    }

    return this.getById(taskId)

    .then(function() {

      throw new TypeError('TaskIdExists');

    })

    .catch(RangeError, function() {

      return task;

    });

  }.bind(this))

  .then(function(task) {

    var query = this.r.table(TABLE).insert(task);

    return this.db.run(query)

    .then(function() {

      return this.getById(task.id);

    }.bind(this));

  }.bind(this));

};

/**
 * Replace the stored task object with the given task object.
 * ----------------------------------------------------------
 * @param {Task} task
 * @return {Promise::Task}
 * @throws {TypeError}
 */
RethinkDriver.prototype.update  = function(task) {

  return bluebird.resolve(task.id)

  .then(function(taskId) {

    if (!taskId) {
      throw new TypeError('TaskIdNotPresent');
    }

    var update  = this.r.table(TABLE).get(taskId).update(task);

    return this.db.run(update);

  }.bind(this))

  .then(function(updated) {

    if (updated.skipped > 0) {
      throw new RangeError('TaskNotFound');
    }

    return this.getById(task.id);

  }.bind(this));
};

/**
 * Retrieve a task by its identifier.
 * ----------------------------------
 * @param {string} id
 * @return {Promise::Task}
 * @throws {RangeError}
 */
RethinkDriver.prototype.getById = function(id) {
  var query = this.r.table(TABLE).get(id);

  return this.db.run(query)

  .then(function(task) {

    if (!task) {
      throw new RangeError('TaskNotFound');
    }

    return task;

  });
};

module.exports  = RethinkDriver;
