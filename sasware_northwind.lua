Version = 'v0.3.7-prealpha'

local DEBUG = false

local function WaitForChildRecursive(Parent, Path)
    local PathSplit = string.split(Path, '.')
    local Current = Parent
    for i,v in next, PathSplit do
        Current = Current:WaitForChild(v)
    end
    return Current
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = game.Players.LocalPlayer
local DownedGui = WaitForChildRecursive(LocalPlayer.PlayerGui, 'InterfaceGuis.Downed.Main.Ornament.ImageGui')
local DefinEvents = nil
local Camera = workspace.CurrentCamera

local BulletDropRate = 1.1

local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/centerepic/script-host/main/ESP_DistanceCheck.lua"))() -- https://kiriot22.com/releases/ESP.lua
local Aiming = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/Aiming/main/Load.lua"))()("Module")

Aiming.Settings.Ignored.IgnoreLocalTeam = false
Aiming.Settings.TargetPart = {"Head", "UpperTorso", "LowerTorso"}
Aiming.Settings.RaycastIgnore = {workspace.TargetFilter}

local AimingSelected = Aiming.Selected
local AimingChecks = Aiming.Checks

local Start = true

local TeleportLocations = {
    [5465507265] = {
        ["St Paul"] = CFrame.new(3168, 111, 561),
        ["Den"] = CFrame.new(2768, 56, 3354),
        ["James Bay"] = CFrame.new(4163, 78, 2676),
        ["Henry's Hill"] = CFrame.new(3982, 387, 1151),
        ["Criminal Warehouse"] = CFrame.new(4046, 117, 409),
        ["Abandoned Camp"] = CFrame.new(2390, 104, 805),
        ["St. Paul Cave"] = CFrame.new(3168, 111, 561),
        ["Whitehill"] = CFrame.new(1756, 165, 1766),
        ["Twin Peaks"] = CFrame.new(2392, 531, 2050),
        ["Cobalt Deposits"] = CFrame.new(2353, 76, 2440),
        ["Lead Deposits"] = CFrame.new(702, 34, 2101),
        ["Iron Deposits"] = CFrame.new(3071, -49.5, 2232),
        ["Prison Items"] = CFrame.new(1074, 91, 2900),
        ["Rupert's Pass Cabin"] = CFrame.new(3515, 72, 1217),
        ["Fishing Cabin"] = CFrame.new(1845, 45, 3122),
        ["Fur Trader"] = CFrame.new(660, 34, 1324),
        ["Native Camp"] = CFrame.new(466, 88, 591),
        ["Forrester's Grove"] = CFrame.new(1779, 74, 1080)
    },
    [5620237900] = {
        ["Abandoned Garden"] = CFrame.new(2036, 61, 1265),
        ["New Bordeaux Warehouse"] = CFrame.new(50, 41, 329),
        ["Fort de Belcourt"] = CFrame.new(1799, 85, -1086),
        ["Rockledge"] = CFrame.new(-666, 30, 1579)
    },
    [5620237741] = {}
}

local GameFunctions = {}

local function SearchAllNilModulesForString(String : string)

    String = string.lower(String)

    local Results = {}

    for i,v in next, getnilinstances() do
        if v:IsA("ModuleScript") then
            local env = require(v)
            
            if type(env) == 'table' then
            
                for i,v in next, env do
                    if type(v) == 'string' and v ~= '' then
                        if string.find(v:lower(), String) then
                            table.insert(Results, {i, v})
                        end
                    end
                    if type(i) == 'string' and i ~= '' then
                        if string.find(i:lower(), String) then
                            table.insert(Results, {i, v})
                        end
                    end
                end
                
            end
        end
    end

    return Results
end

local function CalculateBulletDropCompensation(Origin : Vector3, Target : Vector3, DropRate : number)
	local Distance = (Origin - Target).Magnitude
	local Drop = Vector3.new(0, 1, 0) * ((Distance / 400) * DropRate)
	return Drop
end

if DEBUG then
    DefinEvents = Instance.new("RemoteEvent", ReplicatedStorage)
else
    DefinEvents = ReplicatedStorage:WaitForChild("DefinEvents")

    GameFunctions.OverEncumberedFunctions = {}

    task.spawn(function()
        repeat
            local Results = SearchAllNilModulesForString("IsOverEncumbered")
        
            for i,v in next, Results do
                table.insert(GameFunctions.OverEncumberedFunctions, v[2])
            end
            
            wait(2)
        until #GameFunctions.OverEncumberedFunctions > 0
    end)
    

    for i,v in next, getgc() do
        if type(v) == 'function' and islclosure(v) then
            if debug.getinfo(v).name == "SetStamina" then
                GameFunctions.StaminaFunction = v
            elseif debug.getinfo(v).name == "RaycastToAim" then
                GameFunctions.RaycastToAimFunction = v
            end
        end
    end
end
    
local function AutofillName(partialName)
    local players = game.Players:GetPlayers()
    local bestMatchPlayer = nil
    local bestMatchCount = 0

    for _, player in ipairs(players) do
        local playerName = player.Name:lower()
        local count = select(2, playerName:gsub(partialName:lower(), ""))

        if count > bestMatchCount then
            bestMatchPlayer = player
            bestMatchCount = count
        end
    end

    return bestMatchPlayer
end

local CharacterMethods = {}

function CharacterMethods:GetCharacter(Player : Player)
    if not Player then
        return game.Players.LocalPlayer.Character
    else
        return Player.Character
    end
end

function CharacterMethods:GetCharacters(IncludeLocalPlayer : boolean)
    local Characters = {}
    for _, Player in next, Players:GetPlayers() do
        if IncludeLocalPlayer then
            table.insert(Characters, Player.Character)
        else
            if Player ~= Players.LocalPlayer then
                table.insert(Characters, Player.Character)
            end
        end
    end
    return Characters
end

function CharacterMethods:Respawn()
    DefinEvents:WaitForChild("InteractingRequestRespawn"):InvokeServer(ReplicatedStorage:WaitForChild("Interacting"))
end

function CharacterMethods:TP(TargetCFrame)

    local TeleportFrameRoot = Instance.new("ScreenGui", Players.LocalPlayer.PlayerGui)
    TeleportFrameRoot.IgnoreGuiInset = true
    local TeleportFrame = Instance.new("Frame", TeleportFrameRoot)
    TeleportFrame.ZIndex = 1000
    TeleportFrame.Size = UDim2.new(1, 0, 1, 0)
    TeleportFrame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
    local TeleportText = Instance.new("TextLabel", TeleportFrame)
    TeleportText.ZIndex = 1001
    TeleportText.BackgroundTransparency = 1
    TeleportText.Size = UDim2.new(0.5, 0, 0.2, 0)
    TeleportText.Font = "GothamSemibold"
    TeleportText.TextColor3 = Color3.new(1, 1, 1)
    TeleportText.TextSize = 40
    TeleportText.Position = UDim2.new(0.25, 0, 0.4, 0)
    TeleportText.Text = "Teleporting... [0%]"

    local Lowest = -500

    Camera.CameraType = Enum.CameraType.Scriptable
    RunService:Set3dRenderingEnabled(false)

    local Character = CharacterMethods:GetCharacter()

    local Bind = RunService.Heartbeat:Connect(function()

        for _, BasePart in next, Character:GetChildren() do
            if BasePart:IsA("BasePart") then
                BasePart.CanCollide = false
            end
        end

    end)

    Character.Humanoid.PlatformStand = true
    Character:PivotTo(CFrame.new((Character:GetPivot().Position * Vector3.new(1,0,1)) - Vector3.new(0, 500, 0)))

    local OldGravity = workspace.Gravity
    workspace.Gravity = 0

    TeleportText.Text = "Teleporting... [32%]"

    local Start = tick()

    repeat RunService.Heartbeat:Wait() until Character.HumanoidRootPart.Position.Y > Lowest or tick() - Start > 5 or Players.LocalPlayer.PlayerGui.InterfaceGuis.Zone.Main.Title.TextGui.TextTransparency < 1
    repeat RunService.RenderStepped:Wait() until Players.LocalPlayer.PlayerGui.InterfaceGuis.Zone.Main.Title.TextGui.TextTransparency < 1

    TeleportText.Text = "Teleporting... [52%]"

    Bind:Disconnect()

    Players.LocalPlayer.Character.Humanoid.PlatformStand = false
    Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    repeat task.wait() until Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    wait(0.1)

    TeleportText.Text = "Teleporting... [72%]"

    for _, BasePart in next, Character:GetChildren() do
        if BasePart:IsA("BasePart") then
            BasePart.CanCollide = true
        end
    end

    TeleportText.Text = "Teleporting... [82%]"

    for i = 1, 50 do
        task.wait()
        Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        Players.LocalPlayer.Character:PivotTo(TargetCFrame)
    end

    TeleportText.Text = "Teleporting... [92%]"
    
    Camera.CameraType = Enum.CameraType.Custom
    RunService:Set3dRenderingEnabled(true)
    workspace.Gravity = OldGravity

    TeleportFrameRoot:Destroy()
end

CharacterMethods.Speed = {
    SpeedConnection = nil,
    SpeedBoost = 0,
    Heartbeat = function(DeltaTime)
        local Character = CharacterMethods:GetCharacter()
        if Character and Character:FindFirstChild("Humanoid") then
            Character:TranslateBy(Character.Humanoid.MoveDirection * CharacterMethods.Speed.SpeedBoost * DeltaTime)
        end
    end,
    Enabled = false
}

local CombatMethods = {}

do
    CombatMethods.HBE = {
        HitboxSize = 0,
        Toggled = false,
        Heartbeat = function()
            if CombatMethods.HBE.Toggled then
                for _, Character in next, CharacterMethods:GetCharacters(false) do
                    Character.HumanoidRootPart.Transparency = 0.8
                    Character.HumanoidRootPart.Size = Vector3.new(CombatMethods.HBE.HitboxSize, CombatMethods.HBE.HitboxSize, CombatMethods.HBE.HitboxSize)
                end
            else
                for _, Character in next, CharacterMethods:GetCharacters(false) do
                    Character.HumanoidRootPart.Transparency = 1
                    Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                end
            end
        end,
        Connection = nil
    }

    CombatMethods.BountyHBE = {
        HitboxSize = 0,
        Toggled = false,
        Heartbeat = function()
            if CombatMethods.BountyHBE.Toggled then
                for _, Npc in next, workspace.NPCs.Humans.BountyCombatNPCs:GetChildren() do
                    local Character = Npc:FindFirstChild("Character")
                    if Character and Character:FindFirstChild("HumanoidRootPart") then
                        if not Character.HumanoidRootPart:GetAttribute("OriginalSize") then
                            Character.HumanoidRootPart:SetAttribute("OriginalSize", Character.HumanoidRootPart.Size)
                        end
                        Character.HumanoidRootPart.Transparency = 0.8
                        Character.HumanoidRootPart.Size = Vector3.new(CombatMethods.BountyHBE.HitboxSize, CombatMethods.BountyHBE.HitboxSize, CombatMethods.BountyHBE.HitboxSize)
                    end
                end
            else
                for _, Npc in next, workspace.NPCs.Humans.BountyCombatNPCs:GetChildren() do
                    local Character = Npc:FindFirstChild("Character")
                    if Character and Character:FindFirstChild("HumanoidRootPart") then
                        Character.HumanoidRootPart.Transparency = 1
                        Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                    end
                end
            end
        end,
        Connection = nil
    }

    CombatMethods.AnimalHBE = {
        HitboxSize = 0,
        Toggled = false,
        Heartbeat = function()
            if CombatMethods.AnimalHBE.Toggled then
                for _, Animal in next, workspace.NPCs.Animals:GetChildren() do
                    local Character = Animal:FindFirstChild("Character")
                    if Character and Character:FindFirstChild("HumanoidRootPart") then
                        if not Character.HumanoidRootPart:GetAttribute("OriginalSize") then
                            Character.HumanoidRootPart:SetAttribute("OriginalSize", Character.HumanoidRootPart.Size)
                        end
                        Character.HumanoidRootPart.Transparency = 0.8
                        Character.HumanoidRootPart.Size = Vector3.new(CombatMethods.AnimalHBE.HitboxSize, CombatMethods.AnimalHBE.HitboxSize, CombatMethods.AnimalHBE.HitboxSize)
                    end
                end
            else
                for _, Animal in next, workspace.NPCs.Animals:GetChildren() do
                    local Character = Animal:FindFirstChild("Character")
                    if Character and Character:FindFirstChild("HumanoidRootPart") then
                        Character.HumanoidRootPart.Transparency = 1
                        Character.HumanoidRootPart.Size = Animal.HumanoidRootPart:GetAttribute("OriginalSize") or Vector3.new(2, 2, 1)
                    end
                end
            end
        end,
        Connection = nil
    }

    function CombatMethods.HBE:Toggle(Bool : boolean)
        self.Toggled = Bool

        if self.Toggled then
            self.Connection = RunService.Heartbeat:Connect(self.Heartbeat)
        else
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end

            self.Heartbeat()
        end
    end

    function CombatMethods.BountyHBE:Toggle(Bool : boolean)
        self.Toggled = Bool

        if self.Toggled then
            self.Connection = RunService.Heartbeat:Connect(self.Heartbeat)
        else
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end

            self.Heartbeat()
        end
    end

    function CombatMethods.AnimalHBE:Toggle(Bool : boolean)
        self.Toggled = Bool

        if self.Toggled then
            self.Connection = RunService.Heartbeat:Connect(self.Heartbeat)
        else
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end

            self.Heartbeat()
        end
    end

    function CombatMethods:GetTarget(Position : boolean)
        if not Position then
            return Aiming.Selected
        else
            return Aiming.Selected.Part.Position or Aiming.Selected.Position
        end
    end

    CombatMethods.Projectiles = {
        Wallbang = false,
        SilentAim = {
            Enabled = false,
            FOV = 30,
            AimPart = "Head"
        }
    }
end -- CombatMethods Setup

local VisualMethods = {}

VisualMethods.Ores = {
    CurrentOres = {},
    Connections = {}
}

do

    function VisualMethods.Ores:HandleOre(OreDeposit)
        if not VisualMethods.Ores.CurrentOres[OreDeposit] then 
            local OreInfo = VisualMethods.Ores:IsDeposit(OreDeposit)
            if OreInfo.IsDeposit then
                local ESPObject = ESP:Add(OreDeposit, {
                    Name = OreInfo.OreName .. " Ore",
                    Color = OreInfo.OreColor,
                    Box = false,
                    MaxDistance = function()
                        return Options.OreMaxDistance.Value or 1500
                    end,
                    PrimaryPart = OreDeposit.PrimaryPart,
                    IsEnabled = function() return Toggles.Ores.Value end,
                    ColorDynamic = function()
                        local OreColor = Color3.new(0.2,0.2,0.2)
                        if #OreDeposit.Ores:GetChildren() > 0 then
                            OreColor = OreDeposit.Ores:GetChildren()[1].Color
                        end
                        return OreColor
                    end,
                    Size = Vector3.new(6,6,6)
                })
                VisualMethods.Ores.CurrentOres[OreDeposit] = ESPObject
            end
        end
    end

    function VisualMethods.Ores:IsDeposit(Model : Model)
        if Model.Name:find("deposit") then
            local OreColor = Color3.new(0.2,0.2,0.2)

            if Model:FindFirstChild("Ores") and #Model.Ores:GetChildren() > 0 then
                OreColor = Model.Ores:GetChildren()[1].Color
            end

            local OreObject = {
                IsDeposit = true,
                OreName = Model.Name:split(" ")[1],
                OreColor = OreColor,
            }

            return OreObject
        else
            return {IsDeposit = false}
        end
    end

    function VisualMethods.Ores:Update()
        for _, OreDeposit in next, workspace.StaticProps.Resources:GetChildren() do
            VisualMethods.Ores:HandleOre(OreDeposit)
        end

        for _, OreDeposit in next, workspace.TargetFilter.Resources:GetChildren() do
            VisualMethods.Ores:HandleOre(OreDeposit)
        end
    end

    local DepositAddedConnecton = workspace.StaticProps.Resources.ChildAdded:Connect(function(OreDeposit)
        wait(0.1)
        VisualMethods.Ores:HandleOre(OreDeposit)
    end)
    local DepositAddedConnecton2 = workspace.TargetFilter.Resources.ChildAdded:Connect(function(OreDeposit)
        wait(0.1)
        VisualMethods.Ores:HandleOre(OreDeposit)
    end)

    table.insert(VisualMethods.Ores.Connections, DepositAddedConnecton)
    table.insert(VisualMethods.Ores.Connections, DepositAddedConnecton2)
end -- Ore ESP Setup

local OldBrightness = game.Lighting.Brightness
local OldAmbient = game.Lighting.Ambient

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'sasware | Northwind | ' .. Version,
    Center = true,
    AutoShow = true,
    TabPadding = 2,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab('Main'),
    Combat = Window:AddTab('Combat'),
    Visuals = Window:AddTab('Visuals'),
    Credits = Window:AddTab('Credits'),
    ['UI Settings'] = Window:AddTab('UI Settings')
}

-- Tab 1 - Character
local MainTab = Tabs.Main
local CharacterLeftGroupBox = MainTab:AddLeftGroupbox('Character Options')

CharacterLeftGroupBox:AddButton('Respawn', function()
    CharacterMethods:Respawn()
end)

CharacterLeftGroupBox:AddToggle('AntiLoot', {
    Text = 'Anti-Loot',
    Default = false,
    Callback = function(Value)
        print('[cb] AntiLoot changed to:', Value)
    end
})

CharacterLeftGroupBox:AddToggle('AntiOverencumbered', {
    Text = 'Anti-Overencumbered',
    Default = false,
    Callback = function(Value)
        print('[cb] AntiOverencumbered changed to:', Value)
    end
})

CharacterLeftGroupBox:AddToggle('InfiniteStamina', {
    Text = 'Infinite Stamina',
    Default = false,
    Callback = function(Value)
        print('[cb] InfiniteStamina changed to:', Value)
    end
})

CharacterLeftGroupBox:AddSlider('SpeedBoost', {
    Text = 'Speed Boost',
    Default = 0,
    Min = 0,
    Max = 5,
    Rounding = 2,
    Callback = function(Value)
        CharacterMethods.Speed.SpeedBoost = Value

        if Value > 0 then
            if not CharacterMethods.Speed.Enabled then
                CharacterMethods.Speed.Enabled = true
                CharacterMethods.Speed.SpeedConnection = RunService.Heartbeat:Connect(CharacterMethods.Speed.Heartbeat)
            end
        else
            if CharacterMethods.Speed.Enabled then
                CharacterMethods.Speed.Enabled = false
                CharacterMethods.Speed.SpeedConnection:Disconnect()
                CharacterMethods.Speed.SpeedConnection = nil
            end
        end
    end
})

CharacterLeftGroupBox:AddButton('Rollback Data [Soon™]', function()
    if not Start then
        local Sound = Instance.new("Sound", workspace)
        Sound.SoundId = "rbxassetid://4623124292"
        Sound.Loaded:Wait()
        Sound:Play()
    end
end)

local GameTeleportsRightGroupBox = MainTab:AddRightGroupbox('Island Teleports')

GameTeleportsRightGroupBox:AddButton('Rupert\'s Island', function()
    TeleportService:Teleport(5465507265)
end)

GameTeleportsRightGroupBox:AddButton('Cantermagne Island', function()
    TeleportService:Teleport(5620237741)
end)

GameTeleportsRightGroupBox:AddButton('Beauval', function()
    TeleportService:Teleport(5620237900)
end)

local ToolLeftGroupBox = MainTab:AddLeftGroupbox('Tool Modifications')

ToolLeftGroupBox:AddToggle('PickaxeMultiplier', {
    Text = 'Pickaxe Multiplier',
    Default = false,
    Callback = function(Value)
        print('[cb] PickaxeMultiplier changed to:', Value)
    end
})

local GameTeleportsRightGroupBox = MainTab:AddRightGroupbox('Location Teleports')

local CurrentTeleportLocations = TeleportLocations[game.PlaceId]

local NameIndexes = {}

for i, v in next, CurrentTeleportLocations do
    table.insert(NameIndexes, i)
end

GameTeleportsRightGroupBox:AddButton({
    Text = 'Teleport to contract',
    Func = function()

        local ContractItems = Players.LocalPlayer.PlayerGui.InterfaceGuis.TrackedContracts.Main.ScrollingContent:GetChildren()
        
        if #ContractItems > 1 then
            local Crate = nil

            local ContractItemName = ContractItems[2].Name

            print(ContractItemName)

            for i,v in next, game.ReplicatedStorage.Zones:GetDescendants() do
                if v.Name == ContractItemName and v:IsA("Model") then
                    print('found')
                    Crate = v
                    break
                end
            end

            if Crate == nil then
                for i,v in next, game.ReplicatedStorage.Zones:GetDescendants() do
                    if v.Name == 'WorldPerimeterPingGui' then
                        print('found 2')
                        warn(v.Parent.Name)
                        Crate = v.Parent.Parent
                        break
                    end
                end
            end

            if Crate and Crate:GetPivot() then
                CharacterMethods:TP(Crate:GetPivot())
            end
        end
    end,
    DoubleClick = false
})

GameTeleportsRightGroupBox:AddInput('PlayerTeleport', {
    Default = 'Player Name',
    Numeric = false,
    Finished = false,

    Text = 'Target Player',
    Tooltip = 'Input player name here',

    Placeholder = 'Put username here'
})

GameTeleportsRightGroupBox:AddButton({
    Text = 'Teleport to Player',
    Func = function()
        local Target = AutofillName(Options.PlayerTeleport.Value)
        if Target then
            CharacterMethods:TP(Target.Character.HumanoidRootPart.CFrame)
        end
    end,
    DoubleClick = false
})

local TeleportToPlayerButton =  GameTeleportsRightGroupBox:AddLabel('Target Player - None', false)

Options.PlayerTeleport:OnChanged(function()
    local Target = AutofillName(Options.PlayerTeleport.Value)
    if Target ~= nil and Target.Name then
        TeleportToPlayerButton:SetText('Target Player - ' .. Target.Name)
    else
        TeleportToPlayerButton:SetText('Target Player  - None')
    end
end)

GameTeleportsRightGroupBox:AddDivider()

GameTeleportsRightGroupBox:AddDropdown('TeleportLocations', {
    Values = NameIndexes,
    Default = 1,
    Multi = false,
    AllowNull = true,

    Text = 'Teleport Locations',
    Tooltip = 'Teleport to a location'
})

Options.TeleportLocations:OnChanged(function()
    if Options.TeleportLocations.Value ~= nil and Start == false then

        local Position = CurrentTeleportLocations[Options.TeleportLocations.Value]

        workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

        workspace.CurrentCamera.CFrame = CFrame.new(Position.Position + Vector3.new(0, 100, 0), Position.Position)

        local QueryRoot = Instance.new("ScreenGui", game.Players.LocalPlayer.PlayerGui)

        local TPYesButton = Instance.new('TextButton', QueryRoot)
        TPYesButton.Text = 'Yes' -- Positoned in the middle of the screen so both buttons are centered and spaced by 50 pixels
        TPYesButton.Size = UDim2.new(0, 100, 0, 50)
        TPYesButton.Position = UDim2.new(0.5, -150, 0.5, 0)
        TPYesButton.Font = Enum.Font.SourceSansBold
        TPYesButton.TextSize = 40

        local TPNoButton = Instance.new('TextButton', QueryRoot)
        TPNoButton.Text = 'No' -- Positoned in the middle of the screen so both buttons are centered and spaced by 50 pixels
        TPNoButton.Size = UDim2.new(0, 100, 0, 50)
        TPNoButton.Position = UDim2.new(0.5, 50, 0.5, 0)
        TPNoButton.Font = Enum.Font.SourceSansBold
        TPNoButton.TextSize = 40

        local NoCon; local YesCon;

        YesCon = TPYesButton.Activated:Once(function()
            NoCon:Disconnect()
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            CharacterMethods:TP(Position)
            Options.TeleportLocations:SetValue(nil)
            TPYesButton:Destroy()
            TPNoButton:Destroy()
        end)

        NoCon = TPNoButton.Activated:Once(function()
            YesCon:Disconnect()
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            Options.TeleportLocations:SetValue(nil)
            TPYesButton:Destroy()
            TPNoButton:Destroy()
        end)

    end
end)

-- Tab 2 - Combat
local CombatTab = Tabs.Combat
local CombatLeftGroupBox = CombatTab:AddLeftGroupbox('Combat Options')

CombatLeftGroupBox:AddToggle('Wallbang', {
    Text = 'Wallbang',
    Default = false,
    Callback = function(Value)
        CombatMethods.Projectiles.Wallbang = Value
        print('[cb] Wallbang changed to:', Value)
    end
})

CombatLeftGroupBox:AddButton({
    Text = 'Instant-Load nearest cannon',
    Func = function()
        -- Go through all models in workspace.Props.PlayerProps with name Field cannon and return nearest one
        local NearestCannon, NearestDistance = nil, math.huge
        for _, Model in next, workspace.Props.PlayerProps:GetChildren() do
            if Model.Name == "Field cannon" and Model:GetPivot() then
                local DistanceFromCharacter = (Model:GetPivot().Position - LocalPlayer.Character.HumanoidRootPart.CFrame.Position).Magnitude
                if DistanceFromCharacter < NearestDistance then
                    NearestDistance = DistanceFromCharacter
                    NearestCannon = Model
                end
            end
        end
        
        if NearestCannon then
            DefinEvents["Field cannonRequestAddBall"]:InvokeServer(NearestCannon)
            DefinEvents["Field cannonRequestRamBall"]:InvokeServer(NearestCannon)
        end
    end,
    DoubleClick = false
})

CombatLeftGroupBox:AddLabel('(Must have ram rod equipped)')

CombatLeftGroupBox:AddToggle('SilentAim', {
    Text = 'Silent Aim [In-Development]',
    Default = false,
    Callback = function(Value)
        CombatMethods.Projectiles.SilentAim.Enabled = Value
        Aiming.Enabled = Value
        Aiming.Settings.FOVSettings.Enabled = Value
        Aiming.Settings.TracerSettings.Enabled = Value
        print('[cb] Silent Aim changed to:', Value)
    end
})

CombatMethods.Projectiles.SilentAim.Enabled = false
Aiming.Enabled = false
Aiming.Settings.FOVSettings.Enabled = false
Aiming.Settings.TracerSettings.Enabled = false

CombatLeftGroupBox:AddSlider('SilentAimFOV', {
    Text = 'Silent Aim FOV',
    Default = 30,
    Min = 30,
    Max = 90,
    Rounding = 1,
    Callback = function(Value)
        CombatMethods.Projectiles.SilentAim.FOV = Value
        Aiming.Settings.FOVSettings.Scale = Value
        Aiming.UpdateFOV()
        print('[cb] Silent Aim FOV changed to:', Value)
    end
})

CombatLeftGroupBox:AddSlider('HitboxExtender', {
    Text = 'Hitbox Extender',
    Default = 0,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        if Value == 0 then
            CombatMethods.HBE:Toggle(false)
        else
            CombatMethods.HBE:Toggle(true)
            CombatMethods.HBE.HitboxSize = Value
        end
    end
})

CombatLeftGroupBox:AddSlider('BountyHitboxExtender', {
    Text = 'Bounty Hitbox Extender',
    Default = 0,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        if Value == 0 then
            CombatMethods.BountyHBE:Toggle(false)
        else
            CombatMethods.BountyHBE:Toggle(true)
            CombatMethods.BountyHBE.HitboxSize = Value
        end
    end
})

CombatLeftGroupBox:AddSlider('AnimalHitboxExtender', {
    Text = 'Animal Hitbox Extender',
    Default = 0,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        if Value == 0 then
            CombatMethods.AnimalHBE:Toggle(false)
        else
            CombatMethods.AnimalHBE:Toggle(true)
            CombatMethods.AnimalHBE.HitboxSize = Value
        end
    end
})

CombatLeftGroupBox:AddToggle('Killaura', {
    Text = 'Killaura  [Unimplemented]',
    Default = false,
    Callback = function(Value)
        print('[cb] Killaura changed to:', Value)
    end
})

-- Tab 3 - Visuals
local VisualsTab = Tabs.Visuals
local VisualsLeftGroupBox = VisualsTab:AddLeftGroupbox('ESP Settings')

VisualsLeftGroupBox:AddToggle('FullBright', {
    Text = 'Fullbright',
    Default = false,
    Callback = function(Value)
        print('[cb] FullBright changed to:', Value)
        if not Value then
            wait(0.1)
            game.Lighting.Brightness = OldBrightness
            game.Lighting.Ambient = OldAmbient
        else
            game.Lighting.Brightness = 1
            game.Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        end
    end
})

local FullbrightConnection_Brightness = game.Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
    if Toggles.FullBright.Value then
        game.Lighting.Brightness = 1
    end
end)

local FullbrightConnection_Ambient = game.Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
    if Toggles.FullBright.Value then
        game.Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    end
end)

VisualsLeftGroupBox:AddToggle('ESP', {
    Text = 'Show ESP',
    Default = false,
    Callback = function(Value)
        ESP:Toggle(Value)
        print('[cb] ESP changed to:', Value)
    end
})

VisualsLeftGroupBox:AddToggle('Boxes', {
    Text = 'Show Boxes',
    Default = true,
    Callback = function(Value)
        ESP.Boxes = Value
        print('[cb] Boxes changed to:', Value)
    end
})

VisualsLeftGroupBox:AddToggle('Names', {
    Text = 'Show Names',
    Default = true,
    Callback = function(Value)
        ESP.Names = Value
        print('[cb] Names changed to:', Value)
    end
})

-- VisualsLeftGroupBox:AddToggle('Distance', {
--     Text = 'Show Distance',
--     Default = false,
--     Callback = function(Value)
--         ESP.
--         print('[cb] Distance changed to:', Value)
--     end
-- })

VisualsLeftGroupBox:AddToggle('Players', {
    Text = 'Players',
    Default = false,
    Callback = function(Value)
        ESP.Players = Value
        print('[cb] Players changed to:', Value)
    end
})

VisualsLeftGroupBox:AddSlider('PlayerMaxDistance', {
    Text = 'Players Max Distance',
    Default = 1000,
    Min = 100,
    Max = 6000,
    Rounding = 0,
    Callback = function(Value)
        ESP.PlayerDistance = Value
        print('[cb] Max Distance changed to:', Value)
    end
})

VisualsLeftGroupBox:AddToggle('Mobs', {
    Text = 'Mobs [Unimplemented]',
    Default = false,
    Callback = function(Value)
        print('[cb] Mobs changed to:', Value)
    end
})

VisualsLeftGroupBox:AddToggle('Ores', {
    Text = 'Ores',
    Default = false,
    Callback = function(Value)
        ESP.Ores = Value
        print('[cb] Ores changed to:', Value)
    end
})

VisualsLeftGroupBox:AddSlider('OreMaxDistance', {
    Text = 'Ores Max Distance',
    Default = 1500,
    Min = 100,
    Max = 6000,
    Rounding = 0,
    Callback = function(Value)
        print('[cb] Max Distance changed to:', Value)
    end
})

-- Tab 4 - Credits
local CreditsTab = Tabs.Credits
local CreditsLeftGroupBox = CreditsTab:AddLeftGroupbox('Groupbox')
CreditsLeftGroupBox:AddLabel('Discord - https://discord.gg/g23xH7HykZ')
CreditsLeftGroupBox:AddLabel('sashaa#5351 / sashaa169')
CreditsLeftGroupBox:AddLabel('wally | UI Library')
CreditsLeftGroupBox:AddLabel('Stefanuk | Aiming Library')
CreditsLeftGroupBox:AddLabel('Kiriot | ESP Library')
CreditsLeftGroupBox:AddLabel('Confedyso | Financial Support')
CreditsLeftGroupBox:AddLabel('zu0a loves minors')

CreditsLeftGroupBox:AddButton('Unload', function() Library:Unload() end)

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

-- Addons
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:BuildConfigSection(Tabs["UI Settings"])

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('sasware')
SaveManager:SetFolder('sasware/Northwind')

ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:BuildConfigSection(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
    print('Unloaded!')
    Library.Unloaded = true
end)

for _, Function in next, GameFunctions.OverEncumberedFunctions do
    local OldOverEncumbered; OldOverEncumbered = hookfunction(Function, function(...)
        if Toggles.AntiOverencumbered.Value == true then
            return false
        end
        return OldOverEncumbered(...)
    end)
end

local OldStaminaFunction; OldStaminaFunction = hookfunction(GameFunctions.StaminaFunction, function(Player, Value)

	if Toggles.InfiniteStamina.Value == true and Player.Name == game.Players.LocalPlayer.Name then
		Value = 200
	end
	
	return OldStaminaFunction(Player, Value)
end)

local OldRaycastToAimFunction; OldRaycastToAimFunction = hookfunction(GameFunctions.RaycastToAimFunction, function(...)
    if CombatMethods.Projectiles.SilentAim.Enabled and AimingChecks.IsAvailable() then

        local PreviewPart = Instance.new("Part", workspace)
        PreviewPart.Anchored = true
        PreviewPart.CanCollide = false
        PreviewPart.Transparency = 0.3
        PreviewPart.Material = Enum.Material.Neon
        PreviewPart.Color = Color3.new(1, 0, 0)
        PreviewPart.Size = Vector3.new(1, 1, 1)
        PreviewPart.Position = (AimingSelected.Part.Position + CalculateBulletDropCompensation(LocalPlayer.Character.HumanoidRootPart.Position, AimingSelected.Part.Position, BulletDropRate))

        game.Debris:AddItem(PreviewPart, 0.1)

        return {
            Instance = AimingSelected.Part,  -- Aims higher depending on distance from humanoid root part
            Material = Enum.Material.Plastic,
            Normal = Vector3.new(),
            Position = AimingSelected.Part.Position + CalculateBulletDropCompensation(LocalPlayer.Character.HumanoidRootPart.Position, AimingSelected.Part.Position, BulletDropRate),
            Unit = Vector3.new(),
        }
    end
    return OldRaycastToAimFunction(...)
end)

local AimingHighlight = Instance.new("Highlight", workspace)
AimingHighlight.FillTransparency = 1
AimingHighlight.OutlineColor = Color3.new(1, 0, 0)
AimingHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

task.spawn(function()
    while wait(0.1) do
        if Toggles.AntiLoot.Value == true and DownedGui.ImageTransparency ~= 1 then
            LocalPlayer.Character:PivotTo(LocalPlayer.Character:GetPivot() - Vector3.new(0, 500, 0))
            repeat wait(); for i,v in next, LocalPlayer.Character:GetDescendants() do if v:IsA("BasePart") then v.AssemblyLinearVelocity = Vector3.new(0,0,0) end end until not LocalPlayer.Character.Humanoid.PlatformStand and LocalPlayer.Character.HumanoidRootPart.Position.Y > -500
            local Start = tick()
            repeat
                wait()
                for i,v in next, LocalPlayer.Character:GetDescendants() do if v:IsA("BasePart") then v.AssemblyLinearVelocity = Vector3.new(0,0,0) end end
            until tick() - Start > 5
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if (AimingChecks.IsAvailable()) and Toggles.SilentAim.Value == true then
        AimingHighlight.Parent = AimingSelected.Part
    else
        AimingHighlight.Parent = game.Lighting
    end
end)

local OldNamecall; OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local Args = {...}
    local Method = getnamecallmethod()

    if not checkcaller() then
        if self == workspace and Method == 'Raycast' then

            local RaycastParameters = Args[3]
            local FilterInstances = RaycastParameters.FilterDescendantsInstances
    
            if CombatMethods.Projectiles.Wallbang or CombatMethods.Projectiles.SilentAim.Enabled then
                if #FilterInstances == 2 and table.find(FilterInstances, workspace.TargetFilter) and table.find(FilterInstances, workspace.Carriables) then
                    if CombatMethods.Projectiles.Wallbang then
                        Args[3].FilterDescendantsInstances = {workspace.Characters}
                        Args[3].FilterType = Enum.RaycastFilterType.Include
                    end
                    return OldNamecall(self, table.unpack(Args))
                elseif #FilterInstances == 1 and table.find(FilterInstances, workspace.TargetFilter) then
                    if CombatMethods.Projectiles.Wallbang then
                        Args[3].FilterDescendantsInstances = {workspace.Characters}
                        Args[3].FilterType = Enum.RaycastFilterType.Include
                    end
                    return OldNamecall(self, table.unpack(Args))
                end
            end
        end
    end

    return OldNamecall(self, ...)
end)

VisualMethods.Ores:Update()

Start = false