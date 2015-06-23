var bluebird              = require('bluebird');
var inherits              = require('util').inherits;
var EventEmitter          = require('events').EventEmitter;

function RethinkDriver(options) {

}

inherits(RethinkDriver, EventEmitter);

/**
 * Search through the stored tasks to find any ready to proces tasks.
 * ------------------------------------------------------------------
 * @param {int} delay - number of milliseconds
 */
RethinkDriver.prototype.findReady = function(delay) {

};

/**
 * Store the given task object.
 * ----------------------------
 * @param {Task} task
 * @return {Promise::Task}
 * @throws {TypeError}
 */
RethinkDriver.prototype.create  = function(task) {

};

/**
 * Replace the stored task object with the given task object.
 * ----------------------------------------------------------
 * @param {Task} task
 * @return {Promise::Task}
 * @throws {TypeError}
 */
RethinkDriver.prototype.update  = function(task) {

};

/**
 * Retrieve a task by its identifier.
 * ----------------------------------
 * @param {string} id
 * @return {Promise::Task}
 * @throws {RangeError}
 */
RethinkDriver.prototype.getById = function(id) {

};

module.exports  = RethinkDriver;
