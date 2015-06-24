require '../create-db.js'

rethinkdb = require 'rethinkdb'
DB        = require '../../lib/db.js'

describe 'Database Connector', ->
  db      = null

  before  (done) ->
    testDb  = DB(rethinkConfig)

    testDb.clean()
    .then -> testDb.install()
    .then -> done()

  beforeEach -> db  = DB(rethinkConfig)

  it 'should throw a type error if a config object is not given', ->
    test  = -> DB()
    expect(test).to.throw TypeError, /DatabaseNotSpecified/

  it 'should throw a TypeError if an empty config object is given', ->
    test  = -> DB {}
    expect(test).to.throw TypeError, /DatabaseNotSpecified/

  it 'should throw a TypeError if a database is not specified', ->
    test  = -> DB({ authKey: 'something' })
    expect(test).to.throw TypeError, /DatabaseNotSpecified/

  it 'should provide access to the rethinkdb query object', ->
    r = db.r
    expect(r).to.eql rethinkdb

  it 'should override the db setting with the database setting', (done) ->
    tdb = DB
      db      : 'not_this'
      database: 'use_this'

    tdb.acquire (err, conn) ->
      if err then return done(err)
      expect(conn.db).to.eql 'use_this'
      done()

  it 'should override the authKey setting with the password setting', (done) ->
    tdb = DB
      db      : 'use_this'
      authKey : 'not-this'
      password: ''

    tdb.acquire (err, conn) ->
      if err then return done(err)
      expect(conn.authKey).to.eql ''
      done()

  it 'should return a configured connection pool', (done) ->
    db.acquire (err, conn) ->
      if err then return done(err)

      db.r.db('test_uow_store_rethink').info().run conn, (err, cursor) ->
        if err then return done(err)

        expect(err).to.be.null
        expect(cursor.type).to.eql 'DB'
        expect(cursor.name).to.eql 'test_uow_store_rethink'
        done()

  describe '::install', ->

    it 'should create the task table if it doesn\'t exist', (done) ->

      db.clean()

      .then -> db.clean()

      .then -> db.install()

      .then ->
        query = db.r.tableList().contains('uow_task')
        db.run(query)

      .then (exists) ->
        expect(exists).to.be.true
        done()

    it 'should be idempotent', (done) ->

      insert  = db.r.table('uow_task').insert( id: 'this-is-me' )

      db.run(insert)

      .then -> db.install()

      .then ->
        select = db.r.table('uow_task').get('this-is-me')
        db.run(select)

      .then (results) ->
        expect(results.id).to.eql 'this-is-me'

        del = db.r.table('uow_task').get('this-is-me').delete()
        db.run(del)

      .then -> done()

      .catch done
