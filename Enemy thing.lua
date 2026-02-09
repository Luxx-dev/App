--!strict
--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--//Assets
local EnemyFolder = ReplicatedStorage.Assets.EnemiesFolder

--//Utilities
local Enemies = require(script.Enemies)

local EnemyManager = {}

--//Variables
local Count : number = 0

--//Types
export type EnemyStats = {
	Names : {string},
	Healths : {number},
	Damages : {number},
	AttackCooldowns : {number},
	Movespeeds : {number},
	Types : {string},
	Connections : {RBXScriptConnection},
	Targets : {Model},
	Radius : {number},
	LastAttack : {number},
	LastMove : {number},
	NextMove : {number},
	Models : {Model},	
}

local EnemyStats : EnemyStats = {
	Names = {},
	Healths = {},
	Damages = {},
	AttackCooldowns = {},
	Movespeeds = {},
	Types = {},
	Connections = {},
	Targets = {},
	Radius = {},
	LastAttack = {},
	LastMove = {},
	NextMove = {},
	Models = {},	
}

local function CalculateEnemy()
	local totalWeight = 0
	for _, item in Enemies do
		totalWeight += item.Chance
	end

	local roll = math.random() * totalWeight
	local current = 0

	for _, item in Enemies do
		current += item.Chance
		if roll <= current then
			return item
		end
	end
end

local function CalculatePosition(x: number, y: number, z: number) : Vector3
	local randx = math.random(-x, x)
	local randz = math.random(-z, z)
	
	return Vector3.new(randx, y, randz)
end

function EnemyManager.GetWaveStatus()
	if Count > 0 then
		return "Wave in session"
	end
	return "Wave ended"
end

function EnemyManager.Init()
	local EnemyCount = 15
	EnemyManager.StartWave(EnemyCount)
end

function EnemyManager.StartWave(EnemyCount)
	if Count > 0 then return end
	
	for i = 1, EnemyCount do
		EnemyManager.SpawnEnemy()
	end
end

function EnemyManager.SpawnEnemy()
	local Enemy = CalculateEnemy()
	
	local EnemyIndex = Count + 1
	Count = EnemyIndex
	
	EnemyStats.Names[EnemyIndex] = Enemy.Name
	EnemyStats.Healths[EnemyIndex] = Enemy.Health
	EnemyStats.Damages[EnemyIndex] = Enemy.Damage
	EnemyStats.Types[EnemyIndex] = Enemy.Type
	EnemyStats.AttackCooldowns[EnemyIndex] = Enemy.AttackCooldown
	EnemyStats.LastAttack[EnemyIndex] = 0
	EnemyStats.LastMove[EnemyIndex] = 0
	EnemyStats.NextMove[EnemyIndex] = 0
	EnemyStats.Radius[EnemyIndex] = Enemy.Radius
	EnemyStats.Movespeeds[EnemyIndex] = Enemy.Movespeed
	EnemyStats.Models[EnemyIndex] = EnemyFolder:WaitForChild(Enemy.Name):Clone()
	
	local model = EnemyStats.Models[EnemyIndex]
	if not model then return end
	
	local humanoid = model:WaitForChild("Humanoid")
	local primarypart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	
	humanoid.MaxHealth = EnemyStats.Healths[EnemyIndex]
	humanoid.Health = EnemyStats.Healths[EnemyIndex]
	humanoid.WalkSpeed = EnemyStats.Movespeeds[EnemyIndex]
	
	primarypart.Position = CalculatePosition(500, 50, 500)
	
	local EnemiesFolder = workspace.Enemies
	if not EnemiesFolder then
		EnemiesFolder = Instance.new("Folder")
		EnemiesFolder.Name = "Enemies"
		EnemiesFolder.Parent = workspace
	end
	model.Parent = EnemiesFolder
	
	EnemyManager.FindTarget(EnemyIndex)
end

local MoveCd = 0.4
local NextMoveCd = 8
function EnemyManager.FindTarget(EnemyIndex: number)
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		EnemyStats.Connections[EnemyIndex] = connection
		
		if EnemyStats.LastMove[EnemyIndex] and os.clock() - EnemyStats.LastMove[EnemyIndex] < MoveCd then 
			return 
		end
		EnemyStats.LastMove[EnemyIndex] = os.clock()
		
		local model = EnemyStats.Models[EnemyIndex]
		local primarypart: BasePart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		local humanoid = model:FindFirstChild("Humanoid")
		
		local params =  OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {model}
		
		if EnemyStats.Targets[EnemyIndex] and EnemyStats.Targets[EnemyIndex]:FindFirstChild("Humanoid") then
			if EnemyStats.Targets[EnemyIndex].Humanoid.Health <= 0 then 
				EnemyStats.Targets[EnemyIndex] = nil
				return
			end
			
			if (EnemyStats.Targets[EnemyIndex].HumanoidRootPart.Position - model:FindFirstChild("HumanoidRootPart").Position).Magnitude < 1.5 then
				EnemyManager.Attack(EnemyIndex)
			end
			
			local PositionToMoveTo = EnemyStats.Targets[EnemyIndex].PrimaryPart.Position or EnemyStats.Targets[EnemyIndex]:FindFirstChildWhichIsA("BasePart")
			if PositionToMoveTo then
				humanoid:MoveTo(PositionToMoveTo)
				EnemyStats.NextMove[EnemyIndex] = 0
				return
			end
		end
		
		local target = nil
		target = workspace:GetPartBoundsInRadius(primarypart.Position, EnemyStats.Radius[EnemyIndex], params)
		
		if target then
			for _, Part in target do
				if Part.Parent:FindFirstChild("Humanoid") and game.Players:GetPlayerFromCharacter(Part.Parent) then
					EnemyStats.Targets[EnemyIndex] = Part.Parent
					if (EnemyStats.Targets[EnemyIndex].HumanoidRootPart.Position - model:FindFirstChild("HumanoidRootPart").Position).Magnitude < 1.5 then
						EnemyManager.Attack(EnemyIndex)
					end
				
					if Part.Parent.PrimaryPart or Part.Parent:FindFirstChildWhichIsA("BasePart") then
						humanoid:MoveTo(Part.Parent.PrimaryPart.Position or Part.Parent:FindFirstChildWhichIsA("BasePart").Position)
						EnemyStats.NextMove[EnemyIndex] = 0
					end
				else
					EnemyStats.Targets[EnemyIndex] = nil
					EnemyStats.NextMove[EnemyIndex] += MoveCd
					print(EnemyStats.NextMove[EnemyIndex])
					
					if EnemyStats.NextMove[EnemyIndex] >= NextMoveCd then
						EnemyStats.NextMove[EnemyIndex] = 0
						local PositionToMove = CalculatePosition(20, 0, 20)
						humanoid:MoveTo(primarypart.Position + PositionToMove)
					end
				end
			end
		end
	end)
end

function EnemyManager.Attack(EnemyIndex: number)
	if EnemyStats.LastAttack[EnemyIndex] and os.clock() - EnemyStats.LastAttack[EnemyIndex] < EnemyStats.AttackCooldowns[EnemyIndex] then return end
	EnemyStats.LastAttack[EnemyIndex] = os.clock()
	
	local target = EnemyStats.Targets[EnemyIndex]
	if not target then 
		return
	end
	
	local targetHumanoid = target:WaitForChild("Humanoid")
	targetHumanoid:TakeDamage(EnemyStats.Damages[EnemyIndex])
end

function EnemyManager.Destroy(EnemyIndex: number)
	
	if EnemyStats.Connections[EnemyIndex] then
		EnemyStats.Connections[EnemyIndex]:Disconnect()
		EnemyStats.Connections[EnemyIndex] = nil
	end
	
	if EnemyStats.Models[EnemyIndex] then
		EnemyStats.Models[EnemyIndex]:Destroy()
		EnemyStats.Models[EnemyIndex] = nil
	end
	
	local lastindex = Count
	Count = lastindex - 1
	
	if EnemyIndex ~= lastindex then
		EnemyStats.Names[EnemyIndex] = EnemyStats.Names[lastindex]
		EnemyStats.Healths[EnemyIndex] = EnemyStats.Healths[lastindex]
		EnemyStats.Damages[EnemyIndex] = EnemyStats.Damages[EnemyIndex]
		EnemyStats.Types[EnemyIndex] = EnemyStats.Types[EnemyIndex]
		EnemyStats.AttackCooldowns[EnemyIndex] = EnemyStats.AttackCooldowns[lastindex]
		EnemyStats.LastAttack[EnemyIndex] = EnemyStats.LastAttack[lastindex]
		EnemyStats.LastMove[EnemyIndex] = EnemyStats.LastMove[lastindex]
		EnemyStats.NextMove[EnemyIndex] = EnemyStats.NextMove[lastindex]
		EnemyStats.Movespeeds[EnemyIndex] = EnemyStats.Movespeeds[lastindex]
		EnemyStats.Models[EnemyIndex] = EnemyStats.Models[lastindex]
	end
	
	EnemyStats.Names[lastindex] = nil
	EnemyStats.Healths[lastindex] = nil
	EnemyStats.Damages[lastindex] = nil
	EnemyStats.Types[lastindex] = nil
	EnemyStats.AttackCooldowns[lastindex] = nil
	EnemyStats.LastAttack[lastindex] = nil
	EnemyStats.LastMove[lastindex] = nil
	EnemyStats.NextMove[lastindex] = nil
	EnemyStats.Movespeeds[lastindex] = nil
	EnemyStats.Models[lastindex] = nil
	EnemyStats.Connections[lastindex] = nil
end

function EnemyManager.KillAllEnemies()
	for i = Count, 1, -1 do
		EnemyManager.Destroy(i)
	end
end

return EnemyManager
