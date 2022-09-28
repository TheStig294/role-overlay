local function GetAlivePlayers()
    local alivePlys = {}

    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() and not ply:IsSpec() then
            table.insert(alivePlys, ply)
        end
    end

    return alivePlys
end

local function IsInnocentTeam(ply, skip_detective)
    local ROLE_GLITCH = ROLE_GLITCH or -1
    local ROLE_PHANTOM = ROLE_PHANTOM or -1
    local ROLE_MERCENARY = ROLE_MERCENARY or -1
    -- Handle this early because IsInnocentTeam doesn't
    if skip_detective and IsGoodDetectiveLike(ply) then return false end
    if ply.IsInnocentTeam then return ply:IsInnocentTeam() end
    local role = ply:GetRole()

    return role == ROLE_DETECTIVE or role == ROLE_INNOCENT or role == ROLE_MERCENARY or role == ROLE_PHANTOM or role == ROLE_GLITCH
end

local function IsTraitorTeam(ply, skip_evil_detective)
    local ROLE_DETRAITOR = ROLE_DETRAITOR or -1
    local ROLE_HYPNOTIST = ROLE_HYPNOTIST or -1
    local ROLE_ASSASSIN = ROLE_ASSASSIN or -1
    -- Handle this early because IsTraitorTeam doesn't
    if skip_evil_detective and IsEvilDetectiveLike(ply) then return false end
    if player.IsTraitorTeam then return player.IsTraitorTeam(ply) end
    if ply.IsTraitorTeam then return ply:IsTraitorTeam() end
    local role = ply:GetRole()

    return role == ROLE_TRAITOR or role == ROLE_HYPNOTIST or role == ROLE_ASSASSIN or role == ROLE_DETRAITOR
end

local function IsJesterTeam(ply)
    if ply.IsJesterTeam then return ply:IsJesterTeam() end
    local role = ply:GetRole()

    return role == ROLE_JESTER or role == ROLE_SWAPPER
end

local function IsDetectiveLike(ply)
    local ROLE_DETRAITOR = ROLE_DETRAITOR or -1
    if ply.IsDetectiveLike then return ply:IsDetectiveLike() end
    local role = ply:GetRole()

    return role == ROLE_DETECTIVE or role == ROLE_DETRAITOR
end

local function IsEvilDetectiveLike(ply)
    local role = ply:GetRole()

    return role == ROLE_DETRAITOR or (IsDetectiveLike(ply) and IsTraitorTeam(ply))
end

local function IsGoodDetectiveLike(ply)
    local role = ply:GetRole()

    return role == ROLE_DETECTIVE or (IsDetectiveLike(ply) and IsInnocentTeam(ply))
end

util.AddNetworkString("StigRoleOverlayPopup")
util.AddNetworkString("StigRoleOverlayCreateOverlay")
util.AddNetworkString("StigRoleOverlayEnd")

hook.Add("TTTBeginRound", "StigRoleOverlayBegin", function()
    local ROLE_GLITCH = ROLE_GLITCH or -1

    -- Sets flags on players using randomat functions only available on the server
    for _, ply in ipairs(GetAlivePlayers()) do
        if IsGoodDetectiveLike(ply) then
            ply:SetNWBool("StigRoleOverlayIsGoodDetectiveLike", true)
            ply:SetNWBool("StigRoleOverlayIsDetectiveLike", true)
        elseif IsEvilDetectiveLike(ply) then
            ply:SetNWBool("StigRoleOverlayTraitor", true)
            ply:SetNWBool("StigRoleOverlayIsDetectiveLike", true)
        elseif IsDetectiveLike(ply) then
            ply:SetNWBool("StigRoleOverlayIsDetectiveLike", true)
        elseif IsJesterTeam(ply) then
            ply:SetNWBool("StigRoleOverlayJester", true)
        elseif IsTraitorTeam(ply) or (ROLE_GLITCH and ply:GetRole() == ROLE_GLITCH) then
            ply:SetNWBool("StigRoleOverlayTraitor", true)
        end

        if ROLE_GLITCH and ply:GetRole() == ROLE_GLITCH then
            SetGlobalBool("StigRoleOverlayGlitchExists", true)
        end
    end

    -- Reveals the role of a player when a corpse is searched
    hook.Add("TTTCanIdentifyCorpse", "StigRoleOverlayCorpseSearch", function(_, ragdoll)
        local ply = CORPSE.GetPlayer(ragdoll)
        ply:SetNWInt("StigRoleOverlayScoreboardRoleRevealed", ragdoll.was_role)
    end)

    -- Starts fading in the role overlay and displays the event's name without making the randomat alert sound
    timer.Create("StigRoleOverlayDrawOverlay", 3.031, 1, function()
        net.Start("StigRoleOverlayCreateOverlay")
        net.Broadcast()
    end)
end)

hook.Add("TTTEndRound", "StigRoleOverlayEnd", function()
    -- Removes all popups on the screen
    timer.Remove("StigRoleOverlayDrawOverlay")
    net.Start("StigRoleOverlayEnd")
    net.Broadcast()

    -- Removes all flags set
    for _, ply in ipairs(player.GetAll()) do
        ply:SetNWBool("StigRoleOverlayIsDetectiveLike", false)
        ply:SetNWBool("StigRoleOverlayIsGoodDetectiveLike", false)
        ply:SetNWBool("StigRoleOverlayJester", false)
        ply:SetNWBool("StigRoleOverlayTraitor", false)
        ply:SetNWBool("StigRoleOverlayScoreboardRoleRevealed", -1)
    end

    SetGlobalBool("StigRoleOverlayGlitchExists", false)
end)