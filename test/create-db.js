var Pool  = require('../lib/db.js');

before(function(done) {
  var dbName        = rethinkConfig.db
  var db            = Pool(rethinkConfig);
  var hasTestDb     = db.r.dbList().contains(dbName);
  var createTestDb  = db.r.dbCreate(dbName);

  db.run(hasTestDb)

  .then(function(hasDb) {

    if (!hasDb) {

      return db.run(createTestDb).then(done.bind(null, null));

    }

    return done();

  });
});
