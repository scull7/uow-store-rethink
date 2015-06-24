require '../create-db.js'

R             = require 'ramda'
bluebird      = require 'bluebird'
Driver        = require '../../lib/driver.js'

describe 'Rethink Driver', ->
  driver      = null

  beforeEach ->
    config    = R.merge rethinkConfig,
      runTaskSearch       : false

    driver    = new Driver(config)

    return driver.db.run(driver.r.table('uow_task').delete())

    .then ->

      t1  = driver.create
        id        : 'ready-1'
        status    : 'ready'
        semaphore : null

      t2  = driver.create
        id        : 'not-ready-1'
        status    : 'not-ready'

      t3  = driver.create
        id        : 'not-ready-2'
        status    : 'other'

      t4  = driver.create
        id        : 'ready-2'
        status    : 'ready'

      t5  = driver.create
        id        : 'locked-1'
        status    : 'ready'
        semaphore : true

      return bluebird.join(t1, t2, t3, t4)

      .catch RangeError, (e) ->
        console.log 'CAUGHT RANGE ERROR: ', e

  describe '::findReady', ->

    it 'should be a function with an arity of one', ->
      expect(driver.findReady).to.be.a 'function'
      expect(driver.findReady.length).to.eql 1

    it 'should emit ready events for all of the ready tasks', (done) ->
      readyTasks  = []

      driver.on 'task::ready', (task) ->
        readyTasks.push(task.id)

        if readyTasks.length > 1

          setTimeout ->
            expect(readyTasks.length).to.eql 2
            expect(readyTasks.indexOf('not-ready-1')).to.eql -1
            expect(readyTasks.indexOf('not-ready-2')).to.eql -1
            done()
          , 5

      driver.findReady()

    describe 'Ready Task Search Loop', ->
      driver2     = null

      beforeEach ->
        @clock  = sinon.useFakeTimers()
        driver2 = new Driver(R.merge(rethinkConfig, { runTaskSearch : true }))

      afterEach -> @clock.restore

      it 'should run every 500 ms when initialized to do so', (done) ->

        tick        = @clock.tick.bind(@clock)
        readyTasks  = []

        driver2.on 'task::ready', (task) ->
          readyTasks.push task
          if readyTasks.length > 1

            setTimeout ->
              expect(readyTasks.length).to.eql 2
              expect(readyTasks.indexOf('not-ready-1')).to.eql -1
              expect(readyTasks.indexOf('not-ready-2')).to.eql -1
              driver2.runTaskSearch = false
              done()
            , 5

          tick(10)

        tick(501)

  describe '::create', ->

    it 'should be a function with an arity of one', ->
      expect(driver.create).to.be.a 'function'
      expect(driver.create.length).to.eql 1

    it 'should throw a TypeError if the given task doesn\'t have an ID', ->

      task  =
        name  : 'no-id-for-me'

      driver.create task

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'TaskIdNotPresent'

    it 'should throw a TypeError if a task ID already exists', ->

      task  =
        id    : 'not-ready-1'
        name  : 'i-already-exist'

      driver.create task

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'TaskIdExists'

    it 'should return a task object', ->

      driver.create
        id        : 'fancy-task-id'
        name      : 'fancy-new-task'
        data      :
          foo     : 'bar'

      .then (task) ->
        expect(task.id).to.eql 'fancy-task-id'
        expect(task.name).to.eql 'fancy-new-task'
        expect(task.data.foo).to.eql 'bar'

  describe '::update', ->

    it 'should be a function with an arity of one', ->
      expect(driver.update).to.be.a 'function'
      expect(driver.update.length).to.eql 1

    it 'should throw a TypeError if the given task doesn\'t have an ID', ->

      task  =
        name  : 'no-id-for-me'

      driver.update task

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'TaskIdNotPresent'

    it 'should throw a range error if the task ID doesn\'t exist', ->

      task  =
        id    : 'i-do-not-exist'
        name  : 'does-not-matter'

      driver.update task

      .then -> throw new Error('UnexpectedSuccess')

      .catch RangeError, (e) -> expect(e.message).to.eql 'TaskNotFound'

    it 'should allow a partial update', ->

      t3  =
        id        : 'not-ready-2'
        semaphore : true

      driver.update t3

      .then (task) ->
        expect(task.id).to.eql 'not-ready-2'
        expect(task.status).to.eql 'other'
        expect(task.semaphore).to.be.true

  describe '::getById', ->

    beforeEach ->

    it 'should be a function with an arity of one', ->
      expect(driver.getById).to.be.a 'function'
      expect(driver.getById.length).to.eql 1

    it 'should throw a RangeError when a task is not found.', ->

      driver.getById('does-not-exist')

      .then -> throw new Error('UnexpectedSuccess')

      .catch RangeError, (e) -> expect(e.message).to.eql 'TaskNotFound'

    it 'should return a task', ->

      p1  = driver.getById('ready-1')
      p2  = driver.getById('locked-1')

      return bluebird.join(p1, p2)

      .spread (t1, t2) ->

        expect(t1.id).to.eql 'ready-1'
        expect(t1.semaphore).to.eql null
        expect(t1.status).to.eql 'ready'

        expect(t2.id).to.eql 'locked-1'
        expect(t2.semaphore).to.be.true
        expect(t2.status).to.eql 'ready'
