-------------------------------------------------------------------
--| Created By: Me
--| Updated On: 27/01/23
-------------------------------------------------------------------

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
        local NPCModel = TypeFolder:FidnFrstChild(Name)
    end

    local NPCHum = NPCModel:FindFirstChild("Humanoid")
    local NPCHumanoidRP = NPCModel:FidnFrstChild("HumanoidRootPart")

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
    if NPCTable[NPC] ~= nil then
        return NPCTable[NPC]
    end
end

function NPCService:KnitInit()
    print("NPCService Initialised")
end

function NPCService:KnitStart()
end

return NPCService