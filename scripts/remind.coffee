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

sugar = require('sugar')
fuzzy = require('fuzzy')

module.exports = (robot) ->
    
    # Task Properties
    weight = (task) ->
        time = 10 - Date.create().daysUntil(Date.create(task.due_date))
        priority = 10 * ((task.priority.match(/\*/g) || []).length / 5)
        return time + priority
        
    description = (task) ->
        dueDate = Date.create(task.due_date).format(", {MM}/{dd}/{yyyy}")
        return "#{task.task} for #{task.project} (#{task.priority}#{dueDate})"
        
    taskList = (tasks) ->
        """```
        [ ] #{(description(task) for task in tasks).join('\n[ ] ')}
        ```"""
        
    tasksForProjects = (projects) ->
        allTasks = []
        for projectName, project of projects
            projectTasks = project.sort (a, b) ->
                if weight(a) > weight(b) then -1 else if weight(a) < weight(b) then 1 else 0  
            for projectTask in projectTasks
                allTasks.push(projectTask)
        return allTasks
    
    # Task Observation
    # ... hubot what's next for me?
    robot.hear /what's next for ([^\?]*)(\??)/i, (msg) ->
        # Get user and projects
        username = msg.match[1].trim()
        user = robot.brain.usersForFuzzyName(username)[0]        
        if username == "me" or not user?
            user = msg.message.user
            
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        allTasks = tasksForProjects(projects)
        
        if allTasks.length > 0
            response = "#{user.name}: #{description(allTasks[0])}"
        else
            response = "Relax! There's nothing on #{user.name}'s list."
        msg.send(response)
    
    # ... hubot what's due for the party from me?
    robot.hear /what's due for (.*) from ([^\?]*)(\??)/i, (msg) ->
        # Get user and projects
        username = msg.match[2].trim()        
        user = robot.brain.usersForFuzzyName(username)[0]        
        if username == "me" or not user?
            user = msg.message.user
            
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        projectName = msg.match[1].toLowerCase().trim()
        
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
        # Get user and projects
        username = msg.match[3].trim()        
        user = robot.brain.usersForFuzzyName(username)[0]        
        if username == "me" or not user?
            user = msg.message.user
        
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        
        # Sort and filter
        allTasks = tasksForProjects(projects).filter (task) ->
            previousDate = Date.create(msg.match[2]).rewind({ days: 1 })
            nextDate = Date.create(msg.match[2]).advance({ days: 1 })
            
            dueDate = Date.create(task.due_date)
            switch msg.match[1]
                when "by"
                    if dueDate.isBefore(nextDate)
                        return true
                when "on"
                    if dueDate.isBetween(previousDate, nextDate)
                        return true
            return false  
        
        # Build response
        requestedDate = Date.create(msg.match[2]).format('{MM}/{dd}/{yyyy}')
        if allTasks.length > 0
            response = "The following tasks are due from #{user.name} #{msg.match[1]} #{requestedDate}\n#{taskList(allTasks)}"
        else
            response = "#{user.name} has no tasks due #{msg.match[1]} #{requestedDate}."
            
        msg.send(response)
    
    # Task Addition
    # ... hubot remind me to email Foo about the party by tomorrow ***
    robot.hear /remind (.*) to (.*) (for|about) (.*)  by (.*) (\*{1,5})/i, (msg) ->
        # Get user.
        username = msg.match[1].trim()        
        user = robot.brain.usersForFuzzyName(username)[0]        
        if username == "me" or not user?
            user = msg.message.user
        
        if not user?
            msg.send "I'm not sure who I should remind."
            return                    
                    
        # Get due date.
        time = msg.match[5]
        parsedDate = Date.create(time)
        if parsedDate.isValid() and parsedDate.isFuture()
            dueDate = parsedDate.format(", {MM}/{dd}/{yyyy}")
        else
            parsedDate = Date.future
            dueDate = ""
        
        # Get project
        projectName = msg.match[4].toLowerCase().trim()
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
                
                # ask for response FUCK
        project = []
        if projects[projectName]?
           project = projects[projectName]
        
        # Get priority and task
        priority = msg.match[6].rpad('-', 5)
        task = msg.match[2]
        
        # Add to project
        project.push(
            task: task,
            due_date: parsedDate,
            priority: priority,
            project: projectName
        )
        
        projects[projectName] = project
        
        robot.brain.set("remind/#{user.name}/projects", projects)
        msg.send(":thumbsup: #{user.name} should #{task} #{msg.match[3]} #{projectName} (#{priority}#{dueDate})")
        
    # Task Remove
    # ... hubot i finished emailing Foo
    robot.hear /(.*) finished (.*)/i, (msg) ->
        # Get user and projects
        username = msg.match[1].trim()        
        user = robot.brain.usersForFuzzyName(username)[0]        
        if username == "i" or not user?
            user = msg.message.user
        
        projects = robot.brain.get("remind/#{user.name}/projects") or {}
        allTasks = tasksForProjects(projects)
        
        # Sort and filter
        results = fuzzy.filter(msg.match[2], (task.task for task in allTasks)).map (i) ->
            i.string
        
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
        
    # ... hubot clear everything
    robot.hear /clear all tasks for (.*)/i, (msg) ->
        # Get user
        username = msg.match[1].trim()        
        user = robot.brain.usersForFuzzyName(username)[0]        
        if username == "me" or not user?
            user = msg.message.user
        
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