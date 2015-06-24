(function(global) {
  'use strict';
  var TEST_DB           = 'test_uow_store_rethink';

  global.sinon          = require('sinon');
  global.chai           = require('chai');
  global.should         = require('chai').should();
  global.expect         = require('chai').expect;
  global.AssertionError = require('chai').AssertionError;

  global.swallow        = function(thrower) {
    try {
      thrower();
    } catch (e) {}
  };

  global.rethinkConfig  = {
    db: TEST_DB
  };

  var sinonChai         = require('sinon-chai');
  global.chai.use(sinonChai);

}(global));
