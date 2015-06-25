crypto        = require 'crypto'
bluebird      = require 'bluebird'
DB            = require '../lib/db.js'
LibStore      = require 'uow-store'
Store         = require '../index.js'
{ LockError } = LibStore
#LockError     = LibStore.LockError

describe 'RethinkDB Store', ->
  db    = null
  store = null

  before ->
    db  = DB(rethinkConfig)

    return db.install()

  beforeEach ->
    store = Store(rethinkConfig)

    return db.run(db.r.table('uow_task').delete())

  it 'should return a store object', ->
    expect(store).to.be.an.instanceOf LibStore

  describe '::handleReadyTask', ->
    eStore  = null

    beforeEach ->
      eStore  = Store(rethinkConfig)

    it 'should emit a ready event', (done) ->
      task    =
        name    : 'i-am-ready'
        status  : 'ready'

      eStore.on 'ready', (ready_task) ->
        expect(ready_task.name).to.eql 'i-am-ready'
        expect(ready_task.id).to.eql task.id

        done()

      store.createTask task

      .then (task) -> eStore.handleReadyTask(task.id)

    it 'should not emit an event for a locked task', (done) ->

      eStore.on 'ready', (ready_task) ->
        expect(ready_task.name).to.eql 'i-am-ready'

        setTimeout done, 10

      task    =
        name    : 'i-am-ready'
        status  : 'ready'

      locked  =
        name    : 'i-am-locked'
        status  : 'ready'

      p1  = eStore.createTask locked
          .then (task) -> eStore.lockTask('my-worker-id', task.id)
      p2  = eStore.createTask task

      bluebird.join p1, p2

      .spread (lockedTask, readyTask) ->
        eStore.handleReadyTask(lockedTask.id)
        eStore.handleReadyTask(readyTask.id)

    it 'should not emit an event for a delayed task', (done) ->

      eStore.on 'ready', (ready_task) ->
        expect(ready_task.name).to.eql 'i-am-ready'
        setTimeout done, 10

      task    =
        name    : 'i-am-ready'
        status  : 'ready'

      delayed =
        name    : 'i-am-delayed'
        status  : 'ready'
        after   : new Date().getTime()
        delay   : 1000

      p1  = eStore.createTask delayed
      p2  = eStore.createTask task

      bluebird.join p1, p2

      .spread (delayedTask, readyTask) ->
        eStore.handleReadyTask(delayedTask.id)
        eStore.handleReadyTask(readyTask.id)

    it 'should not emit an event for a future task', (done) ->

      eStore.on 'ready', (ready_task) ->
        expect(ready_task.name).to.eql 'i-am-ready'
        setTimeout done, 10

      task    =
        name    : 'i-am-ready'
        status  : 'ready'

      future =
        name    : 'i-am-future'
        status  : 'ready'
        after   : new Date().getTime() + 10000

      p1  = eStore.createTask future
      p2  = eStore.createTask task

      bluebird.join p1, p2

      .spread (futureTask, readyTask) ->
        eStore.handleReadyTask(futureTask.id)
        eStore.handleReadyTask(readyTask.id)

  describe '::createTask', ->

    it 'should be a function with an arity of one', ->
      expect(store.createTask).to.be.a 'function'
      expect(store.createTask.length).to.eql 1

    it 'should throw a TypeError if the task object has an ID', ->

      task  =
        id  : 'bad'

      store.createTask task

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'InvalidTaskObject'

    it 'should assign the task object a v4 UUID', ->

      task  =
        name  : 'create-task'

      store.createTask task

      .then (task) ->
        expect(task.id).to.be.a 'string'
        expect(task.id.length).to.eql 36

    it 'should call the pickle function if it\'s available', ->

      task  =
        name    : 'create-task'
        pickle  : ->
          id    : this.id
          name  : 'pickled-task'

      store.createTask task

      .then (task) ->
        expect(task.id).to.be.a 'string'
        expect(task.id.length).to.eql 36
        expect(task.name).to.eql 'pickled-task'

  describe '::updateTask', ->

    it 'should be a function with an arity of two', ->
      expect(store.updateTask).to.be.a 'function'
      expect(store.updateTask.length).to.eql 2

    it 'should throw a TypeError if the task doesn\'t have an ID', ->

      task  =
        name  : 'bad-update-task'

      store.updateTask 'my-worker-id', task

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'InvalidTaskObject'

    it 'should throw a LockError if a lock key doesnt match ' +
    ' the lock holder', ->

      task  =
        name  : 'bad-worker-id'

      store.createTask task

      .then (task) -> store.lockTask 'my-worker-id', task.id

      .then (task) ->

        task.updated  = 1

        store.updateTask 'my-other-id', task

      .then -> throw new Error('UnexpectedSuccess')

      .catch LockError, (e) -> expect(e.message).to.eql 'TaskLocked'

    it 'should update a locked task given the correct worker ID', ->

      task  =
        name  : 'locked-task-to-update'

      store.createTask task

      .then (task) -> store.lockTask 'my-worker-id', task.id

      .then (task) ->

        task.updated = 'success-for-locked-task'

        store.updateTask 'my-worker-id', task

      .then (task) ->

        expect(task.name).to.eql 'locked-task-to-update'
        expect(task.updated).to.eql 'success-for-locked-task'

  describe '::getTaskById', ->

    it 'should be a function with an arity of one', ->
      expect(store.getTaskById).to.be.a 'function'
      expect(store.getTaskById.length).to.eql 1

    it 'should throw a TypeError if a task ID is not provided.', ->

      store.getTaskById()

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'TaskIdNotProvided'

    it 'should return the saved task', ->

      task  =
        name  : 'task-to-get'

      store.createTask task

      .then (task) -> store.getTaskById(task.id)

      .then (task) ->
        expect(task.id).to.be.a 'string'
        expect(task.id.length).to.eql 36
        expect(task.name).to.eql 'task-to-get'

  describe '::lockTask', ->

    it 'should be a function with an arity of three', ->
      expect(store.lockTask).to.be.a 'function'
      expect(store.lockTask.length).to.eql 3

    it 'should throw a TypeError if the worker ID is not provided', ->

      store.lockTask()

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'WorkerIdNotProvided'

    it 'should throw a TypeError if the task ID is not provided', ->

      store.lockTask('my-worker-id')

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'TaskIdNotProvided'

    it 'should lock an unlocked task', ->
      hash  = crypto.createHash 'sha512'

      task  =
        name  : 'task-to-lock'

      expected_key  = null

      store.createTask task

      .then (task) ->

        hash.update 'my-worker-id'
        hash.update task.id

        expected_key  = hash.digest 'hex'

        store.lockTask 'my-worker-id', task.id

      .then (task) ->

        expect(task.name).to.eql 'task-to-lock'
        expect(task.semaphore.key).to.be.a 'string'
        expect(task.semaphore.key).to.eql expected_key

    it 'should throw a LockError if the task is already locked', ->
      task  =
        name  : 'task-check-lock'

      store.createTask task

      .then (task) -> store.lockTask 'my-worker-id', task.id

      .then (task) -> store.lockTask 'other-worker-id', task.id

      .then -> throw new Error('UnexpectedSuccess')

      .catch LockError, (e) -> expect(e.message).to.eql 'TaskAlreadyLocked'

  describe '::unlockTask', ->

    it 'should be a function with an arity of two', ->
      expect(store.unlockTask).to.be.a 'function'
      expect(store.unlockTask.length).to.eql 2


    it 'should throw a TypeError if the worker ID is not provided', ->

      store.unlockTask()

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'WorkerIdNotProvided'

    it 'should throw a TypeError if the task ID is not provided', ->

      store.unlockTask('my-worker-id')

      .then -> throw new Error('UnexpectedSuccess')

      .catch TypeError, (e) -> expect(e.message).to.eql 'TaskIdNotProvided'

    it 'should unlock a locked task', ->

      task  =
        name  : 'task-to-unlock'

      store.createTask task

      .then (task) -> store.lockTask 'my-worker-id', task.id

      .then (task) -> store.unlockTask 'my-worker-id', task.id

      .then (task) ->
        expect(task.semaphore).to.be.null

    it 'should throw a LockError if the worker ID is not the lock holder', ->

      task  =
        name  : 'task-to-unlock'

      store.createTask task

      .then (task) -> store.lockTask 'my-worker-id', task.id

      .then (task) -> store.unlockTask 'my-other-id', task.id

      .then -> throw new Error('UnexpectedSuccess')

      .catch LockError, (e) -> expect(e.message).to.eql 'KeyInvalid'
