STIG_ROLE_OVERLAY_MOD_INSTALLED = true

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

local function SetRoleFlags()
    for _, ply in ipairs(GetAlivePlayers()) do
        ply:SetNWBool("RoleOverlayIsDetectiveLike", false)
        ply:SetNWBool("RoleOverlayIsGoodDetectiveLike", false)
        ply:SetNWBool("RoleOverlayJester", false)
        ply:SetNWBool("RoleOverlayTraitor", false)
    end

    for _, ply in ipairs(GetAlivePlayers()) do
        if IsGoodDetectiveLike(ply) then
            ply:SetNWBool("RoleOverlayIsGoodDetectiveLike", true)
            ply:SetNWBool("RoleOverlayIsDetectiveLike", true)
        elseif IsEvilDetectiveLike(ply) then
            ply:SetNWBool("RoleOverlayTraitor", true)
            ply:SetNWBool("RoleOverlayIsDetectiveLike", true)
        elseif IsDetectiveLike(ply) then
            ply:SetNWBool("RoleOverlayIsDetectiveLike", true)
        elseif IsJesterTeam(ply) then
            ply:SetNWBool("RoleOverlayJester", true)
        elseif IsTraitorTeam(ply) or ply.IsGlitch and ply:IsGlitch() then
            ply:SetNWBool("RoleOverlayTraitor", true)
        end

        if ply.IsGlitch and ply:IsGlitch() then
            SetGlobalBool("RoleOverlayGlitchExists", true)
        end
    end
end

util.AddNetworkString("RoleOverlayPopup")
util.AddNetworkString("RoleOverlayEnd")

hook.Add("TTTBeginRound", "RoleOverlayBegin", function()
    -- Puts the role overlay on the screen for all players
    net.Start("RoleOverlayPopup")
    net.Broadcast()

    if CR_VERSION then
        SetGlobalInt("ttt_lootgoblin_announce", GetConVar("ttt_lootgoblin_announce"):GetInt())
        SetGlobalInt("ttt_lootgoblin_notify_mode", GetConVar("ttt_lootgoblin_notify_mode"):GetInt())
    end

    SetRoleFlags()

    -- Continually checks for players' roles, in case roles change
    timer.Create("RoleOverlayCheckRoleChange", 1, 0, function()
        SetRoleFlags()
    end)
end)

-- Reveals the role of a player when a corpse is searched
hook.Add("TTTBodyFound", "RoleOverlayCorpseSearch", function(_, deadply, rag)
    -- If the dead player has disconnected, they won't be on the scoreboard, so skip them
    if not IsPlayer(deadply) then return end
    -- Get the role of the dead player from the ragdoll itself so artificially created ragdolls like the dead ringer aren't given away
    deadply:SetNWBool("RoleOverlayCrossName", true)
end)

-- Reveals the role of a player when a corpse is searched
hook.Add("TTTCanIdentifyCorpse", "RoleOverlayCorpseSearch", function(_, ragdoll)
    local ply = CORPSE.GetPlayer(ragdoll)
    -- If the dead player has disconnected, they won't be on the scoreboard, so skip them
    if not IsPlayer(ply) then return end
    ply:SetNWInt("RoleOverlayScoreboardRoleRevealed", ragdoll.was_role)
end)

-- Reveals the loot goblin's death to everyone if it is announced
hook.Add("PostPlayerDeath", "RoleOverlayDeath", function(ply)
    if ply.IsLootGoblin and ply:IsLootGoblin() and ply:IsRoleActive() and GetGlobalInt("ttt_lootgoblin_notify_mode") == 4 then
        ply:SetNWBool("RoleOverlayCrossName", true)
        ply:SetNWInt("RoleOverlayScoreboardRoleRevealed", ply:GetRole())
    end
end)

hook.Add("TTTPrepareRound", "RoleOverlayEnd", function()
    -- Removes all flags set
    for _, ply in ipairs(player.GetAll()) do
        ply:SetNWBool("RoleOverlayIsDetectiveLike", false)
        ply:SetNWBool("RoleOverlayIsGoodDetectiveLike", false)
        ply:SetNWBool("RoleOverlayJester", false)
        ply:SetNWBool("RoleOverlayTraitor", false)
        ply:SetNWInt("RoleOverlayScoreboardRoleRevealed", -1)
        ply:SetNWBool("RoleOverlayCrossName", false)
    end

    SetGlobalBool("RoleOverlayGlitchExists", false)
end)