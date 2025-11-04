-- npc_esp_for_npcs.lua
-- ESP orientado a modelos NPC dentro de workspace.NPCs

local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
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

--// Settings (ajustalas aquí)
local ESP_SETTINGS = {
    BoxOutlineColor = Color3.new(0, 0, 0),
    BoxColor = Color3.new(237, 2, 18),
    NameColor = Color3.new(1, 1, 1),
    HealthOutlineColor = Color3.new(0, 0, 0),
    HealthHighColor = Color3.new(0, 1, 0),
    HealthLowColor = Color3.new(1, 0, 0),
    CharSize = Vector2.new(4, 6),

    -- Comportamiento
    WallCheck = false, -- si querés ignorar NPCs detrás de paredes
    Enabled = false,    -- activar ESP global
    ShowBox = false,
    BoxType = "2D", -- "2D" o "Corner Box Esp"
    ShowName = false,
    ShowHealth = false,
    ShowDistance = false,
    ShowSkeletons = false,
    ShowTracer = false,
    TracerColor = Color3.new(1, 1, 1),
    TracerThickness = 2,
    SkeletonsColor = Color3.new(1, 1, 1),
    TracerPosition = "Bottom", -- "Top", "Middle", "Bottom"
}

-- helper para crear objetos Drawing
local function create(class, properties)
    local drawing = Drawing.new(class)
    for property, value in pairs(properties or {}) do
        drawing[property] = value
    end
    return drawing
end

-- Crear ESP para un npc (model)
local function createEsp(npc)
    if not npc then return end
    if cache[npc] then return end

    local esp = {
        tracer = create("Line", { Thickness = ESP_SETTINGS.TracerThickness, Color = ESP_SETTINGS.TracerColor, Transparency = 0.5 }),
        boxOutline = create("Square", { Color = ESP_SETTINGS.BoxOutlineColor, Thickness = 3, Filled = false }),
        box = create("Square", { Color = ESP_SETTINGS.BoxColor, Thickness = 1, Filled = false }),
        name = create("Text", { Color = ESP_SETTINGS.NameColor, Outline = true, Center = true, Size = 13 }),
        healthOutline = create("Line", { Thickness = 3, Color = ESP_SETTINGS.HealthOutlineColor }),
        health = create("Line", { Thickness = 1 }),
        distance = create("Text", { Color = Color3.new(1, 1, 1), Size = 12, Outline = true, Center = true }),
        tracer = create("Line", { Thickness = ESP_SETTINGS.TracerThickness, Color = ESP_SETTINGS.TracerColor, Transparency = 1 }),
        boxLines = {},
        skeletonlines = {}
    }

    cache[npc] = esp
end

-- Determina si un modelo está detrás de una pared (opcional)
local function isModelBehindWall(model)
    local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("PrimaryPart")
    if not rootPart then return false end
    local dir = rootPart.Position - camera.CFrame.Position
    local ray = Ray.new(camera.CFrame.Position, dir.Unit * dir.Magnitude)
    local ignore = {}
    -- ignorar el camera y otras cosas si querés; por ahora vacío
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignore)
    return hit and hit:IsA("BasePart")
end

-- Remover ESP de un npc
local function removeEsp(npc)
    local esp = cache[npc]
    if not esp then return end
    for _, drawing in pairs(esp) do
        -- esp contiene tablas también, sólo los Drawing tienen :Remove
        if type(drawing) == "table" then
            -- lines arrays dentro de esp (skeletonlines o boxLines)
            for _, item in pairs(drawing) do
                if type(item) == "table" and item[1] and typeof(item[1]) == "userdata" and pcall(function() return item[1].Remove end) then
                    pcall(function() item[1]:Remove() end)
                elseif typeof(item) == "userdata" and pcall(function() return item.Remove end) then
                    pcall(function() item:Remove() end)
                end
            end
        else
            if typeof(drawing) == "userdata" and pcall(function() return drawing.Remove end) then
                pcall(function() drawing:Remove() end)
            end
        end
    end
    cache[npc] = nil
end

-- Actualizar cada frame
local function updateEsp()
    for npc, esp in pairs(cache) do
        if not esp then continue end

        local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
        local head = npc:FindFirstChild("Head")
        local humanoid = npc:FindFirstChildOfClass("Humanoid")
        local isBehindWall = ESP_SETTINGS.WallCheck and isModelBehindWall(npc)
        local shouldShow = not isBehindWall and ESP_SETTINGS.Enabled

        if rootPart and head and humanoid and shouldShow then
            local position, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            if onScreen then
                local hrp2D = camera:WorldToViewportPoint(rootPart.Position)
                local charSize = (camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0)).Y - camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 2.6, 0)).Y) / 2
                local boxSize = Vector2.new(math.floor(charSize * 1.8), math.floor(charSize * 1.9))
                local boxPosition = Vector2.new(math.floor(hrp2D.X - charSize * 1.8 / 2), math.floor(hrp2D.Y - charSize * 1.6 / 2))

                -- Nombre
                if ESP_SETTINGS.ShowName and ESP_SETTINGS.Enabled then
                    esp.name.Visible = true
                    -- limpiar UUID o guías del nombre
                    local cleanName = (npc.Name or "npc"):match("^(%a+)")
                    esp.name.Text = cleanName or "NPC"
                    esp.name.Position = Vector2.new(boxSize.X / 2 + boxPosition.X, boxPosition.Y - 16)
                    esp.name.Color = ESP_SETTINGS.NameColor
                else
                    esp.name.Visible = false
                end

                -- Caja
                if ESP_SETTINGS.ShowBox and ESP_SETTINGS.Enabled then
                    if ESP_SETTINGS.BoxType == "2D" then
                        esp.boxOutline.Size = boxSize
                        esp.boxOutline.Position = boxPosition
                        esp.box.Size = boxSize
                        esp.box.Position = boxPosition
                        esp.box.Color = ESP_SETTINGS.BoxColor
                        esp.box.Visible = true
                        esp.boxOutline.Visible = true
                        for _, line in ipairs(esp.boxLines) do line:Remove() end
                        esp.boxLines = {}
                    elseif ESP_SETTINGS.BoxType == "Corner Box Esp" then
                        local lineW = (boxSize.X / 5)
                        local lineH = (boxSize.Y / 6)
                        local lineT = 1
                        if #esp.boxLines == 0 then
                            for i = 1, 16 do
                                local boxLine = create("Line", { Thickness = 1, Color = ESP_SETTINGS.BoxColor, Transparency = 1 })
                                esp.boxLines[#esp.boxLines + 1] = boxLine
                            end
                        end
                        local boxLines = esp.boxLines
                        -- top left
                        boxLines[1].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                        boxLines[1].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y - lineT)
                        boxLines[2].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y - lineT)
                        boxLines[2].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + lineH)
                        -- top right
                        boxLines[3].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y - lineT)
                        boxLines[3].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                        boxLines[4].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y - lineT)
                        boxLines[4].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + lineH)
                        -- bottom left
                        boxLines[5].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y - lineH)
                        boxLines[5].To = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                        boxLines[6].From = Vector2.new(boxPosition.X - lineT, boxPosition.Y + boxSize.Y + lineT)
                        boxLines[6].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y + lineT)
                        -- bottom right
                        boxLines[7].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y + lineT)
                        boxLines[7].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
                        boxLines[8].From = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y - lineH)
                        boxLines[8].To = Vector2.new(boxPosition.X + boxSize.X + lineT, boxPosition.Y + boxSize.Y + lineT)
                        -- inline
                        for i = 9, 16 do
                            boxLines[i].Thickness = 2
                            boxLines[i].Color = ESP_SETTINGS.BoxOutlineColor
                            boxLines[i].Transparency = 1
                        end
                        boxLines[9].From = Vector2.new(boxPosition.X, boxPosition.Y)
                        boxLines[9].To = Vector2.new(boxPosition.X, boxPosition.Y + lineH)
                        boxLines[10].From = Vector2.new(boxPosition.X, boxPosition.Y)
                        boxLines[10].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y)
                        boxLines[11].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y)
                        boxLines[11].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)
                        boxLines[12].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y)
                        boxLines[12].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + lineH)
                        boxLines[13].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y - lineH)
                        boxLines[13].To = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)
                        boxLines[14].From = Vector2.new(boxPosition.X, boxPosition.Y + boxSize.Y)
                        boxLines[14].To = Vector2.new(boxPosition.X + lineW, boxPosition.Y + boxSize.Y)
                        boxLines[15].From = Vector2.new(boxPosition.X + boxSize.X - lineW, boxPosition.Y + boxSize.Y)
                        boxLines[15].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)
                        boxLines[16].From = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y - lineH)
                        boxLines[16].To = Vector2.new(boxPosition.X + boxSize.X, boxPosition.Y + boxSize.Y)
                        for _, line in ipairs(boxLines) do line.Visible = true end
                        esp.box.Visible = false
                        esp.boxOutline.Visible = false
                    end
                else
                    esp.box.Visible = false
                    esp.boxOutline.Visible = false
                    for _, line in ipairs(esp.boxLines) do line:Remove() end
                    esp.boxLines = {}
                end

                -- Salud
                if ESP_SETTINGS.ShowHealth and ESP_SETTINGS.Enabled then
                    esp.healthOutline.Visible = true
                    esp.health.Visible = true
                    local healthPercentage = (humanoid.Health / math.max(humanoid.MaxHealth, 1))
                    esp.healthOutline.From = Vector2.new(boxPosition.X - 6, boxPosition.Y + boxSize.Y)
                    esp.healthOutline.To = Vector2.new(esp.healthOutline.From.X, esp.healthOutline.From.Y - boxSize.Y)
                    esp.health.From = Vector2.new((boxPosition.X - 5), boxPosition.Y + boxSize.Y)
                    esp.health.To = Vector2.new(esp.health.From.X, esp.health.From.Y - (healthPercentage) * boxSize.Y)
                    esp.health.Color = ESP_SETTINGS.HealthLowColor:Lerp(ESP_SETTINGS.HealthHighColor, healthPercentage)
                else
                    esp.healthOutline.Visible = false
                    esp.health.Visible = false
                end

                -- Distancia
                if ESP_SETTINGS.ShowDistance and ESP_SETTINGS.Enabled then
                    local distance = (camera.CFrame.p - rootPart.Position).Magnitude
                    esp.distance.Text = string.format("%.1f studs", distance)
                    esp.distance.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 5)
                    esp.distance.Visible = true
                else
                    esp.distance.Visible = false
                end

                -- Skeletons
                if ESP_SETTINGS.ShowSkeletons and ESP_SETTINGS.Enabled then
                    if #esp["skeletonlines"] == 0 then
                        for _, bonePair in ipairs(bones) do
                            local parentBone, childBone = bonePair[1], bonePair[2]
                            if npc[parentBone] and npc[childBone] then
                                local skeletonLine = create("Line", { Thickness = 1, Color = ESP_SETTINGS.SkeletonsColor, Transparency = 1 })
                                esp["skeletonlines"][#esp["skeletonlines"] + 1] = {skeletonLine, parentBone, childBone}
                            end
                        end
                    end
                    for _, lineData in ipairs(esp["skeletonlines"]) do
                        local skeletonLine = lineData[1]
                        local parentBone, childBone = lineData[2], lineData[3]
                        if npc[parentBone] and npc[childBone] then
                            local parentPosition = camera:WorldToViewportPoint(npc[parentBone].Position)
                            local childPosition = camera:WorldToViewportPoint(npc[childBone].Position)
                            skeletonLine.From = Vector2.new(parentPosition.X, parentPosition.Y)
                            skeletonLine.To = Vector2.new(childPosition.X, childPosition.Y)
                            skeletonLine.Color = ESP_SETTINGS.SkeletonsColor
                            skeletonLine.Visible = true
                        else
                            skeletonLine:Remove()
                        end
                    end
                else
                    for _, lineData in ipairs(esp["skeletonlines"]) do
                        local skeletonLine = lineData[1]
                        skeletonLine:Remove()
                    end
                    esp["skeletonlines"] = {}
                end

                -- Tracer (simple, desde centro o bottom)
                if ESP_SETTINGS.ShowTracer and ESP_SETTINGS.Enabled then
                    local tracerY
                    if ESP_SETTINGS.TracerPosition == "Top" then tracerY = 0
                    elseif ESP_SETTINGS.TracerPosition == "Middle" then tracerY = camera.ViewportSize.Y / 2
                    else tracerY = camera.ViewportSize.Y end

                    esp.tracer.Visible = true
                    esp.tracer.From = Vector2.new(camera.ViewportSize.X / 2, tracerY)
                    esp.tracer.To = Vector2.new(hrp2D.X, hrp2D.Y)
                else
                    esp.tracer.Visible = false
                end

            else
                -- offscreen -> ocultar
                for _, drawing in pairs(esp) do
                    if type(drawing) ~= "table" and typeof(drawing) == "userdata" then
                        drawing.Visible = false
                    end
                end
                for _, lineData in ipairs(esp["skeletonlines"]) do
                    local skeletonLine = lineData[1]
                    skeletonLine:Remove()
                end
                esp["skeletonlines"] = {}
                for _, line in ipairs(esp.boxLines) do line:Remove() end
                esp.boxLines = {}
            end
        else
            -- npc inválido o no cumple condiciones -> ocultar
            for _, drawing in pairs(esp) do
                if type(drawing) ~= "table" and typeof(drawing) == "userdata" then
                    drawing.Visible = false
                end
            end
            for _, lineData in ipairs(esp["skeletonlines"]) do
                local skeletonLine = lineData[1]
                skeletonLine:Remove()
            end
            esp["skeletonlines"] = {}
            for _, line in ipairs(esp.boxLines) do line:Remove() end
            esp.boxLines = {}
        end
    end
end

-- Inicializar con NPCs existentes
local npcsFolder = workspace:FindFirstChild("NPCs")
if npcsFolder then
    for _, npc in ipairs(npcsFolder:GetChildren()) do
        createEsp(npc)
    end

    -- Listeners para añadir/remover
    npcsFolder.ChildAdded:Connect(function(child)
        createEsp(child)
    end)
    npcsFolder.ChildRemoved:Connect(function(child)
        removeEsp(child)
    end)
else
    warn("No se encontró workspace.NPCs; crea la carpeta o ajusta la ruta.")
end

-- Limpiar si el model es eliminado o pierde su Humanoid (opcional)
workspace.DescendantRemoving:Connect(function(desc)
    -- si el descendant pertenecía a un npc que tenemos en cache y el model quedó inválido, removemos
    for npc, _ in pairs(cache) do
        if not npc.Parent then
            removeEsp(npc)
        end
    end
end)

RunService.RenderStepped:Connect(updateEsp)

return ESP_SETTINGS
