-------------------------------------------------------------------
--| Created By: UltraTheSensei
--| Updated On: 15/02/2023
-------------------------------------------------------------------
--| This service handles the general NPC System

-------------------------------------------------------------------
--Services
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local SERVER_SCRIPT_SERVICE = game:GetService("ServerScriptService")
local SERVER_STORAGE = game:GetService("ServerStorage")
local SERVER_SCRIPT_SERVICE = game:GetService("ServerScriptService")
local PLAYERS = game:GetService("Players")
local HTTP_SERVICE = game:GetService("HttpService")
local RUN_SERVICE = game:GetService("RunService")

------------------------------------------------------------------
--Events
local NPCService_Event = REPLICATED_STORAGE.Events.Others.NPCService
local Effects_Event = REPLICATED_STORAGE.Events.Others.Effects

------------------------------------------------------------------
--Modules
local Knit = require(REPLICATED_STORAGE.Packages.Knit)
local Trove = require(REPLICATED_STORAGE.Packages.Trove)
local Promise = require(REPLICATED_STORAGE.Packages.Promise)

local Cooldowns = require(SERVER_SCRIPT_SERVICE.Game.Components.Player.Cooldowns)
local SimplePath = require(script.SimplePath)
local ItemInfos = require(SERVER_SCRIPT_SERVICE.Game.Scripts.Combat.Throw.ItemInfos)
local RagdollMod = require(SERVER_SCRIPT_SERVICE.Game.Scripts.Ragdoll.Ragdoll)

local PlayerComponent = require(SERVER_SCRIPT_SERVICE.Game.Components.Player)

------------------------------------------------------------------
--Variables
local NPCTable = {}

------------------------------------------------------------------
--Main
local NPCService = Knit.CreateService {
	Name = "NPCService",
	Client = {}
}

function NPCService:CreateNPC(SpawnLocation: Vector3, Type: string, Name: string)
	local NPCService = Knit.GetService("NPCService")
	local UtilityService = Knit.GetService("UtilityService")
	
	local TypeFolder = SERVER_STORAGE.NPCs:FindFirstChild(Type)
	local NPCModel = TypeFolder:GetChildren()[math.random(1, #TypeFolder:GetChildren())]
	if Name then
		local NPCModel = TypeFolder:FindFirstChild(Name):Clone()
	end
	NPCModel = NPCModel:Clone()

	local NPCHum = NPCModel:FindFirstChild("Humanoid")
	local NPCHumanoidRP = NPCModel:FindFirstChild("HumanoidRootPart")
	
	NPCModel:SetAttribute("ID", HTTP_SERVICE:GenerateGUID(false))
	NPCTable[NPCModel] = {
		Target = nil,
		LastUsed = os.clock(),
		EquippedItem = "None",
		Combo = 1,
		Body = {
			LeftHand = 100,
			RightHand = 100,
			RightLeg = 100,
			LeftLeg = 100
		},
		_Trove = Trove.new(),
	}
	
	local Path = SimplePath.new(NPCModel)
	Path.Visualize = false
	
	Path.WaypointReached:Connect(function()
		if not workspace:GetAttribute("Start") then
			NPCService:_Idle(NPCModel, Path)
		else
			NPCService:_FollowClosestTarget(NPCModel, Path)
		end
	end)

	Path.Reached:Connect(function()
		if not workspace:GetAttribute("Start") then
			NPCService:_Idle(NPCModel, Path)
		else
			if NPCTable[NPCModel] ~= nil then
				if NPCTable[NPCModel].Target ~= nil then
					if (NPCTable[NPCModel].Target:GetPivot().Position - NPCHumanoidRP.Position).Magnitude <= 4 then
						NPCService:Attack(NPCModel)
					end
				end
			end
			NPCService:_FollowClosestTarget(NPCModel, Path)
		end
	end)

	Path.Blocked:Connect(function()
		if not workspace:GetAttribute("Start") then
			NPCService:_Idle(NPCModel, Path)
		else
			NPCService:_FollowClosestTarget(NPCModel, Path)
		end
	end)

	Path.Error:Connect(function()
		if not workspace:GetAttribute("Start") then
			NPCService:_Idle(NPCModel, Path)
		else
			NPCService:_FollowClosestTarget(NPCModel, Path)
		end
	end)
	
	task.spawn(function()
		NPCService:_Idle(NPCModel, Path)

		while true do
			if workspace:GetAttribute("Start") then
				break
			end
			task.wait()
		end

		NPCService:_FollowClosestTarget(NPCModel, Path)
	end)
	
	local OldHealth = NPCHum.Health
	NPCTable[NPCModel]._Trove:Add(NPCHum.HealthChanged:Connect(function(NewHealth)
		if NewHealth < OldHealth then
			if not workspace:GetAttribute("Start") then
				workspace:SetAttribute("Start", true)
			end
			
			local KillerID = NPCModel:GetAttribute("KillerID")
			if KillerID then
				local KillerPlayer = PLAYERS:GetPlayerByUserId(tonumber(KillerID) or -1)

				if KillerPlayer then
					if NPCTable[NPCModel].Target ~= KillerPlayer.Character then
						NPCTable[NPCModel].Target = KillerPlayer.Character
						NPCService:_FollowClosestTarget(NPCModel, Path)
					end
				else
					local KillerNPC = NPCService:FindNPCFromID(KillerID)
					
					if KillerNPC then
						if NPCTable[NPCModel].Target ~= KillerNPC then
							NPCTable[NPCModel].Target = KillerNPC
							NPCService:_FollowClosestTarget(NPCModel, Path)
						end
					end
				end
			end
		end
		
		OldHealth = NewHealth
	end))

	NPCTable[NPCModel]._Trove:Add(NPCHum.Died:Connect(function()
		--[[if Path.StatusType ~= nil then
			if Path.Status ~= Path.StatusType.Idle then
				Path:Stop()
			end
		end
		Path:Destroy()--]]
		
		RagdollMod.Bot(NPCModel, true)
		Effects_Event:FireAllClients("CreateDeadBody", NPCModel)

		local KillerID = NPCModel:GetAttribute("KillerID")
		if KillerID then
			local KillerPlayer = PLAYERS:GetPlayerByUserId(tonumber(KillerID) or -1)

			if KillerPlayer then
				local KillerOldKills = KillerPlayer:GetAttribute("Kills")
				KillerPlayer:SetAttribute("Kills", KillerOldKills + 1)
			end
		end
		
		NPCService:RemoveNPC(NPCModel)
	end))
	
	NPCHumanoidRP.Position = SpawnLocation
	NPCModel.Parent = workspace.Map.NPCs
	
	RagdollMod.Joints(NPCModel)
	--NPCTable[NPCModel]._Trove:AttachToInstance(NPCModel)
end

function NPCService:Attack(NPC: Model)
	local UtilityService = Knit.GetService("UtilityService")
	local NPCHum = NPC:FindFirstChild("Humanoid")

	if NPCHum then
		local EquippedItem = NPCTable[NPC].EquippedItem
		local Combo = NPCTable[NPC].Combo
		
		local CombatAnimFolder = REPLICATED_STORAGE.Animations.Combat
		local Anim = nil
		
		if EquippedItem == "None" then
			if os.clock() - NPCTable[NPC].LastUsed <= Cooldowns.Fists[Combo] then return end
			
			local ArmType = UtilityService:CurrentArm(Combo)
			Anim = CombatAnimFolder[ArmType .. "Punch"]
		else
			--Do rest later
		end
		NPCTable[NPC].LastUsed = os.clock()
		NPCService_Event:FireAllClients(NPCHum, EquippedItem, Combo)

		local ServerWaitTime = Anim:GetAttribute("ServerWaitTime")
		task.wait(ServerWaitTime)
		
		local OverlapParam = OverlapParams.new()
		OverlapParam.FilterType = Enum.RaycastFilterType.Blacklist
		OverlapParam.FilterDescendantsInstances = {NPC}
		
		local Hitbox = NPC:FindFirstChild("Hitbox")
		if Hitbox then
			local Hits = workspace:GetPartsInPart(Hitbox, OverlapParam)
			if Hits then
				local RandomPlayer = PLAYERS:GetPlayers()[math.random(1,#PLAYERS:GetPlayers())]
				local RandomPlayerComponent = PlayerComponent:FromInstance(RandomPlayer)
				local Found = {}
				
				for _,Hit in pairs(Hits) do
					if Hit then
						if Hit.Parent then
							local HitChar = Hit.Parent
							if HitChar:FindFirstChild("Humanoid") and table.find(Found, HitChar) == nil then
								table.insert(Found, HitChar)
								
								if HitChar:GetAttribute("ID") ~= nil then
									HitChar:SetAttribute("KillerID", NPC:GetAttribute("ID"))
								end

								local HitHum = HitChar.Humanoid
								local Damage = ItemInfos[EquippedItem].Normal
								HitHum:TakeDamage(Damage)
								Effects_Event:FireAllClients("Damage Indicator", {HitHum.Parent.HumanoidRootPart, Damage})

								RandomPlayerComponent:DoLimbDamage(HitChar, ItemInfos[EquippedItem].Limb, Hit)
								RandomPlayerComponent:DoBlood(HitChar, math.random(8,12), Hit)
							end
						end
					end
				end
				UtilityService:Clear(Found)
			end
		end
		
		if NPC ~= nil and NPCTable[NPC] ~= nil then
			NPCTable[NPC].Combo += 1
			if NPCTable[NPC].Combo > ItemInfos[EquippedItem].MaxCombo then
				NPCTable[NPC].Combo = 1
			end
		end
	end
end

function NPCService:_FollowClosestTarget(NPC: Model, Path)
	if NPCTable[NPC] == nil then return end
	if NPCTable[NPC].Target ~= nil then
		if NPCTable[NPC].Target:FindFirstChild("Humanoid") then
			if NPCTable[NPC].Target.Humanoid.Health <= 0 then
				NPCTable[NPC].Target = nil
			end
		else
			NPCTable[NPC].Target = nil
		end
	end

	local Char = NPCTable[NPC].Target
	if Char == nil then
		Char = Path.GetNearestCharacter(NPC:GetPivot().Position)
		repeat Char = Path.GetNearestCharacter(NPC:GetPivot().Position) task.wait() until Char ~= nil
	end

	if Char ~= nil and NPCTable[NPC] ~= nil then
		if Char:FindFirstChild("HumanoidRootPart") then
			local Goal = Char.HumanoidRootPart.Position + Vector3.new(math.random(-1,1), 0, math.random(-1,1))
			NPCTable[NPC].Target = Char

			Path:Run(Goal)
		end
	end
end

function NPCService:_Idle(NPC: Model, Path)
	if NPCTable[NPC] == nil then return end
	if NPCTable[NPC].Target ~= nil then
		if NPCTable[NPC].Target:FindFirstChild("Humanoid") then
			if NPCTable[NPC].Target.Humanoid.Health <= 0 then
				NPCTable[NPC].Target = nil
			end
		else
			NPCTable[NPC].Target = nil
		end
	end
	
	local NPCHumanoidRP = NPC:WaitForChild("HumanoidRootPart")
	if NPCHumanoidRP then
		local Goal = NPCHumanoidRP.Position + Vector3.new(math.random(-50,50), 0, math.random(-50,50))
		Path:Run(Goal)
	end
end

function NPCService:FindNPCFromID(ID)
	for NPC, _ in NPCTable do
		if NPC:GetAttribute("ID") == ID then
			return NPC
		end
	end
	return nil
end

function NPCService:GetNPCTable(NPC: Model)
	if NPCTable[NPC] then
		return NPCTable[NPC]
	end
	return nil
end

function NPCService:RemoveNPC(NPC: Model)
	NPCTable[NPC]._Trove:Clean()
	
	for Name,Thing in NPCTable[NPC] do
		if typeof(Thing) == "table" then
			for Name2,Thing2 in Thing do
				NPCTable[NPC][Name][Name2] = nil
			end
		end

		NPCTable[NPC][Name] = nil
	end
	NPCTable[NPC] = nil
	
	task.delay(.05, function()
		NPC:Destroy()
	end)
end

function NPCService:KnitInit()
	print("NPCService Initialised")
end

function NPCService:KnitStart()
	local NPCService = Knit.GetService("NPCService")
	
	local AnimLoaderDummy = REPLICATED_STORAGE.Animations.AnimLoaderDummy
	AnimLoaderDummy.Parent = workspace
	local Animator = AnimLoaderDummy:WaitForChild("Humanoid"):WaitForChild("Animator")
	
	for _,Anim in REPLICATED_STORAGE.Animations:GetDescendants() do
		if Anim:IsA("Animation") then
			local AnimTrack = Animator:LoadAnimation(Anim)
			
			Promise.defer(function(Resolve)
				if not AnimTrack.IsPlaying then
					AnimTrack:Play()
				end
				repeat task.wait() until AnimTrack.Length > 0
				
				if AnimTrack:GetTimeOfKeyframe("Hit") then
					Anim:SetAttribute("ServerWaitTime", AnimTrack:GetTimeOfKeyframe("Hit"))
					AnimTrack:Destroy()
					
					Resolve()
				end
			end):timeout(5):catch(function()
				AnimTrack:Destroy()
			end)
		end
	end
	AnimLoaderDummy:Destroy()
--Testing
	for i = 1,3 do
		NPCService:CreateNPC(Vector3.new(38.629, 5.196, 160.671), "Normal")
	end
	
	for i = 1,3 do
		NPCService:CreateNPC(Vector3.new(39.417, 5.065, 156.495) + Vector3.new(math.random(-50,50), 0, math.random(-50,50)), "Normal")
	end
end

return NPCService
