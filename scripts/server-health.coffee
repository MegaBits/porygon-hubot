# Description:
#   Recurring checks on various servers.

cron = require('node-crontab')

checkupJob = null

module.exports = (robot) ->
    robot.hear /start monitoring alakazam/i, (msg) ->        
        msg.send("Ok, I'll start monitoring Alakazam. (robot: #{typeof(robot)})")
        checkupJob = cron.scheduleJob '* */12 * * *',  ->
            checkup(robot)
        checkup(robot)
    
    robot.hear /stop monitoring alakazam/i, (msg) ->
        msg.send("Ok, I'll stop monitoring Alakazam.")
        cron.cancelJob(checkupJob)

    checkup = (aRobot) ->
        # Checkup on Alakazam
        aRobot.messageRoom("#dev", "Checking on Alakazam...")
        data = JSON.stringify({"uuid": uuid(), "event": "pingTest"})
        aRobot.http("http://alakazam-dev.elasticbeanstalk.com").post(data) (err, res, body) ->
            if res.statusCode isnt 200
                aRobot.messageRoom("#dev", "❗️Alakazam hurt itself in confusion❗️")
            else
                aRobot.messageRoom("#dev", "Alakazam is at full health.")
            
uuid = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )