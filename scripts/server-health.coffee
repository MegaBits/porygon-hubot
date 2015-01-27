# Description:
#   Recurring checks on various servers.

cron = require('node-crontab')

module.exports = (robot) ->
    checkup = (robot) ->
        # Checkup on Alakazam
        data = JSON.stringify({"uuid": uuid(), "event": "pingTest"})
        robot.http("http://alakazam-dev.elasticbeanstalk.com").post(data) (err, res, body) ->
            if res.statusCode isnt 200
                robot.messageRoom("dev", "❗️Alakazam hurt itself in confusion❗️")
            else
                robot.messageRoom("dev", "Alakazam is at full health.")
    checkupJob = cron.scheduleJob('* 12 * * *', checkup(robot))
            
uuid = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )