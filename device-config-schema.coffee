module.exports = {
  title: "pimatic-august-connect device config schemas"
  MqttSwitch: {
    title: "AugustConnectDevice config options"
    type: "object"
    properties:
      username:
        description: "The August Connect Username"
        type: "string"
        default: ""
      password:
        description: "The August Connect Password"
        type: "string"
        default: ""
  }
}
