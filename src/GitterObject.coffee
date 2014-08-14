EventEmitter2 = require('eventemitter2').EventEmitter2

# Base class for all Gitter objects
#
# @abstract
class GitterObject extends EventEmitter2

  @inspectArgs: (args) ->
    res = []
    for arg in args
      if arg and arg instanceof Array
        res.push "[object Array<#{ arg.length }><#{ GitterObject.inspectArgs([arg[0]]) }>]"
      else if arg and typeof(arg) is 'object' and not (arg instanceof GitterObject)
        if (cn = arg.constructor.toString().replace(/^function ([^\(]+)[^$]+$/, '$1')) is 'Object'
          res.push "[object Object<#{ (key for own key of arg).join ',' }>]"
        else
          res.push "[object #{ cn }]"
      else
        res.push "#{ arg }"
    res.join ', '

  # Log a message with a level
  #
  # @param {String} level Level of the message
  # @param {String} message The message to log
  # @param {String} context Some optional context
  @log: (level, message, context = "[#{ @className() }]") ->
    message = "[node-gitter2.#{ level }]#{ context } #{ message }"
    level = 'log' unless console[level]
    console[level] message

  # @property {Object<Object<GitterObject>>} Holds all known GitterObject and derived, indexed
  @_instances: {}

  # Factory method
  #
  # @param {GitterClient} client The client to be used
  # @param {Object} data Core data from `node-gitter`
  # @return {GitterObject} The unique `GitterObject` instance, created if necessary
  @factory: (client, data) ->
    cn = @className()
    throw new ReferenceError("#{ cn }.factory(): no id defined in given data: #{ data }") unless data?.id
    clk = if client then "#{ client }" else '-'
    @_instances[clk] ?= {}
    @_instances[clk][cn] ?= {}
    if (res = @_instances[clk][cn][data.id])
      updated = []
      for own key, val of data when typeof(val) in ['string', 'number'] or val.constructor is Date
        unless res[key] is val
          res[key] = val
          updated.push key
      if updated.length and (cl = @client()) instanceof require('./GitterClient')
        setTimeout (=>
          cl.emit "#{ cn }:update", res
          res.emit 'update', updated
        ), 1
    else
      res = @_instances[clk][cn][data.id] = new @(client, data)
    res

  # Get the class name as a string
  #
  # @return {String} Name of the class as string
  @className: ->
    @toString().replace(/^function ([^\(]+)[^$]+$/, '$1')

  # Find an object given a client and a class
  #
  # @param {GitterClient} client The client to use if any
  # @param {Function} Class The class of the object to find
  # @param {String} property The name of the property to look for
  # @param {*} value The value of the property to look for
  # @return {GitterObject} The corresponding object or `undefined` if no such object
  @findBy: (client, Class, property, value) ->
    clk = if client then "#{ client }" else '-'
    index = @_instances[clk]?[Class.className()] ? {}
    for own k, object of index
      if (v = object[property]) and typeof(v) is 'function' and object[property]() is value
        return object
      else if v is value
        return object
    undefined

  # @property {Object} Holds the core data of that object
  _data: null

  # @property {GitterClient} The client to be used with this object
  _client: null

  # @property {Object<Promise>} Store promises stuff not yet returned
  _promises: null

  # Construct a new GitterObject instance
  #
  # @param {Object} _data The core data of that gitter object
  # @option _data {String} id The id of that object
  constructor: (@_client, @_data) ->
    throw new ReferenceError("no id given to create an object: #{ GitterObject.inspectArgs arguments }") unless _data?.id
    # initialize our event emitter
    super {wildcard: yes, maxListeners: Infinity}
    @_promises = {}
    self = @
    @on '*', ->
      self.log "{event}{#{ @event }} #{ GitterObject.inspectArgs arguments }"
      return
    # be sure this will run async, after any other constructor code
    setTimeout (=> cl.emit "#{ @className() }:new", @), 1 if (cl = @client()) instanceof require('./GitterClient')
    @log "created"

  # Get the ID of that object
  #
  # @return {String} The object's ID
  id: ->
    @_data.id

  # Get the client of that object
  #
  # @return {GitterClient} The object's client
  client: ->
    @_client

  # Get the object's class name
  #
  # @return {String} The name of the class of this object
  className: ->
    @constructor.toString().replace(/^function ([^\(]+)[^$]+$/, '$1')

  # Log a message with a level
  #
  # @param {String} level Optional level which, if not specified, is `debug`
  # @param {String} message The message to log
  log: (level, message) ->
    args = Array::slice.apply arguments
    if arguments.length is 1
      args.unshift 'debug'
    args.push @
    @constructor.log args...

  # Get a pretty identifier that can identify the object
  #
  # @return {String} A text identifying the object
  prettyIdentifier: ->
    @id()

  # Returns the string representation of that Gitter object
  #
  # @return {String} String representation of that object
  toString: ->
    "[object #{ @className() }<#{ @prettyIdentifier() }>]"

  # Get the promise of something loading, creating it if it does not exists
  #
  # @param {String} key Identifier of that promise
  # @param {Function} create Method used to create and return the promise
  # @return {Promise} The created or running promise
  _promise: (key, create) ->
    unless (p = @_promises[key])
      @log "creating promise `#{ key }`"
      p = @_promises[key] = create()
      setTimeout (=>
        p.finally =>
          @log "destroying promise `#{ key }`"
          delete @_promises[key]
          return
      ), 1
    p



module.exports = GitterObject
