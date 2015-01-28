# Description:
#   Recurring checks on various servers.

cron = require('node-crontab')

checkupJob = null
checkupRobot = null

module.exports = (robot) ->
    robot.hear /start monitoring alakazam/i, (msg) ->
        checkupRobot = robot
        
        msg.send("Ok, I'll start monitoring Alakazam.")
        checkupJob = cron.scheduleJob('* */12 * * *', checkup)
        checkup()
    
    robot.hear /stop monitoring alakazam/i, (msg) ->
        checkupRobot = null
        
        msg.send("Ok, I'll stop monitoring Alakazam.")
        cron.cancelJob(checkupJob)

    checkup = () ->
        # Checkup on Alakazam
        checkupRobot.messageRoom("#dev", "Checking on Alakazam...")
        data = JSON.stringify({"uuid": uuid(), "event": "pingTest"})
        checkupRobot.http("http://alakazam-dev.elasticbeanstalk.com").post(data) (err, res, body) ->
            if res.statusCode isnt 200
                checkupRobot.messageRoom("#dev", "❗️Alakazam hurt itself in confusion❗️")
            else
                checkupRobot.messageRoom("#dev", "Alakazam is at full health.")
            
uuid = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )