-------------------------------------------------------------------
--| Created By: Me
--| Updated On: 27/01/23
-------------------------------------------------------------------
--| This service handles the general NPC System

-------------------------------------------------------------------
--Services
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local SERVER_STORAGE = game:GetService("ServerStorage")
local SERVER_SCRIPT_SERVICE = game:GetService("ServerScriptService")
local PLAYERS = game:GetService("Players")
local HTTPService = game:GetService("HttpService")

------------------------------------------------------------------
--Modules
local Knit = require(REPLICATED_STORAGE.Packages.Knit)
local Trove = require(REPLICATED_STORAGE.Packages.Trove)
local Promise = require(REPLICATED_STORAGE.Packages.Promise)
--local Comm = require(REPLICATED_STORAGE.Packages.Comm)

------------------------------------------------------------------
--Variables
local ServerComm = Comm.ServerComm.new(REPLICATED_STORAGE, "DATA_COMMUNICATION")

local NPCTable = {}

------------------------------------------------------------------
--Main
local NPCService = Knit.CreateService {
	Name = "NPCService",
	Client = {}
}

function NPCService:CreateNPC(SpawnLocation: Vector3, Type: string, Name: string)
    local TypeFolder = SERVER_STORAGE.NPCs:FindFirstChild(Type)
    local NPCModel = TypeFolder[math.random(1, #TypeFolder:GetChildren())]
    if Name then
        local NPCModel = TypeFolder:FindFirsttChild(Name)
    end

    local NPCHum = NPCModel:FindFirstChild("Humanoid")
    local NPCHumanoidRP = NPCModel:FindFirstChild("HumanoidRootPart")

    Trove:Add(task.spawn(function()
        while true do
            if NPCTable[NPC] ~= nil then
                local ClosestInfo = {}

                for _,Player in Players:GetPlayers() do
                    if ClosestInfo == nil then
                        ClosestInfo = {Player, Player.Character, math.huge}
                    else
                        if ClosestInfo[2]:FindFirstChild("HumanoidRootPart") then 
                            if Player.Character:FindFirstChild("HumanoidRootPart") then
                                if (ClosestInfo[2].HumanoidRootPart.Position - Player.Character.HumanoidRootPart.Position).Magnitude <= ClosestInfo[3] then
                                    ClosestInfo = {Player, Player.Character, (ClosestInfo[2].HumanoidRootPart.Position - Player.Character.HumanoidRootPart.Position).Magnitude}
                                end
                            else
                                ClosestInfo = {Player, Player.Character}
                            end
                        end
                    end
                end

                local ClosestPlayer = ClosestInfo[1]
                NPCHum:MoveTo(ClosestPlayer.Character.HumanoidRootPart.Position)
                NPCHum.MoveToFinished:Connect(function()

                end)
            end
            task.wait()
        end
    end))

    Trove:Add(NPCHum.Died:Connect(function()
        local NPCService = Knit.GetService("NPCService")
        NPCService:RemoveNPC(NPCModel)

        local KillerID = NPCModel:GetAttribute("KillerID")
        if KillerID then
            local KillerPlayer = Players:GetPlayerFromUserId(Killer)

            if KillerPlayer then
                --Add rest later
            end
        end
    end)

    NPCModel:SetAttribute("ID", HttpService:GenerateGUID(false))
    NPCTable[NPC] = {
        Target = nil,
        Body = {
            LeftArm = 100,
            RightArm = 100,
            RightLeg = 100,
            LeftLeg = 100
        },
        Cooldowns = {
            Attack = 0.7,
            Kick = 2,
        }
    }
end

function NPCService:GetNPCTable(NPC: Model)
    return Promise.defer(function(Resolve, Reject, OnCancel)
        if NPCTable[NPC] then
            Resolve(NPCTable[NPC])
        else
            NPC:Destroy()
            Reject("NPC has no table")
        end
    end)
end

function NPCService:Attack(Target: Player, NPC: Model)
    local TargetChar = Target.Character
    if (TargetChar:GetPivot().Position - NPC:GetPivot().Position).Magnitude <= 4 then
        
    end
end

function NPCService:KnitInit()
    print("NPCService Initialised")
end

function NPCService:KnitStart()
end

return NPCService