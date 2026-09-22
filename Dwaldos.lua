--========================================================
-- DWALDOS
--========================================================

local ADDON_NAME = ...

------------------------------------------------------------
-- Saved Variables / Defaults
------------------------------------------------------------

local defaults = {
    enabled = true,

    -- Change these to the actual character names.
    donaldName = "Donald",
    wintonName = "Winton",

    dwaldo1 = "Vynaraz",
    dwaldo2 = "Robs",
    dwaldo3 = "Dwaldo",

    vynarazName = "Vynaraz",

    -- Daily Vynaraz reminder.
    dailyReminder = true,

    -- Show Sal over the player portrait.
    salPortrait = true,
}

local db

------------------------------------------------------------
-- Initialize Saved Variables
------------------------------------------------------------

local function InitializeDB()
    if not DwaldosDB then
        DwaldosDB = {}
    end

    db = DwaldosDB

    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = value
        end
    end
end

------------------------------------------------------------
-- Sound Files
------------------------------------------------------------

local function AddonFile(relativePath)
    return "Interface\\AddOns\\" .. ADDON_NAME .. "\\" .. relativePath
end

local SOUND_WINTON = AddonFile("Sounds\\winton.ogg")
local SOUND_73 = AddonFile("Sounds\\73_laugh.ogg")
local SOUND_WHAAAAT = AddonFile("Sounds\\whaaaat.ogg")
local SOUND_GANGS = AddonFile("Sounds\\gangs_all_here.ogg")
local SOUND_SLOT = AddonFile("Sounds\\slot_machine.ogg")
local TEXTURE_SAL = AddonFile("sal.tga")

------------------------------------------------------------
-- Sound Helper
------------------------------------------------------------

local function PlayDwaldosSound(soundFile)
    if not db or not db.enabled then
        return
    end

    PlaySoundFile(soundFile, "Master")
end

local function ShowRaidNotice(text)
    if RaidNotice_AddMessage and RaidWarningFrame then
        local color = ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]

        pcall(
            RaidNotice_AddMessage,
            RaidWarningFrame,
            text,
            color
        )
    end
end

------------------------------------------------------------
-- Name Helpers
------------------------------------------------------------

local function ShortName(name)
    if not name then
        return nil
    end

    if Ambiguate then
        return Ambiguate(name, "none")
    end

    return strmatch(name, "^([^-]+)") or name
end

local function NameMatches(name, targetName)
    if not name or not targetName or targetName == "" then
        return false
    end

    name = ShortName(name)

    return strlower(name) == strlower(targetName)
end

------------------------------------------------------------
-- Check whether a character is currently in the group
------------------------------------------------------------

local function IsCharacterInGroup(targetName)
    if not targetName or targetName == "" then
        return false
    end

    -- Player.
    local playerName = UnitName("player")

    if NameMatches(playerName, targetName) then
        return true
    end

    if not IsInGroup() then
        return false
    end

    local memberCount = GetNumGroupMembers()

    for i = 1, memberCount do
        local unit

        if IsInRaid() then
            unit = "raid" .. i
        else
            unit = "party" .. i
        end

        if UnitExists(unit) then
            local name = GetUnitName(unit, true)

            if NameMatches(name, targetName) then
                return true
            end
        end
    end

    return false
end

------------------------------------------------------------
-- Get Current Group Members
------------------------------------------------------------

local function GetGroupMembers()
    local members = {}

    local playerName = UnitName("player")

    if playerName then
        members[ShortName(playerName)] = true
    end

    if not IsInGroup() then
        return members
    end

    local memberCount = GetNumGroupMembers()

    for i = 1, memberCount do
        local unit

        if IsInRaid() then
            unit = "raid" .. i
        else
            unit = "party" .. i
        end

        if UnitExists(unit) then
            local name = GetUnitName(unit, true)

            if name then
                members[ShortName(name)] = true
            end
        end
    end

    return members
end

------------------------------------------------------------
-- Previous Group State
------------------------------------------------------------

local previousGroup = {}

local function GroupContains(group, targetName)
    if not targetName or targetName == "" then
        return false
    end

    for name in pairs(group) do
        if NameMatches(name, targetName) then
            return true
        end
    end

    return false
end

------------------------------------------------------------
-- Donald Detection
------------------------------------------------------------

local function CheckDonald(previous, current)
    if not db or not db.donaldName or db.donaldName == "" then
        return
    end

    local wasInGroup =
        GroupContains(previous, db.donaldName)

    local isInGroup =
        GroupContains(current, db.donaldName)

    if isInGroup and not wasInGroup then
        PlayDwaldosSound(SOUND_WHAAAAT)

        print(
            "|cff00ccffDwaldos:|r WHAAAAAT?!"
        )
    end
end

------------------------------------------------------------
-- Winton Detection
------------------------------------------------------------

local function CheckWinton(previous, current)
    if not db or not db.wintonName or db.wintonName == "" then
        return
    end

    local wasInGroup =
        GroupContains(previous, db.wintonName)

    local isInGroup =
        GroupContains(current, db.wintonName)

    if isInGroup and not wasInGroup then
        PlayDwaldosSound(SOUND_WINTON)

        print(
            "|cff00ccffDwaldos:|r Winton has arrived."
        )
    end
end

------------------------------------------------------------
-- The Three Dwaldos
------------------------------------------------------------

local dwaldosAnnouncementActive = false

local function CheckAllDwaldos()
    if not db then
        return
    end

    if not IsInGroup() then
        dwaldosAnnouncementActive = false
        return
    end

    local first =
        IsCharacterInGroup(db.dwaldo1)

    local second =
        IsCharacterInGroup(db.dwaldo2)

    local third =
        IsCharacterInGroup(db.dwaldo3)

    local everyoneIsHere =
        first and second and third

    if everyoneIsHere and not dwaldosAnnouncementActive then
        dwaldosAnnouncementActive = true

        PlayDwaldosSound(SOUND_GANGS)

        ShowRaidNotice("GANGS ALL HERE!")

        print(
            "|cff00ff00Dwaldos:|r GANGS ALL HERE!"
        )

    elseif not everyoneIsHere then
        dwaldosAnnouncementActive = false
    end
end

------------------------------------------------------------
-- /ROLL Detection
------------------------------------------------------------

local function HandleRollMessage(message)
    if not message then
        return
    end

    -- Examples of Blizzard's roll messages:
    --
    -- Player rolls 72 (1-100)
    -- Player rolls 100 (1-100)
    --
    -- We look for "rolls" and a number.

    local hasRollWord =
        message:find("rolls")

    local hasRollRange =
        message:find("%(%d+%-%d+%)")

    if hasRollWord and hasRollRange then
        PlayDwaldosSound(SOUND_SLOT)
    end
end

------------------------------------------------------------
-- Player Death
------------------------------------------------------------

local function HandlePlayerDeath()
    PlayDwaldosSound(SOUND_73)
end

------------------------------------------------------------
-- Master Loot
------------------------------------------------------------

local lastLootMethod = nil

local function GetCurrentLootMethod()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        local method = C_PartyInfo.GetLootMethod()

        if Enum and Enum.LootMethod and method == Enum.LootMethod.Masterlooter then
            return "master"
        end

        if method == 2 then
            return "master"
        end

        return method
    end

    if GetLootMethod then
        local method = GetLootMethod()

        if method == "master" then
            return "master"
        end

        return method
    end

    return nil
end

local function CheckLootMethod()
    if not db or not db.enabled then
        return
    end

    local method = GetCurrentLootMethod()

    if method ~= lastLootMethod then
        if method == "master" then
            ShowRaidNotice("SNAGGED YOUR LOOT!")

            print(
                "|cffff8000Dwaldos:|r SNAGGED YOUR LOOT!"
            )
        end

        lastLootMethod = method
    end
end

------------------------------------------------------------
-- Daily Vynaraz Reminder
------------------------------------------------------------

local function DoDailyReminder()
    if not db or not db.dailyReminder then
        return
    end

    if not db.vynarazName or db.vynarazName == "" then
        return
    end

    local today = date("%Y-%m-%d")

    if DwaldosDB.lastReminderDate == today then
        return
    end

    DwaldosDB.lastReminderDate = today

    print(
        "|cffffd700Dwaldos Daily Reminder:|r "
        .. db.vynarazName
        .. " got Ashes AND the Headless Horseman mount in the same day!"
    )
end

------------------------------------------------------------
-- Sal Player Portrait
------------------------------------------------------------

local PORTRAIT_MASK =
    "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function GetPlayerPortraitTexture()
    if PlayerFrame
        and PlayerFrame.PlayerFrameContainer
        and PlayerFrame.PlayerFrameContainer.PlayerPortrait then

        return PlayerFrame.PlayerFrameContainer.PlayerPortrait,
            PlayerFrame.PlayerFrameContainer
    end

    if PlayerFrame and PlayerFrame.portrait then
        return PlayerFrame.portrait, PlayerFrame
    end

    if PlayerPortrait then
        return PlayerPortrait, PlayerPortrait:GetParent()
    end
end

local function SetDefaultPortraitHidden(hidden)
    local portrait = GetPlayerPortraitTexture()

    if not portrait then
        return
    end

    if hidden then
        portrait:SetAlpha(0)
    else
        portrait:SetAlpha(1)
    end
end

local function CreateSalPortrait()
    if not db then
        return
    end

    local portrait, container = GetPlayerPortraitTexture()

    if not portrait or not container then
        return
    end

    local texture = container.DwaldosSalPortrait

    if not texture then
        -- Draw under FrameTexture so the unit-frame chrome sits on top
        -- of Sal, same as the default character portrait.
        texture = container:CreateTexture(
            nil,
            "BACKGROUND",
            nil,
            -1
        )

        texture:SetAllPoints(portrait)
        texture:SetTexture(TEXTURE_SAL)

        local mask = container:CreateMaskTexture()
        mask:SetAllPoints(portrait)
        mask:SetTexture(
            PORTRAIT_MASK,
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE"
        )
        texture:AddMaskTexture(mask)

        container.DwaldosSalPortrait = texture
        texture.mask = mask
    else
        texture:ClearAllPoints()
        texture:SetAllPoints(portrait)
    end

    if db.salPortrait then
        texture:Show()
        SetDefaultPortraitHidden(true)
    else
        texture:Hide()
        SetDefaultPortraitHidden(false)
    end
end

if hooksecurefunc then
    hooksecurefunc("SetPortraitTexture", function(texture)
        if not db or not db.salPortrait then
            return
        end

        local portrait = GetPlayerPortraitTexture()

        if texture == portrait then
            texture:SetAlpha(0)
        end
    end)
end

------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------

SLASH_DWALDOS1 = "/dwaldos"
SLASH_DWALDOS2 = "/dw"

SlashCmdList["DWALDOS"] = function(message)
    if not db then
        InitializeDB()
    end

    message = message or ""

    local command, value =
        message:match("^(%S+)%s*(.-)$")

    command = command and command:lower() or ""
    value = value or ""

    --------------------------------------------------------
    -- Enable
    --------------------------------------------------------

    if command == "on" then

        db.enabled = true

        print(
            "|cff00ff00Dwaldos enabled.|r"
        )

    --------------------------------------------------------
    -- Disable
    --------------------------------------------------------

    elseif command == "off" then

        db.enabled = false

        print(
            "|cffff0000Dwaldos disabled.|r"
        )

    --------------------------------------------------------
    -- Donald
    --------------------------------------------------------

    elseif command == "donald" then

        if value == "" then
            print(
                "Donald is currently set to: "
                .. tostring(db.donaldName)
            )
        else
            db.donaldName = value

            print(
                "Dwaldos: Donald set to "
                .. value
            )
        end

    --------------------------------------------------------
    -- Winton
    --------------------------------------------------------

    elseif command == "winton" then

        if value == "" then
            print(
                "Winton is currently set to: "
                .. tostring(db.wintonName)
            )
        else
            db.wintonName = value

            print(
                "Dwaldos: Winton set to "
                .. value
            )
        end

    --------------------------------------------------------
    -- Dwaldo #1
    --------------------------------------------------------

    elseif command == "dwaldo1" then

        if value == "" then
            print(
                "Dwaldo #1: "
                .. tostring(db.dwaldo1)
            )
        else
            db.dwaldo1 = value

            print(
                "Dwaldos: Dwaldo #1 set to "
                .. value
            )

            dwaldosAnnouncementActive = false
        end

    --------------------------------------------------------
    -- Dwaldo #2
    --------------------------------------------------------

    elseif command == "dwaldo2" then

        if value == "" then
            print(
                "Dwaldo #2: "
                .. tostring(db.dwaldo2)
            )
        else
            db.dwaldo2 = value

            print(
                "Dwaldos: Dwaldo #2 set to "
                .. value
            )

            dwaldosAnnouncementActive = false
        end

    --------------------------------------------------------
    -- Dwaldo #3
    --------------------------------------------------------

    elseif command == "dwaldo3" then

        if value == "" then
            print(
                "Dwaldo #3: "
                .. tostring(db.dwaldo3)
            )
        else
            db.dwaldo3 = value

            print(
                "Dwaldos: Dwaldo #3 set to "
                .. value
            )

            dwaldosAnnouncementActive = false
        end

    --------------------------------------------------------
    -- Vynaraz
    --------------------------------------------------------

    elseif command == "vynaraz" then

        if value == "" then
            print(
                "Vynaraz is currently set to: "
                .. tostring(db.vynarazName)
            )
        else
            db.vynarazName = value

            print(
                "Dwaldos: Vynaraz set to "
                .. value
            )
        end

    --------------------------------------------------------
    -- Daily reminder
    --------------------------------------------------------

    elseif command == "reminder" then

        local setting = value:lower()

        if setting == "on" then
            db.dailyReminder = true

            print(
                "Dwaldos daily reminder enabled."
            )

        elseif setting == "off" then
            db.dailyReminder = false

            print(
                "Dwaldos daily reminder disabled."
            )

        else
            print(
                "/dw reminder on"
            )

            print(
                "/dw reminder off"
            )
        end

    --------------------------------------------------------
    -- Sal portrait
    --------------------------------------------------------

    elseif command == "sal" then

        local setting = value:lower()

        if setting == "on" then
            db.salPortrait = true

            CreateSalPortrait()

            print(
                "Dwaldos: Sal portrait enabled."
            )

        elseif setting == "off" then
            db.salPortrait = false

            CreateSalPortrait()

            print(
                "Dwaldos: Sal portrait disabled."
            )

        else
            print(
                "/dw sal on"
            )

            print(
                "/dw sal off"
            )
        end

    --------------------------------------------------------
    -- Sound tests
    --------------------------------------------------------

    elseif command == "test" then

        local sound = value:lower()

        if sound == "winton" then

            PlayDwaldosSound(
                SOUND_WINTON
            )

            print(
                "Dwaldos: Testing Winton sound."
            )

        elseif sound == "73" then

            PlayDwaldosSound(
                SOUND_73
            )

            print(
                "Dwaldos: Testing 73 laugh."
            )

        elseif sound == "donald" then

            PlayDwaldosSound(
                SOUND_WHAAAAT
            )

            print(
                "Dwaldos: Testing Donald sound."
            )

        elseif sound == "gangs" then

            PlayDwaldosSound(
                SOUND_GANGS
            )

            print(
                "Dwaldos: Testing Gangs All Here."
            )

        elseif sound == "slot" then

            PlayDwaldosSound(
                SOUND_SLOT
            )

            print(
                "Dwaldos: Testing slot machine."
            )

        else

            print(
                "Available tests:"
            )

            print(
                "/dw test winton"
            )

            print(
                "/dw test 73"
            )

            print(
                "/dw test donald"
            )

            print(
                "/dw test gangs"
            )

            print(
                "/dw test slot"
            )
        end

    --------------------------------------------------------
    -- Manual gang check
    --------------------------------------------------------

    elseif command == "check" then

        CheckAllDwaldos()

        print(
            "Dwaldos: Checking group..."
        )

    --------------------------------------------------------
    -- Help
    --------------------------------------------------------

    else

        print(
            "|cff00ccff===== DWALDOS =====|r"
        )

        print(
            "/dw on - Enable addon"
        )

        print(
            "/dw off - Disable addon"
        )

        print(
            "/dw donald NAME"
        )

        print(
            "/dw winton NAME"
        )

        print(
            "/dw dwaldo1 NAME"
        )

        print(
            "/dw dwaldo2 NAME"
        )

        print(
            "/dw dwaldo3 NAME"
        )

        print(
            "/dw vynaraz NAME"
        )

        print(
            "/dw reminder on/off"
        )

        print(
            "/dw sal on/off"
        )

        print(
            "/dw check"
        )

        print(
            "/dw test winton"
        )

        print(
            "/dw test 73"
        )

        print(
            "/dw test donald"
        )

        print(
            "/dw test gangs"
        )

        print(
            "/dw test slot"
        )

        print(
            "|cff00ccff===================|r"
        )
    end
end

------------------------------------------------------------
-- Main Event Frame
------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local function RegisterGameEvent(eventName)
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, eventName)

    return ok
end

RegisterGameEvent("ADDON_LOADED")
RegisterGameEvent("PLAYER_LOGIN")
RegisterGameEvent("PLAYER_ENTERING_WORLD")
RegisterGameEvent("GROUP_ROSTER_UPDATE")
RegisterGameEvent("CHAT_MSG_SYSTEM")
RegisterGameEvent("PLAYER_DEAD")
RegisterGameEvent("PARTY_LOOT_METHOD_CHANGED")

eventFrame:SetScript(
    "OnEvent",
    function(self, event, ...)

        ----------------------------------------------------
        -- Addon loaded
        ----------------------------------------------------

        if event == "ADDON_LOADED" then

            local loadedName = ...

            if loadedName == ADDON_NAME then
                InitializeDB()
            end

        ----------------------------------------------------
        -- Login
        ----------------------------------------------------

        elseif event == "PLAYER_LOGIN" then

            if not db then
                InitializeDB()
            end

            previousGroup =
                GetGroupMembers()

            print(
                "|cff00ccffDwaldos|r loaded. Type |cffffff00/dw|r for commands."
            )

            C_Timer.After(
                3,
                function()

                    CreateSalPortrait()

                    CheckAllDwaldos()

                    CheckLootMethod()

                end
            )

        ----------------------------------------------------
        -- Entering world
        ----------------------------------------------------

        elseif event == "PLAYER_ENTERING_WORLD" then

            if not db then
                InitializeDB()
            end

            C_Timer.After(
                5,
                function()

                    DoDailyReminder()

                    CheckAllDwaldos()

                    CreateSalPortrait()

                end
            )

        ----------------------------------------------------
        -- Group changed
        ----------------------------------------------------

        elseif event == "GROUP_ROSTER_UPDATE" then

            if not db then
                return
            end

            local currentGroup =
                GetGroupMembers()

            CheckDonald(
                previousGroup,
                currentGroup
            )

            CheckWinton(
                previousGroup,
                currentGroup
            )

            CheckAllDwaldos()

            previousGroup =
                currentGroup

            C_Timer.After(
                0.1,
                function()
                    CheckLootMethod()
                end
            )

        ----------------------------------------------------
        -- System messages
        ----------------------------------------------------

        elseif event == "CHAT_MSG_SYSTEM" then

            local message = ...

            HandleRollMessage(
                message
            )

        ----------------------------------------------------
        -- Player death
        ----------------------------------------------------

        elseif event == "PLAYER_DEAD" then

            HandlePlayerDeath()

        ----------------------------------------------------
        -- Loot method changed
        ----------------------------------------------------

        elseif event == "PARTY_LOOT_METHOD_CHANGED" then

            C_Timer.After(
                0.1,
                function()
                    CheckLootMethod()
                end
            )
        end
    end
)
