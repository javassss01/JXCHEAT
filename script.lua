-- Target: Roblox Universal / Mobile Runtimes (Delta)
-- Description: Multi-bone skeletal tracer lines, 2D bounding boxes, and vertical health bars

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local CFG = {
    Enabled = true,
    TeamCheck = false,
    TracerOrigin = Vector2.new(Camera.ViewportSize.X / 2, 0), -- Top-center convergence like reference
    BoxColor = Color3.fromRGB(255, 40, 40),
    TracerColor = Color3.fromRGB(255, 30, 30),
}

local drawings = {}

local function safe(fn)
    local ok, err = pcall(fn)
    if not ok then warn("[KEEL]", err) end
end

local function create_esp(plr)
    safe(function()
        if drawings[plr] then return end
        
        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = CFG.BoxColor
        box.Thickness = 1.5
        box.Filled = false

        local healthBg = Drawing.new("Line")
        healthBg.Visible = false
        healthBg.Color = Color3.fromRGB(40, 40, 40)
        healthBg.Thickness = 2.5

        local healthBar = Drawing.new("Line")
        healthBar.Visible = false
        healthBar.Color = Color3.fromRGB(0, 255, 100)
        healthBar.Thickness = 1.5

        -- Bone tracers: Head, Chest, Left Arm, Right Arm
        local bones = {"Head", "UpperTorso", "LeftUpperArm", "RightUpperArm"}
        local boneTracers = {}
        for _, bone in ipairs(bones) do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = CFG.TracerColor
            line.Thickness = 1
            boneTracers[bone] = line
        end

        drawings[plr] = {
            box = box,
            healthBg = healthBg,
            healthBar = healthBar,
            boneTracers = boneTracers,
            bones = bones
        }
    end)
end

local function remove_esp(plr)
    safe(function()
        local d = drawings[plr]
        if d then
            d.box:Remove()
            d.healthBg:Remove()
            d.healthBar:Remove()
            for _, line in pairs(d.boneTracers) do
                line:Remove()
            end
            drawings[plr] = nil
        end
    end)
end

local function world_to_screen(pos)
    local screen, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), onScreen, screen.Z
end

RunService.Heartbeat:Connect(function()
    if not CFG.Enabled then
        for _, d in pairs(drawings) do
            d.box.Visible = false
            d.healthBg.Visible = false
            d.healthBar.Visible = false
            for _, line in pairs(d.boneTracers) do line.Visible = false end
        end
        return
    end

    CFG.TracerOrigin = Vector2.new(Camera.ViewportSize.X / 2, 0)

    for plr, d in pairs(drawings) do
        safe(function()
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso"))

            if not char or not hum or hum.Health <= 0 or not root or (CFG.TeamCheck and plr.Team == LocalPlayer.Team) then
                d.box.Visible = false
                d.healthBg.Visible = false
                d.healthBar.Visible = false
                for _, line in pairs(d.boneTracers) do line.Visible = false end
                return
            end

            local topPos = (char:FindFirstChild("Head").CFrame * CFrame.new(0, 0.8, 0)).Position
            local botPos = (root.CFrame * CFrame.new(0, -2.8, 0)).Position
            local top, _, topDepth = world_to_screen(topPos)
            local bot, _, botDepth = world_to_screen(botPos)

            if topDepth < 0 and botDepth < 0 then
                d.box.Visible = false
                d.healthBg.Visible = false
                d.healthBar.Visible = false
                for _, line in pairs(d.boneTracers) do line.Visible = false end
                return
            end

            local height = math.abs(top.Y - bot.Y)
            local width = height * 0.55

            -- 2D Box
            d.box.Size = Vector2.new(width, height)
            d.box.Position = Vector2.new(top.X - width / 2, top.Y)
            d.box.Visible = true

            -- Vertical Health Bar (left side of box)
            local healthPct = math.clamp(hum.Health / hum.MaxHeight, 0, 1) -- MaxHealth fallback handled
            local currentMaxHealth = hum.MaxHealth > 0 and hum.MaxHealth or 100
            healthPct = math.clamp(hum.Health / currentMaxHealth, 0, 1)

            local barX = top.X - width / 2 - 6
            d.healthBg.From = Vector2.new(barX, bot.Y)
            d.healthBg.To = Vector2.new(barX, top.Y)
            d.healthBg.Visible = true

            local healthHeight = height * healthPct
            d.healthBar.From = Vector2.new(barX, bot.Y)
            d.healthBar.To = Vector2.new(barX, bot.Y - healthHeight)
            d.healthBar.Visible = true

            -- Multi-bone Tracers converging to top-center origin
            for _, boneName in ipairs(d.bones) do
                local bonePart = char:FindFirstChild(boneName)
                local line = d.boneTracers[boneName]
                if bonePart and line then
                    local screenPos, onScreen, depth = world_to_screen(bonePart.Position)
                    if depth > 0 then
                        line.From = CFG.TracerOrigin
                        line.To = screenPos
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        end)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then create_esp(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function() create_esp(p) end)
    end
end)
Players.PlayerRemoving:Connect(remove_esp)

print("[KEEL] Multi-Bone Skeletal ESP Loaded")
