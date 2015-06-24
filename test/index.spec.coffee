
LibStore    = require 'uow-store'
Store       = require '../index.js'

describe 'RethinkDB Store', ->
  store = null

  beforeEach -> store = Store(rethinkConfig)

  it 'should return a store object', ->
    expect(store).to.be.an.instanceOf LibStore
