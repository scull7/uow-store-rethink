
Driver        = require '../../lib/driver.js'

describe 'Rethink Driver', ->
  driver      = null

  beforeEach ->
    driver    = new Driver()

  describe '::findReady', ->

    it 'should be a function with an arity of one', ->
      expect(driver.findReady).to.be.a 'function'
      expect(driver.findReady.length).to.eql 1

  describe '::create', ->

    it 'should be a function with an arity of one', ->
      expect(driver.create).to.be.a 'function'
      expect(driver.create.length).to.eql 1

  describe '::update', ->

    it 'should be a function with an arity of one', ->
      expect(driver.update).to.be.a 'function'
      expect(driver.update.length).to.eql 1

  describe '::getById', ->

    it 'should be a function with an arity of one', ->
      expect(driver.getById).to.be.a 'function'
      expect(driver.getById.length).to.eql 1
