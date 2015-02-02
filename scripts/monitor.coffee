# Description:
#   Recurring checks on various servers.

# Imports
cron = require('node-crontab')

# Global Variables
monitorJobs = {}

module.exports = (robot) ->
    robot.hear /(start|stop) monitoring (.*)/i, (msg) ->  
        serverName = msg.match[2].toLowerCase().trim()
        start = (msg.match[1] == "start")
        
        if start
            startMonitoring(serverName, msg)
        else
            stopMonitoring(serverName, msg)
          
    startMonitoring = (serverName, msg) ->
        if !(serverName of monitorEndpoints)
            msg.send("I'm not sure how to monitor #{serverName}.")
            return
    
        if serverName of monitorJobs
            msg.send("I'm already monitoring #{serverName}.")
            return
        
        job = cron.scheduleJob "* 12 * * *",  ->
            monitor(serverName, msg)
        monitorJobs[serverName] = job
        msg.send("Ok, I'll start monitoring #{serverName}.")
        
        monitor(serverName, msg)
    
    stopMonitoring = (serverName, msg) ->
        if !(serverName of monitorJobs)
            msg.send("I'm not monitoring #{serverName}.")
            return
    
        cron.cancelJob(monitorJobs[serverName])
        delete monitorJobs[serverName]
        
        msg.send("Ok, I'll stop monitoring #{serverName}.")

    monitor = (serverName, msg) ->
        endpoint = monitorEndpoints[serverName]
        msg.send("Checking on #{serverName}.")
        
        responseHandler = (err, res, body) ->
            if res.statusCode isnt 200
                msg.send("❗️ #{serverName} hurt itself in confusion ❗️")
            else
                msg.send("#{serverName} is at full health.")
        
        switch endpoint.method
            when "GET"
                msg.http(endpoint.url).get() responseHandler
            when "POST"
                msg.http(endpoint.url).post(endpoint.data) responseHandler

       
# Global Functions     
uuid = ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )
  
monitorEndpoints = {
    "alakazam": {
        "url": "http://alakazam.gameserver.megabitsapp.com",
        "method": "POST",
        "data": JSON.stringify({"uuid": uuid(), "event": "pingTest"})
    },
    
    "exeggcute": {
        "url": "http://exeggcute.gameserver.megabitsapp.com/user?q=megabits&client=2B604E7C6A0946BAB69E741BC177F961",
        "method": "GET"
    }
}