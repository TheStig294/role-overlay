local overlayPositions = {}
local YPos = 50
local alpha = 0
local iconSize = 32
local playerNames = {}

surface.CreateFont("StigRoleOverlayOverlayFont", {
    font = "Trebuchet24",
    size = 24,
    weight = 1000
})

CreateClientConVar("ttt_role_overlay_active", "1", true, false, "Whether to show a role overlay during a round of TTT", 0, 1)
local overlayActive = GetConVar("ttt_role_overlay_active"):GetBool()

hook.Add("TTTPrepareRound", "StigSetRoleOverlayState", function()
    overlayActive = GetConVar("ttt_role_overlay_active"):GetBool()
end)

local pressedTab = false
local shownMessage = false

-- Makes the scoreboard button a toggle for the role overlay when double pressed
hook.Add("PlayerBindPress", "StigRoleOverlayToggle", function(ply, bind, pressed, code)
    if bind == "+showscores" then
        if pressedTab then
            overlayActive = GetConVar("ttt_role_overlay_active"):GetBool()

            if overlayActive == false then
                RunConsoleCommand("ttt_role_overlay_active", "1")
                overlayActive = true
                chat.AddText("Role overlay enabled")
            else
                RunConsoleCommand("ttt_role_overlay_active", "0")
                overlayActive = false
                chat.AddText("Role overlay disabled")
            end
        else
            if not shownMessage then
                chat.AddText(COLOR_GREEN, "Double press '" .. string.upper(input.GetKeyName(code)) .. "' to toggle role overlay")
                shownMessage = true
            end

            pressedTab = true

            timer.Create("StigRoleOverlayDoublePress", 1, 1, function()
                pressedTab = false
            end)
        end
    end
end)

-- Creates the table of players to be displayed in the role overlay
net.Receive("StigRoleOverlayCreateOverlay", function()
    local playerCount = 0
    local screenWidth = ScrW()

    -- Grabbing player names and the number of them
    for _, ply in ipairs(player.GetAll()) do
        playerCount = playerCount + 1
        playerNames[ply] = ply:Nick()
    end

    -- The magic formula for getting the correct x-coordinates of where each overlay box should be
    -- This is used for getting centred positions of many objects on the screen in a row for HUDs
    -- Sorry for this being a bit of a magic number... took a lot of thought to come up with this formula
    -- Probably would've been faster to google this since I'm probably not the only person to have had this problem to solve, oh well...
    for playerIndex, ply in ipairs(player.GetAll()) do
        overlayPositions[ply] = (playerIndex * screenWidth) / (playerCount + 1)
    end

    -- Fallback colours to use
    local colourTable = {
        [ROLE_INNOCENT] = Color(25, 200, 25, 200),
        [ROLE_TRAITOR] = Color(200, 25, 25, 200),
        [ROLE_DETECTIVE] = Color(25, 25, 200, 200)
    }

    local ROLE_COLORS = ROLE_COLORS or colourTable
    -- Getting the icons for every role if Custom Roles for TTT is installed
    local roleIcons = nil

    if ROLE_STRINGS_SHORT then
        roleIcons = {}

        for roleID, shortName in pairs(ROLE_STRINGS_SHORT) do
            if file.Exists("materials/vgui/ttt/roles/" .. shortName .. "/score_" .. shortName .. ".png", "GAME") then
                roleIcons[roleID] = Material("vgui/ttt/roles/" .. shortName .. "/score_" .. shortName .. ".png")
            else
                roleIcons[roleID] = Material("vgui/ttt/score_" .. shortName .. ".png")
            end
        end
    end

    local defaultColour = Color(100, 100, 100)
    alpha = 0

    timer.Create("StigRoleOverlayFadeIn", 0.01, 100, function()
        alpha = alpha + 0.01
    end)

    local ROLE_GLITCH = ROLE_GLITCH or -1

    hook.Add("DrawOverlay", "StigRoleOverlayDrawNameOverlay", function()
        if not overlayActive then return end
        surface.SetAlphaMultiplier(alpha)

        for ply, XPos in SortedPairsByValue(overlayPositions) do
            if not IsPlayer(ply) then continue end
            local roleColour = defaultColour
            local iconRole

            -- Reveal yourself, searched players, and detectives (when their roles aren't hidden) to everyone
            if ply == LocalPlayer() or ply:GetNWInt("StigRoleOverlayScoreboardRoleRevealed", -1) ~= -1 or (ply:GetNWBool("StigRoleOverlayIsGoodDetectiveLike") and GetGlobalInt("ttt_detective_hide_special_mode", 0) == 0) then
                local role = ply:GetRole()

                if ply:GetNWInt("StigRoleOverlayScoreboardRoleRevealed", -1) ~= -1 then
                    role = ply:GetNWInt("StigRoleOverlayScoreboardRoleRevealed", -1)
                end

                roleColour = ROLE_COLORS[role]

                if roleIcons then
                    iconRole = role
                end
                -- Reveal fellow traitors as plain traitors until they're searched, when there is a glitch
            elseif LocalPlayer():GetNWBool("StigRoleOverlayTraitor") and ply:GetNWBool("StigRoleOverlayTraitor") and LocalPlayer():GetRole() ~= ROLE_GLITCH then
                if GetGlobalBool("StigRoleOverlayGlitchExists") then
                    roleColour = ROLE_COLORS[ROLE_TRAITOR]

                    if roleIcons then
                        iconRole = ROLE_TRAITOR
                    end
                else
                    roleColour = ROLE_COLORS[ply:GetRole()]

                    if roleIcons then
                        iconRole = ply:GetRole()
                    end
                end
            elseif (ply:GetNWBool("StigRoleOverlayIsDetectiveLike") and ply:GetNWBool("HasPromotion")) or (ply:GetNWBool("StigRoleOverlayIsGoodDetectiveLike") and GetGlobalInt("ttt_detective_hide_special_mode", 0) == 1) then
                -- Reveal promoted detective-like players like the impersonator, or special detectives while the hide convar is on, as ordinary detectives
                roleColour = ROLE_COLORS[ROLE_DETECTIVE]

                if roleIcons then
                    iconRole = ROLE_DETECTIVE
                end
            elseif LocalPlayer():GetNWBool("StigRoleOverlayTraitor") and ply:GetNWBool("StigRoleOverlayJester") and LocalPlayer():GetRole() ~= ROLE_GLITCH then
                -- Reveal jesters only to traitors
                roleColour = ROLE_COLORS[ply:GetRole()]

                if roleIcons then
                    iconRole = ROLE_JESTER
                end
            end

            -- Grabbing the name of the player again if they don't have a name yet, but were connected enough to the server to be given an overlay position
            if not playerNames[ply] then
                playerNames[ply] = ply:Nick()
            end

            -- But if the player still doesn't have a name yet, skip them
            if not playerNames[ply] then continue end
            -- Box and player name
            draw.WordBox(16, XPos, YPos, playerNames[ply], "StigRoleOverlayOverlayFont", roleColour, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Role icons
            if iconRole then
                surface.SetMaterial(roleIcons[iconRole])
                surface.SetDrawColor(255, 255, 255)
                surface.DrawTexturedRect(XPos - iconSize / 2, iconSize / 6, iconSize, iconSize)
            end

            -- Death X
            if ply:GetNWInt("StigRoleOverlayScoreboardRoleRevealed", -1) ~= -1 then
                -- You have to set the font using surface.SetFont() to use surface.GetTextSize(), even though surface.SetFont() is not used for any drawing
                surface.SetFont("StigRoleOverlayOverlayFont")
                local textWidth, textHeight = surface.GetTextSize(playerNames[ply])
                surface.SetDrawColor(255, 255, 255)
                surface.DrawLine(XPos - (textWidth / 2), YPos - (textHeight / 2), XPos + (textWidth / 2), YPos + (textHeight / 2))
                surface.DrawLine(XPos - (textWidth / 2), YPos + (textHeight / 2), XPos + (textWidth / 2), YPos - (textHeight / 2))
            end
        end
    end)
end)

-- Cleans up everything and slowly fades out the overlay
net.Receive("StigRoleOverlayEnd", function()
    timer.Remove("StigRoleOverlayFadeIn")

    timer.Create("StigRoleOverlayFadeOut", 0.01, 100, function()
        alpha = alpha - 0.01

        if timer.RepsLeft("StigRoleOverlayFadeOut") == 0 then
            hook.Remove("DrawOverlay", "StigRoleOverlayDrawNameOverlay")
        end
    end)
end)