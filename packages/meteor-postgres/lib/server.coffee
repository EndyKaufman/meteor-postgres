pg = Npm.require('pg')
clientHolder = {}

removeListeningConnections = ->
  for key of clientHolder
    clientHolder[key].end()
  return

process.on 'exit', removeListeningConnections

_.each ['SIGINT', 'SIGHUP', 'SIGTERM'], (sig) ->
  process.once sig, ->
    removeListeningConnections()
    process.kill process.pid, sig

###*
# @param Collection
# @constructor
###

SQL.Server = (Collection) ->
  Collection = Collection or Object.create SQL.Server::
  Collection.table = Collection.tableName
  Collection.conString = process.env.MP_POSTGRES or process.env.DATABASE_URL

  SQL.Server::clearAll()
  Collection


# Load all the shared SQL methods
_.extend SQL.Server::, SQL.Sql::

###*
# SQL: CREATE TABLE field data_type constraint
# Notes: Required for all SQL Collections, must use prescribed data types and table constraints
# Type: Query
# @param tableObj
###

SQL.Server::createTable = (tableObj) ->
  if arguments.length >= 2 
    defaultData = arguments[1]
  else 
    defaultData = []
  if arguments.length >= 3 
    callback = arguments[3] 
  else 
    callback = ->
  $this = this
  if arguments.length > 0
    @fetch "select count(1) from #{@table}", [], Meteor.bindEnvironment((error, result) ->
      if error != undefined or result.rows[0].count == 0
        if error != undefined
          ##
          startString = "CREATE TABLE IF NOT EXISTS \"#{$this.table}\" ("
          item = undefined
          subKey = undefined
          valOperator = undefined
          inputString = ''

          for key of tableObj
            inputString += " #{key} "
            inputString += $this._DataTypes[tableObj[key][0]]
            if _.isArray(tableObj[key]) && tableObj[key].length > 1
              for i in [1..(tableObj[key].length-1)]
                item = tableObj[key][i]
                if _.isObject(item)
                  subKey = Object.keys item
                  valOperator = $this._TableConstraints[subKey]
                  inputString += " #{valOperator}#{item[subKey]}"
                else
                  inputString += " #{$this._TableConstraints[item]}"
            inputString += ', '

          startString += 'id varchar(255) primary key,' if inputString.indexOf(' id') is -1

          watchTrigger = 'watched_table_trigger'
          $this.inputString = """
            #{startString}#{inputString} created_at TIMESTAMP default now());

            CREATE OR REPLACE FUNCTION notify_trigger_#{$this.table}() RETURNS trigger AS $$
            BEGIN
              IF (TG_OP = 'DELETE') THEN
                PERFORM pg_notify('notify_trigger_#{$this.table}', '[{"' || TG_TABLE_NAME || '":"' || OLD.id || '"}, { "operation": "' || TG_OP || '"}]');
                RETURN old;
              ELSIF (TG_OP = 'INSERT') THEN
                PERFORM pg_notify('notify_trigger_#{$this.table}', '[{"' || TG_TABLE_NAME || '":"' || NEW.id || '"}, { "operation": "' || TG_OP || '"}]');
                RETURN new;
              ELSIF (TG_OP = 'UPDATE') THEN
                PERFORM pg_notify('notify_trigger_#{$this.table}', '[{"' || TG_TABLE_NAME || '":"' || NEW.id || '"}, { "operation": "' || TG_OP || '"}]');
                RETURN new;
              END IF;
            END;
            $$ LANGUAGE plpgsql;
          """

          $this.prevFunc = 'CREATE TABLE'
          executeQuery = Meteor.wrapAsync($this.exec, $this)
          executeQuery $this.inputString, [], Meteor.bindEnvironment( (error, result) -> 
            if error != undefined and error != null
              console.log error
          )
          executeQuery "DROP TRIGGER IF EXISTS #{watchTrigger} ON #{$this.table};", []
          executeQuery "CREATE TRIGGER #{watchTrigger} AFTER INSERT OR DELETE OR UPDATE ON #{$this.table} FOR EACH ROW EXECUTE PROCEDURE notify_trigger_#{$this.table}();", []

          $this.clearAll()
          ##
          result = rows: [ { count: 0 } ]
        #fill table with default data
        if result.rows[0].count == 0 and defaultData.length > 0
          $this.select().fetch Meteor.bindEnvironment((error, result) ->
            if result.rowCount == 0
              i = 0
              while i < defaultData.length
                $this.insert(defaultData[i]).save()
                i++
              callback(true)
            return
          )
        else
          callback(true)
      else
        callback(false)
      return
    )
  return

###*
# Make a synchronous or asynchronous select on the table.
#
# This makes an synchronous call and returns the result. Otherwise throws and
# error
#   query.fetch()
#
# This makes an asynchronous call and runs the callback after the query has
# executed and returns (error, result)
#   query.fetch(function(error, result) { ... })
#
# This makes an asynchronous call but uses the provided input and data for the
# query
#   query.fetch('SOME QUERY', [data as array], function(error, result) { ... })
#
# Type: Data method
# @param {string} input
# @param {array} data
# @param {function} cb
###

SQL.Server::fetch = ->
  callback = _.last arguments
  input = if arguments.length >= 3 then arguments[0] else undefined
  data = if arguments.length >= 3 then arguments[1] else undefined

  data = @dataArray unless data
  unless input
    starter = @updateString or @deleteString or @selectString
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + @orderString + @limitString + @offsetString + @groupString + @havingString + ';'

  if arguments.length is 0
    executeQuery = Meteor.wrapAsync(@exec, @)
    result = executeQuery(input, data, callback)
    return result
  else
    @exec input, data, callback
  return

SQL.Server::pg = pg

SQL.Server::exec = (input, data, cb) ->
  pg.connect @conString, (err, client, done) ->
    if err and cb
      cb err, null
    console.log(err) if err
    try
      client.query input, data, (error, results) ->
        done()
        if cb
          cb error, results
    catch e
      cb e, null
  @clearAll()

###*
# Make a synchronous or asynchronous insert/update/delete on the table.
#
# This makes an synchronous call and returns the result. Otherwise throws and
# error
#   query.save()
#
# This makes an asynchronous call and runs the callback after the query has
# executed and returns (error, result)
#   query.save(function(error, result) { ... })
#
# This makes an asynchronous call but uses the provided input and data for the
# query
#   query.save('SOME QUERY', [data as array], function(error, result) { ... })
#
# Type: Data method
# @param {string} input
# @param {array} data
# @param {function} cb
###

SQL.Server::save = ->
  callback = _.last arguments
  input = if arguments.length >= 3 then arguments[0] else undefined
  data = if arguments.length >= 3 then arguments[1] else undefined

  data = @dataArray unless data
  unless input
    starter = @updateString or @deleteString or @selectString
    input = if @inputString.length > 0 then @inputString else starter + @joinString + @whereString + ';'

  if arguments.length is 0
    executeQuery = Meteor.wrapAsync(@exec, @)
    try
      result = executeQuery(input, data, callback)
      return result
    catch e
      console.error e.message
      return e
  else
    @exec input, data, callback
  return

###*
#
# @param sub
###

SQL.Server::autoSelect = (sub) ->
  # We need a dedicated client to watch for changes on each table. We store these clients in
  # our clientHolder and only create a new one if one does not already exist
  self = @
  table = @table
  strings = {}
  strings.select = strings.select or @selectString
  strings.join = strings.join or @joinString
  strings.prevFunc = @prevFunc

  @autoSelectInput = if @autoSelectInput != '' then @autoSelectInput else @selectString + @joinString + @whereString + @orderString + @limitString + ';'
  @autoSelectData = if @autoSelectData != '' then @autoSelectData else @dataArray

  value = @autoSelectInput
  data = @autoSelectData

  if sub != undefined
    @sub = sub
  else
    sub = @sub

  loadAutoSelectClient = (name, cb) ->
    # Function to load a new client, store it, and then send it to the function to add the watcher
    client = new pg.Client(process.env.MP_POSTGRES or process.env.DATABASE_URL)
    client.on 'notification', (msg) -> self._notificationsDDP(sub, strings, msg)
    client.connect()
    clientHolder[name] = client
    cb client

  autoSelectHelper = (client) ->
    # Selecting all from the table
    client.query value, data, (error, results) ->
      if error
        console.error "#{error.message} in autoSelect top"
      else
        sub._session.send
          msg: 'added'
          collection: sub._name
          id: sub._subscriptionId
          fields:
            reset: false
            results: results.rows
            value: value
            data: data

    # Adding notification triggers
    if @sub == undefined
      query = client.query "LISTEN notify_trigger_#{table}"
      client.on 'notification', (msg) -> self._notificationsDDP(sub, strings, msg)

  # Checking to see if this table already has a dedicated client before adding the listener
  if clientHolder[table]
    autoSelectHelper clientHolder[table]
  else
    loadAutoSelectClient table, autoSelectHelper
  return

SQL.Server::_notificationsDDP = (sub, strings, msg) ->
  message = JSON.parse msg.payload
  k = sub._name
  if message[1].operation is 'DELETE'
    tableId = message[0][k]
    sub._session.send
      msg: 'changed'
      collection: sub._name
      id: sub._subscriptionId
      index: tableId
      fields:
        removed: true
        reset: false
        tableId: tableId

  else if message[1].operation is 'UPDATE'
    selectString = "#{strings.select + strings.join} WHERE #{@table}.id = '#{message[0][@table]}'"
    pg.connect process.env.MP_POSTGRES or process.env.DATABASE_URL, (err, clientSub, done) ->
      if err
        console.log(err, "in #{prevFunc} #{@table}")

      clientSub.query selectString, @autoSelectData, (error, results) ->
        if error
          console.error error.message, selectString
        else
          done()
          sub._session.send
            msg: 'changed'
            collection: sub._name
            id: sub._subscriptionId
            index: tableId
            fields:
              modified: true
              removed: false
              reset: false
              results: results.rows[0]

  else if message[1].operation is 'INSERT'
    selectString = "#{strings.select + strings.join} WHERE #{@table}.id = '#{message[0][@table]}'"
    pg.connect process.env.MP_POSTGRES or process.env.DATABASE_URL, (err, clientSub, done) ->
      if err
        console.log(err, "in #{prevFunc} #{@table}")

      clientSub.query selectString, @autoSelectData, (error, results) ->
        if error
          console.error error.message, selectString
        else
          done()
          ddpPayload =
            msg: 'changed'
            collection: sub._name
            id: sub._subscriptionId
            fields:
              removed: false
              reset: false
              results: results.rows[0]
          sub._session.send ddpPayload
