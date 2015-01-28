# Description:
#   Recurring checks on various servers.

cron = require('node-crontab')

module.exports = (robot) ->
    checkup = () ->
        # Checkup on Alakazam
        _robot.messageRoom("#dev", "Checking on Alakazam...")
        data = JSON.stringify({"uuid": uuid(), "event": "pingTest"})
        _robot.http("http://alakazam-dev.elasticbeanstalk.com").post(data) (err, res, body) ->
            if res.statusCode isnt 200
                _robot.messageRoom("#dev", "❗️Alakazam hurt itself in confusion❗️")
            else
                _robot.messageRoom("#dev", "Alakazam is at full health.")
                
    # "main"
    _robot = robot
    checkupJob = cron.scheduleJob('* */12 * * *', checkup)
    checkup()
            
uuid = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )