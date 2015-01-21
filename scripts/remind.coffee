# Description:
#   A task-management solution, bespoke for Porygon.
#
# Notes:
#   Task management should be easy, portable, and personal.
#   What better way than to converse with Hubot to plan your day?
#
# Technical: {
#   "{user}/projects": {
#      "{project}": [{
#          "task": "{task}",
#          "due_date": {due_date},
#          "priority": "{priority}",
#      }]
#   }
#
#   weight(task) = (10 - (due_date - time())) + (10 * (priorty / 5))
#
# Feature Requests:
#   *---- Calendar export / Google calendar integration

sugar = require('sugar')
fuzzy = require('fuzzy')
schedule = require('node-schedule')

module.exports = (robot) ->
    
    # Task Properties
    weight = (task) ->
        time = 10 - Date.create().daysUntil(Date.create(task.due_date))
        priority = 10 * ((task.priority.match(/\*/g) || []).length / 5)
        return time + priority
        
    description = (task) ->
        dueDate = Date.create(task.due_date).format("{MM}/{dd}/{yyyy}")
        return "#{task.priority} (#{dueDate}) #{task.task} for #{task.project}"
        
    taskList = (tasks) ->
        """```
        #{(description(task) for task in tasks).join('\n')}
        ```"""
        
    tasksForProjects = (projects) ->
        allTasks = []
        for projectName, project of projects
            for projectTask in project
                allTasks.push(projectTask)
                
        allTasks = allTasks.sort (a, b) ->
            if weight(a) > weight(b) then -1 else if weight(a) < weight(b) then 1 else 0  
        return allTasks
    
    # Task Observation
    # ... hubot what's next for me?
    robot.hear /what's next for ([^\?]*)(\??)/i, (msg) ->
        # Get user and projects
        username = msg.match[1].trim()
        user = robot.brain.usersForFuzzyName(username)[0] or user = msg.message.user
            
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        allTasks = tasksForProjects(projects)
        
        if allTasks.length > 0
            response = "#{user.name}: #{description(allTasks[0])}"
        else
            response = "Relax! There's nothing on #{user.name}'s list."
        msg.send(response)
        
    # ... hubot what tasks do i have?
    robot.hear /what tasks (do|does) (.*) have(\??)/i, (msg) ->
        # Get user and projects
        username = msg.match[2]
        user = robot.brain.usersForFuzzyName(username)[0] or user = msg.message.user
            
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        for projectName of projects
            projectTaskHandler(msg, user.name, projectName)
        
    
    # ... hubot what's due for the party from me?
    robot.hear /what's due for (.*) from ([^\?]*)(\??)/i, (msg) ->
        projectTaskHandler(msg, msg.match[2].trim(), msg.match[1].toLowerCase().trim())
    robot.hear /what's due from (.*) for ([^\?]*)(\??)/i, (msg) ->
        projectTaskHandler(msg, msg.match[1].trim(), msg.match[2].toLowerCase().trim())
        
    projectTaskHandler = (msg, username, projectName) ->
        # Get user and projects
        user = robot.brain.usersForFuzzyName(username)[0] or user = msg.message.user
            
        projects = robot.brain.get("remind/#{user.name}/projects") or {}        
        if not projectName of projects
            msg.send "I'm not sure which project you mean."
            return
        
        # Sort and filter
        results = fuzzy.filter(projectName, (project for project of projects)).map (i) ->
            i.string
            
        project = projects[results[0]] or []
        projectTasks = project.sort (a, b) ->
            if weight(a) > weight(b) then -1 else if weight(a) < weight(b) then 1 else 0
        
        # Build response
        requestedDate = Date.create(msg.match[2]).format('{MM}/{dd}/{yyyy}')
        if projectTasks.length > 0
            response = "The following tasks are due for #{results[0] or projectName}\n#{taskList(projectTasks)}"
        else
            response = "There are no tasks due for #{results[0] or projectName}."
            
        msg.send(response)
    
    # ... hubot what's due on Thursday from me?
    robot.hear /what's due (on|by) (.*) from ([^\?]*)(\??)/i, (msg) ->
        dueDateTaskHandler(msg,
            msg.match[3].trim(),
            msg.match[1].trim(),
            msg.match[2].trim())
    robot.hear /what's due from (.*) (on|by) ([^\?]*)(\??)/i, (msg) ->
        dueDateTaskHandler(msg,
            msg.match[1].trim(),
            msg.match[2].trim(),
            msg.match[3].trim())
    
    dueDateTaskHandler = (msg, username, heuristic, date) ->
        # Get user and projects
        user = robot.brain.usersForFuzzyName(username)[0] or user = msg.message.user
        
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        
        # Sort and filter
        allTasks = tasksForProjects(projects).filter (task) ->
            previousDate = Date.create(date).rewind({ days: 1 })
            nextDate = Date.create(date).advance({ days: 1 })
            
            dueDate = Date.create(task.due_date)
            switch heuristic
                when "by"
                    if dueDate.isBefore(nextDate)
                        return true
                when "on"
                    if dueDate.isBetween(previousDate, nextDate)
                        return true
            return false  
        
        # Build response
        requestedDate = Date.create(date).format('{MM}/{dd}/{yyyy}')
        if allTasks.length > 0
            response = "The following tasks are due from #{user.name} #{heuristic} #{requestedDate}\n#{taskList(allTasks)}"
        else
            response = "#{user.name} has no tasks due #{msg.match[1]} #{requestedDate}."
            
        msg.send(response)
    
    # Task Addition
    # ... hubot remind me to email Foo about the party by tomorrow ***
    robot.hear /remind (.*) to (.*) (for|about) (.*) by (.*) (\*{1,5})/i, (msg) ->
        newTaskHandler(msg,
            msg.match[1].trim(),
            msg.match[2].trim(),
            msg.match[3].trim(),
            msg.match[4].toLowerCase().trim(),
            msg.match[5].trim(),
            msg.match[6])
    robot.hear /remind (.*) to (.*) by (.*) (for|about) (.*) (\*{1,5})/i, (msg) ->
        newTaskHandler(msg,
            msg.match[1].trim(),
            msg.match[2].trim(),
            msg.match[4].trim(),
            msg.match[5].toLowerCase().trim(),
            msg.match[3].trim(),
            msg.match[6])
        
    newTaskHandler = (msg, username, task, heuristic, projectName, time, priority) ->
        # Get user.
        user = robot.brain.usersForFuzzyName(username)[0] or user = msg.message.user
        
        if not user?
            msg.send "I'm not sure who I should remind."
            return                    
                    
        # Get due date.
        parsedDate = Date.create(time)
        if parsedDate.isValid() and parsedDate.isFuture()
            dueDate = parsedDate.format(", {MM}/{dd}/{yyyy}")
        else
            parsedDate = Date.future
            dueDate = ""
        
        # Get project
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
                
        project = []
        if projects[projectName]?
           project = projects[projectName]
        
        # Get priority
        priority = priority.rpad('-', 5)
        
        # Add to project
        task =
            task: task
            due_date: parsedDate
            priority: priority
            project: projectName
            
        project.push(task)
        
        projects[projectName] = project
        
        robot.brain.set("remind/#{user.name}/projects", projects)
        msg.send(":thumbsup: #{user.name} should #{task} #{heuristic} #{projectName} (#{priority}#{dueDate})")
        
        schedule.scheduleJob(parsedDate, () ->
            msg.send(":alarm_clock: Reminder: #{description(task)}"))
        
    # Task Remove
    # ... hubot i finished emailing Foo
    robot.hear /(.*) finished (.*)(^project)/i, (msg) ->
        # Get user and projects
        username = msg.match[1].trim()        
        user = robot.brain.usersForFuzzyName(username)[0] or user = msg.message.user
        
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        allTasks = tasksForProjects(projects)
        
        # Sort and filter
        results = fuzzy.filter(msg.match[2], (task.task for task in allTasks)).map (i) ->
            i.string
        
        if results.length <= 0
            msg.send("I can't seem to find that task.")
            return
        
        projectName = (task.project for task in allTasks when task.task == results[0])
        project = []
        if projects[projectName]?
           project = projects[projectName]
        
        # Remove from project
        project = project.filter (task) ->
            task.task != results[0]
        projects[projectName] = project
        
        robot.brain.set("remind/#{user.name}/projects", projects)
        msg.send(":thumbsup: Nice! '#{results[0]}' is off the list.")
        
    # ... hubot i finished the party project
    robot.hear /(.*) finished (.*) project/i, (msg) ->
        projectRemovalHandler(msg,
            msg.match[1].trim(),
            msg.match[2].trim().toLowerCase())
    robot.hear /(.*) finished project (.*)/i, (msg) ->
        projectRemovalHandler(msg,
            msg.match[1].trim(),
            msg.match[2].trim().toLowerCase())
    
    projectRemovalHandler = (msg, username, projectName) ->
        # Get user and projects
        user = robot.brain.usersForFuzzyName(username)[0] or user = msg.message.user
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        
        # Sort and filter
        results = fuzzy.filter(projectName, (projectName for projectName of projects)).map (i) ->
            i.string
        
        if results.length <= 0
            msg.send("I can't seem to find that project.")
            return
        
        projectName = results[0]
        
        # Remove project
        delete projects[projectName]

        robot.brain.set("remind/#{user.name}/projects", projects)
        msg.send(":tada: Fantastic! '#{results[0]}' is off the list. :tada:")
        
    # ... hubot clear everything
    robot.hear /clear all tasks for (.*)/i, (msg) ->
        # Get user
        username = msg.match[1].trim()        
        user = robot.brain.usersForFuzzyName(username)[0] or msg.message.user
        
        if robot.brain.get("remind/clear") == user.name
            robot.brain.remove("remind/#{user.name}/projects")
            robot.brain.remove("remind/clear")
            msg.send("Ok. All tasks for #{user.name} have be cleared.")
        else
            robot.brain.set("remind/clear", user.name)
            msg.send(":emperoar: Are you sure I should delete all tasks? Send this command again so I can confirm.")
            
    # ... hubot cancel clear
    robot.hear /cancel clear/i, (msg) ->
        robot.brain.remove("remind/clear")
        msg.send(":relieved: Ok. I won't clear all tasks.")
        
        
# Misc. Functions
if (typeof String::lpad != 'function')
  String::lpad = (padString, length) ->
    str = this
    while str.length < length
      str = padString + str
    return str
    
if (typeof String::rpad != 'function')
  String::rpad = (padString, length) ->
    str = this
    while str.length < length
      str = str + padString
    return str