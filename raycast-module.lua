local Modules = {
    FadeModule,
    CommandModule,
    RaytraceModule
}

local CommandModule = spawn(function()
    repeat print('> Loading CommandModule') task.wait() until game:IsLoaded()

    --> COMMAND MODULE <------------------------------------------------------------
    local CommandModule = { Prefix = '/', RegisteredCommands = {}, }
    
    --// Variables
    local Player = game.Players.LocalPlayer
    local Configuration = script.Parent.Parent:WaitForChild('Configuration')
    local ChatService = game:GetService('TextChatService')
    
    --// Functions
    local function overwrite(t1:{}, t2:{})
    	for i, v in pairs(t2) do
    		if type(v) == 'table' then
    			t1[i] = overwrite(t2[i] or {}, v)
    		else
    			t1[i] = v
    		end
    	end
    
    	return t1 or nil
    end
    
    function CommandModule:SetPrefix(newPrefix)
    	CommandModule.Prefix = newPrefix
    	print(`Prefix set to: {newPrefix}`)
    end
    
    function CommandModule:RegisterCommand(...)	
    	local Default = {
    		Name = '',
    		MaxArgs = 1,
    		MinArgs = 1,
    		Callback = function() 
    			warn("No callback set")
    		end
    	}
    	
    	local Data = overwrite(Default, ... or {})
    	
    	CommandModule.RegisteredCommands[Data.Name] = {
    		MaxArgs = Data.MaxArgs,
    		MinArgs = Data.MinArgs,
    		Running = false,
    		Callback = Data.Callback
    	}
    	
    	print(`> Registered CMD: {Data.Name}`)
    end
    
    ChatService.OnIncomingMessage = function(...)
    	local content = (...)['Text']
    	local args = content:split(' ')
    	
    	if args[1]:sub(1,1) == CommandModule.Prefix then else
    		return
    	end
    	
    	args[1] = args[1]:sub(2,99)
    
    	if CommandModule.RegisteredCommands[args[1]] then
    		local Command = CommandModule.RegisteredCommands[args[1]]
    		table.remove(args, 1)
    		
    		if (#args) > Command.MaxArgs then
    			warn("Too many args")
    			return nil
    		end
    		
    		if (#args) < Command.MinArgs then
    			warn(`Missing args: {tostring(math.abs((#args)-Command.MinArgs))}`)
    			return nil
    		end
    		
    		if Command.Running then else
    			Command.Running = true
    			Command.Callback(args)
    			spawn(function() task.wait(1)
    				Command.Running = false
    			end)
    			
    			return nil
    		end
    		
    		(...)['Text'] = ''
    		(...):Destroy()
    	end
    end
    
    print("> Loaded CommandModule")
    Modules.CommandModule = CommandModule
    return CommandModule
end

spawn(function()
    repeat print('> Loading FadeModule') task.wait() until game:IsLoaded()
    
    --> FADE MODULE <---------------------------------------------------------------
    local fadeModule = {}
    
    --// Dependencies
    local tweenService = game:GetService('TweenService')
    local Config = script.Parent.Parent:WaitForChild('Configuration')
    
    --// Return the value of the specified query from the config
    local function ImportFromConfig(Query : string)
    	if Config:FindFirstChild(Query) then
    		return Config:WaitForChild(Query).Value
    	end
    
    	return false
    end
    
    --// fade in function
    fadeModule.fadeIn = function(...)
    	local instance = ...
    	
    	if instance:IsA('PointLight') then else
    		return
    	end
    	
    	local tween = tweenService:Create(
    		instance, 
    		TweenInfo.new(
    			ImportFromConfig('Fade'),
    			Enum.EasingStyle.Quad, 
    			Enum.EasingDirection.InOut
    		), 
    		{ Brightness = ImportFromConfig('Brightness') }
    	)
    	
    	tween:Play()
    	tween.Completed:Wait()
    end
    
    --// fade out function
    fadeModule.fadeOut = function(...)
    	local instance = ...
    
    	if instance:IsA('PointLight') then else
    		return
    	end
    
    	local tween = tweenService:Create(
    		instance, 
    		TweenInfo.new(
    			ImportFromConfig('Fade'), 
    			Enum.EasingStyle.Quad, 
    			Enum.EasingDirection.InOut
    		), 
    		{ Brightness = 0 }
    	)
    
    	tween:Play()
    	tween.Completed:Wait()
    	instance.Parent:Destroy()
    end
    
    print("> Loaded FadeModule")
    Modules.FadeModule = fadeModule
    return fadeModule
end)

spawn(function()
    repeat print('> Loading RaytraceModule') task.wait() until game:IsLoaded()
    
    --> RAYTRACE MODULE <-----------------------------------------------------------
    local raytraceModule = {}
    local threads = {}
    
    --// Load fade module
    local FadeModule = require(script.Parent:WaitForChild('FadeModule'))
    local CommandModule = require(script.Parent:WaitForChild('CommandModule'))
    
    --// Load configuration
    local Config = script.Parent.Parent:WaitForChild('Configuration')
    local ProbesFolder
    
    --// Return the value of the specified query from the config
    local function ImportFromConfig(Query : string)
    	if Config:FindFirstChild(Query) then
    		return Config:WaitForChild(Query).Value
    	end
    
    	return false
    end
    
    --// Returns table that only contains children that are the class provided
    local function GetChildrenOfClass(Object : Instance, Class : string)
    	local Children = {}
    
    	for _, v in Object:GetChildren() do
    		if v:IsA(Class) then
    			table.insert(Children, v)
    		end
    	end
    
    	--// Return the children or false if it can't find anything
    	return Children or false
    end
    
    --// Find rayNodesFolder
    local function GetNodeFolder()
    	for _, folder in GetChildrenOfClass(workspace, 'Folder') do
    		if folder:GetAttributes()["rayNodesFolder"] then
    			return folder
    		end
    	end
    
    	--// Return false if it can't find anything
    	return nil
    end
    
    local function CreateNodeFolder()
    	local Folder = Instance.new('Folder', workspace)
    	Folder:SetAttribute("rayNodesFolder", '')
    	Folder.Name = 'rayNodesFolder'
    	
    	return Folder
    end
    
    --// Delay to let roblox fully load bc for some reason game:IsLoaded() is inaccurate
    task.wait(1)
    
    --// Draw rayNodes
    function raytraceModule:GetNodes()
    	local nodeFolder = GetNodeFolder()
    	
    	if nodeFolder then
    		return nodeFolder:GetChildren()
    	end
    	
    	return nil
    end
    
    function raytraceModule:ClearNodes()
    	local nodeFolder = GetNodeFolder()
    	
    	if nodeFolder then 
    		nodeFolder:Destroy() 
    	end
    end
    
    function raytraceModule:DrawNodes(drawVector : Vector3, nodeAmount : number)
    	local nodeFolder = GetNodeFolder()
    	local nodes = {}
    	
    	if not nodeFolder then
    		nodeFolder = CreateNodeFolder()
    	end
    	
    	for x = 1, nodeAmount do
    		for z = 1, nodeAmount do
    			local nodePart = Instance.new('Part', nodeFolder)
    			nodePart.Transparency = 0.5
    			nodePart.CanCollide = false
    			nodePart.CanQuery = false
    			nodePart.CanTouch = false
    			nodePart.Anchored = true
    			nodePart.Size = Vector3.new(0.5, 17.5, 0.5)
    			nodePart.Name = 'Node'
    			
    			local xOffset = (x - 1) * (nodePart.Size.X + 10)
    			local zOffset = (z - 1) * (nodePart.Size.Z + 10)
    			local yOffset = -17.5/2
    			
    			local gridPosition = Vector3.new(
    				xOffset, 
    				yOffset,
    				zOffset
    			)
    			
    			nodePart.Position = drawVector - gridPosition
    			table.insert(nodes, nodePart)
    		end
    	end
    	
    	return nodes
    end
    
    --// Stop rayCast
    function raytraceModule:StopRaycast()
    	for _, thread in pairs(threads) do
    		if type(thread) == 'thread' then
    			task.cancel(thread)
    		end
    	end
    	
    	threads = {}
    end
    
    --// Apply rayCast to all rayNodes
    function raytraceModule:StartRaycast()
    	local nodeCount = #GetNodeFolder():GetChildren()
    	local successCount = 0
    	
    	for index, rayPart in ipairs(GetNodeFolder():GetChildren()) do
    		--// Only filter through parts called rayPart
    		if rayPart.Name == 'Node' then
    
    			--// Create rayParts transparent, untouchable and un-indexable
    			rayPart.Transparency = 1
    			rayPart.CastShadow = false
    			rayPart.CanCollide = false
    			rayPart.CanTouch = false
    			rayPart.CanQuery = false
    
    			--// Create a new task for each ray casted
    			threads[index] = task.spawn(function()
    				local part = rayPart
    
    				--// Function to generate a random direction
    				local function getRandomDirection()
    					local randomX = math.random(ImportFromConfig('Density') - (ImportFromConfig('Density') * 2), ImportFromConfig('Density'))
    					local randomY = math.random(ImportFromConfig('Density') - (ImportFromConfig('Density') * 2), ImportFromConfig('Density'))
    					local randomZ = math.random(ImportFromConfig('Density') - (ImportFromConfig('Density') * 2), ImportFromConfig('Density'))
    
    					return Vector3.new(randomX, randomY, randomZ).Unit
    				end
    
    				--// Main loop
    				while task.wait() do
    					if ImportFromConfig('Enabled') then
    						--// Check if the probes folder exists, and if it doesn't, make it
    						if workspace:FindFirstChild('RayProbes') then
    							ProbesFolder = workspace:WaitForChild('RayProbes')
    						elseif not workspace:FindFirstChild('RayProbes') then
    							ProbesFolder = Instance.new('Folder', workspace)
    							ProbesFolder.Name = 'RayProbes'
    							ProbesFolder:AddTag('Probes')
    						end
    
    						--// Calculate the ray start and end positions
    						local rayOrigin = part.Position
    						local rayDirection = getRandomDirection() * ImportFromConfig('MaxRayDistance')
    
    						--// Create raycast
    						local hitPart, hitPosition = workspace:FindPartOnRay(
    							Ray.new(rayOrigin, rayDirection), 
    							GetNodeFolder()
    						)
    
    						--// Check for ray interferences
    						if hitPart and hitPart:IsA('BasePart') then 
    							pcall(function()
    
    								--// Create probe part
    								local probe = Instance.new('Part', ProbesFolder)
    								probe.Size = Vector3.new(0.1, 0.1, 0.1)
    								probe.Transparency = 1
    								probe.Position = hitPosition
    								probe.Color = hitPart.Color
    								probe.CanCollide = false
    								probe.CanTouch = false
    								probe.CanQuery = false
    								probe.Anchored = true
    
    								--// Debug mode
    								if ImportFromConfig('DebugMode') then
    									local beam = Instance.new('Beam', probe)
    									local att1 = Instance.new('Attachment', probe)
    									local att2 = Instance.new('Attachment', rayPart)
    
    									beam.Attachment0 = att1
    									beam.Attachment1 = att2
    									beam.Width0 = 0.01
    									beam.Width1 = 0.01
    									beam.LightEmission = 0
    									beam.LightInfluence = 0
    									beam.Transparency = NumberSequence.new({
    										NumberSequenceKeypoint.new(0, 0, 0),
    										NumberSequenceKeypoint.new(1, 1, 0)
    									})
    									beam.Color = ColorSequence.new({
    										ColorSequenceKeypoint.new(0, hitPart.Color),
    										ColorSequenceKeypoint.new(1, hitPart.Color)
    									})
    
    									probe.Transparency = 0.5
    								end
    
    								--// Create point light in probe
    								local light = Instance.new('PointLight', probe)
    								light.Range = ImportFromConfig('Range')
    								light.Brightness = 0
    								light.Shadows = true
    								light.Color = hitPart.Color
    
    								--// Spawn a new thread to fade the light in
    								task.spawn(function()
    									pcall(function()
    										FadeModule.fadeIn(light)
    									end)
    								end)
    
    								--// Spawn a new thread to fade the light out
    								task.spawn(function()
    									task.wait(ImportFromConfig('Delay'))
    									pcall(function()
    										FadeModule.fadeOut(light)
    									end)
    								end) 
    							end)
    						end 
    					end
    				end
    			end)
    		end
    		
    		successCount+=1
    	end
    	
    	warn(`> Applied Raycast to {successCount} / {nodeCount} nodes.`)
    	
    end
    
    print('> Loaded RaytraceModule')
    Modules.RaytraceModule = raytraceModule
    return raytraceModule
end)

return Modules
