-- npc_esp.lua
-- ESP para NPCs dentro de workspace.NPCs

--// Variables
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local NPCFolder = workspace:WaitForChild("NPCs")
local cache = {}

local bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

--// Configuración
local ESP_SETTINGS = {
    Enabled = false,
    ShowBox = false,
    ShowName = false,
    ShowHealthNumber = false, -- 👈 la vida se mostrará aunque el nombre esté desactivado
    ShowDistance = false,
    ShowSkeletons = false,
    ShowTracer = false,

    BoxColor = Color3.new(237, 2, 18),
    BoxOutlineColor = Color3.new(237, 2, 18),
    TracerColor = Color3.new(237, 2, 18),
    SkeletonsColor = Color3.new(237, 2, 18,
    TracerThickness = 2,
    TracerPosition = "Bottom"
}

--// Función para limpiar UID del nombre
local function cleanName(name)
    -- Elimina patrones tipo 8-4-4-4-12 (UUID)
    return string.gsub(name, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x", "")
end

--// Función de creación de objetos Drawing
local function create(class, props)
    local drawing = Drawing.new(class)
    for i, v in pairs(props) do
        drawing[i] = v
    end
    return drawing
end

--// Crear ESP
local function createEsp(npc)
    local esp = {
        box = create("Square", {Thickness = 1, Filled = false, Color = ESP_SETTINGS.BoxColor}),
        boxOutline = create("Square", {Thickness = 3, Filled = false, Color = ESP_SETTINGS.BoxOutlineColor}),
        name = create("Text", {Size = 13, Center = true, Outline = true, Color = Color3.new(1,1,1)}),
        distance = create("Text", {Size = 12, Center = true, Outline = true, Color = Color3.new(1,1,1)}),
        health = create("Text", {Size = 13, Center = true, Outline = true, Color = Color3.new(1,1,1)}),
        tracer = create("Line", {Thickness = ESP_SETTINGS.TracerThickness, Color = ESP_SETTINGS.TracerColor}),
        skeleton = {}
    }
    cache[npc] = esp
end

--// Eliminar ESP
local function removeEsp(npc)
    local esp = cache[npc]
    if esp then
        for _, v in pairs(esp) do
            if typeof(v) == "table" then
                for _, l in pairs(v) do
                    pcall(function() l:Remove() end)
                end
            else
                pcall(function() v:Remove() end)
            end
        end
        cache[npc] = nil
    end
end

--// Actualización visual
RunService.RenderStepped:Connect(function()
    if not ESP_SETTINGS.Enabled then
        for _, esp in pairs(cache) do
            for _, v in pairs(esp) do
                if typeof(v) == "table" then
                    for _, l in pairs(v) do
                        if typeof(l) == "userdata" then l.Visible = false end
                    end
                else
                    v.Visible = false
                end
            end
        end
        return
    end

    for npc, esp in pairs(cache) do
        if npc and npc.Parent == NPCFolder then
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            local head = npc:FindFirstChild("Head")
            local hum = npc:FindFirstChildOfClass("Humanoid")
            if hrp and head and hum and hum.Health > 0 then
                local pos, vis = camera:WorldToViewportPoint(hrp.Position)
                if vis then
                    -- Tamaño y posición de caja
                    local height = math.abs(camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0)).Y - camera:WorldToViewportPoint(hrp.Position + Vector3.new(0,2.6,0)).Y)
                    local width = height * 0.6
                    local x, y = pos.X - width/2, pos.Y - height/2

                    -- Caja
                    if ESP_SETTINGS.ShowBox then
                        esp.box.Size = Vector2.new(width, height)
                        esp.box.Position = Vector2.new(x, y)
                        esp.box.Visible = true
                        esp.boxOutline.Size = esp.box.Size
                        esp.boxOutline.Position = esp.box.Position
                        esp.boxOutline.Visible = true
                    else
                        esp.box.Visible = false
                        esp.boxOutline.Visible = false
                    end

                    -- Nombre sin UID
                    local baseName = cleanName(npc.Name)

                    if ESP_SETTINGS.ShowName then
                        esp.name.Visible = true
                        esp.name.Text = baseName
                        esp.name.Position = Vector2.new(pos.X, y - 15)
                    else
                        esp.name.Visible = false
                    end

                    -- Vida (siempre visible)
                    if ESP_SETTINGS.ShowHealthNumber and hum then
                        local healthText = string.format("[%d/%d]", math.floor(hum.Health), math.floor(hum.MaxHealth))
                        esp.health.Text = ESP_SETTINGS.ShowName and (" " .. healthText) or (baseName .. " " .. healthText)
                        esp.health.Visible = true
                        esp.health.Position = ESP_SETTINGS.ShowName
                            and Vector2.new(pos.X + (#baseName * 4.5), y - 15) -- al lado del nombre
                            or Vector2.new(pos.X, y - 15) -- si no hay nombre, usa posición del nombre
                    else
                        esp.health.Visible = false
                    end

                    -- Distancia
                    if ESP_SETTINGS.ShowDistance then
                        local dist = (camera.CFrame.Position - hrp.Position).Magnitude
                        esp.distance.Visible = true
                        esp.distance.Text = string.format("%.1f studs", dist)
                        esp.distance.Position = Vector2.new(pos.X, y + height + 10)
                    else
                        esp.distance.Visible = false
                    end

                    -- Tracer
                    if ESP_SETTINGS.ShowTracer then
                        local tracerY = (ESP_SETTINGS.TracerPosition == "Top" and 0)
                            or (ESP_SETTINGS.TracerPosition == "Middle" and camera.ViewportSize.Y / 2)
                            or camera.ViewportSize.Y
                        esp.tracer.Visible = true
                        esp.tracer.From = Vector2.new(camera.ViewportSize.X / 2, tracerY)
                        esp.tracer.To = Vector2.new(pos.X, pos.Y)
                    else
                        esp.tracer.Visible = false
                    end

                    -- Skeleton
                    if ESP_SETTINGS.ShowSkeletons then
                        if #esp.skeleton == 0 then
                            for _, bonePair in ipairs(bones) do
                                local line = create("Line", {Thickness = 1, Color = ESP_SETTINGS.SkeletonsColor})
                                table.insert(esp.skeleton, {line, bonePair[1], bonePair[2]})
                            end
                        end
                        for _, data in ipairs(esp.skeleton) do
                            local line, b1, b2 = data[1], data[2], data[3]
                            local p1 = npc:FindFirstChild(b1)
                            local p2 = npc:FindFirstChild(b2)
                            if p1 and p2 then
                                local s1, v1 = camera:WorldToViewportPoint(p1.Position)
                                local s2, v2 = camera:WorldToViewportPoint(p2.Position)
                                if v1 and v2 then
                                    line.From = Vector2.new(s1.X, s1.Y)
                                    line.To = Vector2.new(s2.X, s2.Y)
                                    line.Visible = true
                                else
                                    line.Visible = false
                                end
                            else
                                line.Visible = false
                            end
                        end
                    else
                        for _, data in ipairs(esp.skeleton) do
                            data[1].Visible = false
                        end
                    end
                else
                    for _, v in pairs(esp) do
                        if typeof(v) == "table" then
                            for _, l in pairs(v) do
                                if typeof(l) == "userdata" then l.Visible = false end
                            end
                        else
                            v.Visible = false
                        end
                    end
                end
            else
                removeEsp(npc)
            end
        else
            removeEsp(npc)
        end
    end
end)

--// Detectar NPCs nuevos
for _, npc in ipairs(NPCFolder:GetChildren()) do
    if npc:FindFirstChild("HumanoidRootPart") then
        createEsp(npc)
    end
end

NPCFolder.ChildAdded:Connect(function(npc)
    task.wait(0.5)
    if npc:FindFirstChild("HumanoidRootPart") then
        createEsp(npc)
    end
end)

NPCFolder.ChildRemoved:Connect(removeEsp)

return ESP_SETTINGS
