# Pimatic RFXCom plugin
# Tim van de Vathorst
# https://github.com/Timvdv/pimatic-rfxcom

module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'

  #Create a class that extends the Plugin class
  # and implements the following functions
  class AugustConnectPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      deviceConfigDef = require("./device-config-schema")

      #init the different device types
      @framework.deviceManager.registerDeviceClass("AugustConnectDevice", {
        configDef: deviceConfigDef.AugustConnectDevice,

        createCallback: (config) =>
          new AugustConnectDevice(config)
      })

  plugin = new AugustConnectPlugin

  class AugustConnectDevice extends env.devices.Device
    attributes:
      status:
        description: "status of the door lock"
        type: "string"
        labels: ['locked', 'locking', 'unlocked', 'unlocking', 'unknown']
      battery:
        description: "how much battery the doorlock has"
        type: "number"
        unit: '%'

    actions:
      unlockDoor:
        description: "unlocks the door"
      lockDoor:
        description: "locks the door"
      toggleDoorLock:
        description: "opens or closes the door depending on the current status"
      changeStatusTo:
        description: "changes the door locked status"
        params:
          state:
            type: "string"

    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @_status = "unknown"

      super()

    unlockDoor: -> @changeStatusTo "unlocked"
    lockDoor: -> @changeStatusTo "locked"
    toggleDoorLock: -> if @getStatus() is 'locked' then @unlockDoor() else @lockDoor()

    _setStatust: (value) ->
      if @_status is value then return
      @_status = value
      @emit 'status', value

    getStatus: () -> Promise.resolve(@_status)

    destroy: () ->
      super()

  plugin.AugustConnectDevice = AugustConnectDevice

  class AugustConnectActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>
      # Try to match the input string with:
      M(input, context)
        .match('set mode of ')
        .matchDevice(thermostats, (next, d) =>
          next.match(' to ')
            .matchStringWithVars( (next, ts) =>
              m = next.match(' mode', optional: yes)
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              valueTokens = ts
              match = m.getFullMatch()
            )
        )

      if match?

        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new AugustConnectActionHandler(@framework, @client, statusTokens)
        }
      else
        return null

  plugin.AugustConnectActionProvider = AugustConnectActionProvider

  class AugustConnectActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @client, @statusTokens) ->
      assert @statusTokens?

    ###
    Handles the above actions.
    ###
    _doExecuteAction: (simulate, value) =>
      return (
        if simulate
          __("would set mode %s to %s%%", @device.name, value)
        else
          @device.changeModeTo(value).then( => __("set mode %s to %s%%", @device.name, value) )
      )

    # ### executeAction()
    executeAction: (simulate) =>
      @framework.variableManager.evaluateStringExpression(@valueTokens).then( (value) =>
        @lastValue = value
        return @_doExecuteAction(simulate, value)
      )

    # ### hasRestoreAction()
    # hasRestoreAction: -> yes
    # # ### executeRestoreAction()
    # executeRestoreAction: (simulate) => Promise.resolve(@_doExecuteAction(simulate, @lastValue))

  plugin.AugustConnectActionHandler = AugustConnectActionHandler

  return plugin
