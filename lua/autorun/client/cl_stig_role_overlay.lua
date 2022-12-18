local overlayPositions = {}
local YPos = 50
local alpha = 0
local iconSize = 40
local playerNames = {}
local minBoxWidth = 150
local boxOutlineSize = 2
local boxPadding = 10
local boxBorderSize = 28
local boxWidths = {}

surface.CreateFont("RoleOverlayFont", {
    font = "Trebuchet24",
    size = 28,
    weight = 1000,
    shadow = true
})

local function WordBox(bordersize, x, y, text, font, color, fontcolor, xalign, yalign)
    surface.SetFont(font)
    local w, h = surface.GetTextSize(text)

    if (xalign == TEXT_ALIGN_CENTER) then
        x = x - (bordersize + w / 2)
    elseif (xalign == TEXT_ALIGN_RIGHT) then
        x = x - (bordersize * 2 + w)
    end

    if (yalign == TEXT_ALIGN_CENTER) then
        y = y - (bordersize + h / 2)
    elseif (yalign == TEXT_ALIGN_BOTTOM) then
        y = y - (bordersize * 2 + h)
    end

    local boxWidth = w + bordersize * 2
    boxWidth = math.max(minBoxWidth, boxWidth)
    local xDiff = boxWidth - (w + bordersize * 2)
    -- Box outline
    draw.RoundedBox(bordersize, x - xDiff / 2 - boxOutlineSize, y + bordersize / 1.3 - boxOutlineSize, boxWidth + boxOutlineSize * 2, h + bordersize / 2 + boxOutlineSize * 2, COLOR_WHITE)
    -- Box background
    draw.RoundedBox(bordersize, x - xDiff / 2, y + bordersize / 1.3, boxWidth, h + bordersize / 2, color)
    -- Box text
    surface.SetTextColor(fontcolor.r, fontcolor.g, fontcolor.b, fontcolor.a)
    surface.SetTextPos(x + bordersize, y + bordersize)
    surface.DrawText(text)

    return boxWidth
end

local function OverrideColours()
    local colourTable = table.Copy(ROLE_COLORS)

    if ConVarExists("ttt_color_mode") and (GetConVar("ttt_color_mode"):GetString() == "default" or GetConVar("ttt_color_mode"):GetString() == "simple") then
        for key, colour in pairs(colourTable) do
            if colour == Color(0, 225, 0, 255) or colour == Color(245, 200, 0, 255) then
                colourTable[key] = Color(25, 150, 25)
            elseif colour == Color(245, 106, 0, 255) or colour == Color(225, 0, 0, 255) then
                colourTable[key] = Color(150, 0, 0)
            elseif colour == Color(0, 210, 240, 255) then
                colourTable[key] = Color(0, 0, 225, 255)
            end
        end
    end

    return colourTable
end

local function CalculateBoxWidths()
    local screenWidth = ScrW()
    local overlayWidth = 0

    for _, ply in ipairs(player.GetAll()) do
        if ply:IsSpec() then continue end
        overlayWidth = overlayWidth + boxPadding + boxWidths[ply]
    end

    local leftMargin = screenWidth / 2 - overlayWidth / 2
    local boxOffset = 0

    for _, ply in ipairs(player.GetAll()) do
        if ply:IsSpec() then continue end
        boxOffset = boxOffset + boxWidths[ply] / 2
        overlayPositions[ply] = leftMargin + boxOffset
        boxOffset = boxOffset + boxPadding + boxWidths[ply] / 2
    end
end

local overlayConvar = CreateClientConVar("ttt_role_overlay", "1", true, false, "Whether the role overlay is on or not", 0, 1)
local overlayToggle = GetConVar("ttt_role_overlay"):GetBool()
local messageShown = false
local tabPressed = false

hook.Add("ScoreboardShow", "RoleOverlayPressTab", function()
    if tabPressed then
        if overlayToggle then
            overlayConvar:SetBool(false)
            overlayToggle = false
            chat.AddText("Role overlay disabled")
        else
            overlayConvar:SetBool(true)
            overlayToggle = true
            chat.AddText("Role overlay enabled")

            timer.Simple(0.1, function()
                CalculateBoxWidths()
            end)
        end
    else
        tabPressed = true
        local binding = input.LookupBinding("+score") or "TAB"

        if not messageShown then
            chat.AddText(COLOR_GREEN, "Double-press " .. string.upper(binding) .. " to toggle role overlay")
            messageShown = true
        end

        timer.Simple(1, function()
            tabPressed = false
        end)
    end
end)

local function CreateOverlay()
    local playerCount = 0

    -- Grabbing player names and the number of them
    for i, ply in ipairs(player.GetAll()) do
        playerCount = playerCount + 1
        playerNames[ply] = ply:Nick()
    end

    -- Sets all overlay positions to 0, so after the wordboxes are first drawn in the overlay hook, we can get the boxes' width
    for _, ply in ipairs(player.GetAll()) do
        if ply:IsSpec() then
            overlayPositions[ply] = nil
        elseif not overlayPositions[ply] then
            overlayPositions[ply] = 0
        end
    end

    -- Fallback colours to use if CR for TTT is not installed
    local defaultColour = Color(100, 100, 100)

    local colourTable = {
        [ROLE_INNOCENT] = Color(25, 200, 25, 200),
        [ROLE_TRAITOR] = Color(200, 25, 25, 200),
        [ROLE_DETECTIVE] = Color(25, 25, 200, 200)
    }

    -- If CR is a thing, force simplified role colours, and make the green colour more readable against the white text
    if istable(ROLE_COLORS) then
        colourTable = OverrideColours()

        timer.Create("RoleOverlayColourChangeCheck", 1, 0, function()
            colourTable = OverrideColours()
        end)
    end

    -- Getting the icons for every role if Custom Roles for TTT is installed
    local roleIcons = nil

    if ROLE_STRINGS_SHORT then
        roleIcons = {}

        for roleID, shortName in pairs(ROLE_STRINGS_SHORT) do
            if file.Exists("materials/vgui/ttt/roles/" .. shortName .. "/sprite_" .. shortName .. ".vtf", "GAME") then
                roleIcons[roleID] = Material("vgui/ttt/roles/" .. shortName .. "/sprite_" .. shortName .. ".vtf")
            else
                roleIcons[roleID] = Material("vgui/ttt/sprite_" .. shortName .. ".png")
            end
        end

        -- Add the "?" icon for unknown jesters/detectives
        if file.Exists("materials/vgui/ttt/roles/nil/sprite_nil.vtf", "GAME") then
            roleIcons[ROLE_NONE] = Material("vgui/ttt/roles/nil/sprite_nil.vtf")
        else
            roleIcons[ROLE_NONE] = Material("vgui/ttt/sprite_nil.png")
        end
    end

    if alpha == 0 then
        timer.Create("RoleOverlayStartFade", 3.031, 1, function()
            timer.Create("RoleOverlayFadeIn", 0.01, 100, function()
                alpha = alpha + 0.01
            end)
        end)
    else
        alpha = 1
    end

    local boxWidthsCalculated = false

    timer.Simple(0.1, function()
        CalculateBoxWidths()

        timer.Simple(1, function()
            boxWidthsCalculated = true
        end)
    end)

    hook.Add("DrawOverlay", "RoleOverlayDrawNameOverlay", function()
        if not overlayToggle then return end
        surface.SetAlphaMultiplier(alpha)

        for ply, XPos in SortedPairsByValue(overlayPositions) do
            if not IsValid(ply) then continue end
            local roleColour = defaultColour
            local iconRole = nil

            if GetRoundState() == ROUND_PREP or not boxWidthsCalculated then
                -- If the round hasn't started yet,
                -- or in the split-second where the overlay is not displayed properly as box widths are being calculated,
                -- display everyone as a grey rectangle
                roleColour = defaultColour
                iconRole = nil
            elseif GetRoundState() == ROUND_POST then
                -- At the end of the round, display everyone's role
                local role = ply:GetRole()
                roleColour = colourTable[role]
                iconRole = role
            elseif ply == LocalPlayer() or ply:GetNWInt("RoleOverlayScoreboardRoleRevealed", -1) ~= -1 or ply:GetNWBool("RoleOverlayIsGoodDetectiveLike") or (ply.IsLootGoblin and ply:IsLootGoblin() and ply:IsRoleActive() and GetGlobalInt("ttt_lootgoblin_announce") == 4) or (ply.IsTurncoat and ply:IsTurncoat() and ply:IsTraitorTeam()) or ply.IsBeggar and ply:IsBeggar() and ply:ShouldRevealBeggar() then
                -- Reveal yourself, searched players, detectives (when their roles aren't hidden) to everyone, loot goblins (when they are shown to everyone), revealed turncoats and revealed beggars
                local role = ply:GetRole()

                if roleIcons then
                    iconRole = role
                end

                if ply:GetNWInt("RoleOverlayScoreboardRoleRevealed", -1) ~= -1 then
                    role = ply:GetNWInt("RoleOverlayScoreboardRoleRevealed", -1)
                    iconRole = ply:GetNWInt("RoleOverlayScoreboardRoleRevealed", -1)
                elseif ply:GetNWBool("RoleOverlayIsGoodDetectiveLike") and GetGlobalInt("ttt_detective_hide_special_mode", 0) ~= 0 then
                    role = ROLE_DETECTIVE
                end

                roleColour = colourTable[role]

                if roleIcons and role == ROLE_DETECTIVE and (GetGlobalInt("ttt_detective_hide_special_mode", 0) == 1 or (GetGlobalInt("ttt_detective_hide_special_mode", 0) == 2 and ply ~= LocalPlayer())) then
                    iconRole = ROLE_NONE
                end
            elseif LocalPlayer():GetNWBool("RoleOverlayTraitor") and ply:GetNWBool("RoleOverlayTraitor") and not (LocalPlayer().IsGlitch and LocalPlayer():IsGlitch()) then
                -- Reveal fellow traitors as plain traitors until they're searched, when there is a glitch
                if GetGlobalBool("RoleOverlayGlitchExists") then
                    roleColour = colourTable[ROLE_TRAITOR]

                    if roleIcons then
                        iconRole = ROLE_TRAITOR
                    end
                else
                    roleColour = colourTable[ply:GetRole()]

                    if roleIcons then
                        iconRole = ply:GetRole()
                    end
                end
            elseif (ply:GetNWBool("RoleOverlayIsDetectiveLike") and ply:GetNWBool("HasPromotion")) or (ply:GetNWBool("RoleOverlayIsGoodDetectiveLike") and GetGlobalInt("ttt_detective_hide_special_mode", 0) == 1) then
                -- Reveal promoted detective-like players like the impersonator, or special detectives while the hide convar is on, as ordinary detectives
                roleColour = colourTable[ROLE_DETECTIVE]

                if roleIcons then
                    iconRole = ROLE_NONE
                end
            elseif LocalPlayer():GetNWBool("RoleOverlayTraitor") and ply:GetNWBool("RoleOverlayJester") and not (LocalPlayer().IsGlitch and LocalPlayer():IsGlitch()) then
                -- Reveal jesters only to traitors
                roleColour = colourTable[ply:GetRole()]

                if roleIcons then
                    iconRole = ROLE_NONE
                end
            end

            -- Grabbing the name of the player again if they don't have a name yet, but were connected enough to the server to be given an overlay position
            if not playerNames[ply] then
                playerNames[ply] = ply:Nick()
            end

            -- But if the player still doesn't have a name yet, skip them
            if not playerNames[ply] then continue end
            -- Box and player name
            local boxWidth = WordBox(boxBorderSize, XPos, YPos, playerNames[ply], "RoleOverlayFont", roleColour, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if not boxWidths[ply] then
                boxWidths[ply] = boxWidth
            end

            -- Role icons
            if iconRole then
                surface.SetMaterial(roleIcons[iconRole])
                surface.SetDrawColor(255, 255, 255)
                surface.DrawTexturedRect(XPos - iconSize / 2, iconSize / 6, iconSize, iconSize)
            end

            -- Death X
            if ply:GetNWBool("RoleOverlayCrossName") or (GetRoundState() == ROUND_POST and ply:IsSpec() and not ply:Alive()) then
                -- You have to set the font using surface.SetFont() to use surface.GetTextSize(), even though surface.SetFont() is not used for any drawing
                surface.SetFont("RoleOverlayFont")
                local textWidth, _ = surface.GetTextSize(playerNames[ply])
                draw.NoTexture()
                surface.SetDrawColor(255, 255, 255)
                surface.DrawTexturedRectRotated(XPos, YPos, textWidth + 1, 6, 30)
                surface.DrawTexturedRectRotated(XPos, YPos, textWidth + 1, 6, -30)
                surface.SetDrawColor(255, 0, 0)
                surface.DrawTexturedRectRotated(XPos, YPos, textWidth, 5, 30)
                surface.DrawTexturedRectRotated(XPos, YPos, textWidth, 5, -30)
            end
        end
    end)
end

-- Displays the role overlay
net.Receive("RoleOverlayPopup", CreateOverlay)