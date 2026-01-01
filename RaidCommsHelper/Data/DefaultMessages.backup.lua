-- RaidCommsHelper Default Messages
-- Edit this file externally for bulk changes, then /reload and click "Load from File"
--
-- AUTO-SYNCED from SavedVariables on: 2025-12-12 09:26:37
--
-- CHAT TYPES: "RAID_WARNING", "RAID", "PARTY"
--
-- PLACEHOLDERS you can use in text:
--   {G1} - {G8}  : Group members by group number
--   {TANKS}      : All tanks
--   {HEALERS}    : All healers
--   {DPS}        : All DPS
--   {target}     : Your current target
--   {focus}      : Your focus target
--   {raidcount}  : Current raid size
--   {skull}, {cross}, {square}, {moon}, {triangle}, {diamond}, {circle}, {star} : Raid icons
--

RCH_DefaultMessages = {    ["General"] = {
        order = 1,
        messages = {
            { name = "Summon Request", text = "if you can get here early, help summon so we can start quickly! (at least 3 going would be nice)", chatType = "RAID_WARNING" },
            { name = "Tour Description", text = "Great Vers & Bronze Farm!! We will assign groups to clear wings fast, regroup for end bosses. --- Please have good awareness and stick with your group --- Loot is mailed, don't run back to bosses...", chatType = "RAID_WARNING" },
            { name = "Check Assignments", text = "check assignments (your group may change)", chatType = "RAID_WARNING" },
            { name = "test", text = "test this is a new message... ading more text to see if it works", chatType = "RAID_WARNING" },
        },
    },

    ["EN"] = {
        order = 2,
        messages = {
            { name = "EN Quick Split", text = "Fast clear -- splitting groups by boss. -- Loot is mailed, don't run back to bosses...", chatType = "RAID_WARNING" },
            { name = "Split Announce!", text = "After Nythendra (1st boss) we will split 3 ways === check assignments (your group may change) ===", chatType = "RAID_WARNING" },
            { name = "Group Assignments", text = "==== G1: {circle} Ursoc | G2: {moon} Dragons | G3: {cross} Spider | G4: {skull} Eye ====\n{circle} G1 Ursoc: {G1}\n{moon} G2 Dragons: {G2}\n{cross} G3 Spider: {G3}\n{skull} G4 Eye: {G4}", chatType = "RAID_WARNING" },
            { name = "Portal Warning", text = "do not enter the portal for Il'gynoth (the eye) unless you are in group 4", chatType = "RAID_WARNING" },
            { name = "Teleport Warning", text = "Dragons or Spider bosses may teleport you to them... it's happened a few times", chatType = "RAID_WARNING" },
            { name = "Rez Warning", text = "Reminder: you can not rez while there is a boss encounter going... we will likely be waiting for the eye to die...", chatType = "RAID_WARNING" },
            { name = "Continue to NH", text = "If you are continuing... those who dont need to check mail and update gear please head to Nighthold and begin clearing trash and summoning.", chatType = "RAID_WARNING" },
        },
    },

    ["NH"] = {
        order = 3,
        messages = {
            { name = "NH Quick Split", text = "Speed run - splitting into 3 groups after Trilliax. Check raid warnings for assignments. -- Loot is mailed, don't run back to bosses...", chatType = "RAID_WARNING" },
            { name = "Krosus Volunteers", text = "Need 3 volunteers to flex for a high DPS group to tackle Krosus (demon on the pier)", chatType = "RAID_WARNING" },
            { name = "First 3 Bosses", text = "First 3 bosses together: Skorpyron -> Anomaly -> Trilliax -- then splitting 3 ways", chatType = "RAID_WARNING" },
            { name = "After Trilliax", text = "After Trilliax we will split 3 ways === check assignments (your group may change) ===", chatType = "RAID_WARNING" },
            { name = "Pause at Stairs", text = "Please pause and regroup at top of stairs... find your group + assignment!", chatType = "RAID_WARNING" },
            { name = "NH Split Assignments", text = "SPLIT: {triangle} G1+G2 Spellblade & Tich | {star} G3+G4 Etraeus & Botanist | {skull} G5 Krosus\n{triangle} Spellblade/Tich: {G1}, {G2}\n{star} Etraeus/Botanist: {G3}, {G4}\n{skull} Krosus: {G5}", chatType = "RAID_WARNING" },
            { name = "Regroup Elisande", text = "Regroup at Elisande (Nightspire) -- last 2 bosses together. Group 5 please begin the Elisande monologue if possible...", chatType = "RAID_WARNING" },
            { name = "Continue to ToS", text = "If you are continuing... those who dont need to check mail and update gear please head to ToS and begin clearing trash and summoning.", chatType = "RAID_WARNING" },
        },
    },

    ["ToS"] = {
        order = 4,
        messages = {
            { name = "ToS Quick Split", text = "Speed run - splitting 3 ways after Goroth. Watch raid warnings for assignments. Portal to KJ when Avatar dies. --Loot is mailed, don't run back to bosses. Bring patience and curiosity :D", chatType = "RAID_WARNING" },
            { name = "After Goroth", text = "After Goroth (1st boss), we will split 3 ways-- check assignments (your group may change)", chatType = "RAID_WARNING" },
            { name = "Pause Find Group", text = "After we kill Goroth please pause and find your group and understand where you are going... ask questions... route confusion will make this take a lot longer.......", chatType = "RAID_WARNING" },
            { name = "ToS Split Assignments", text = "{moon} G1+G2: Elf Sisters -> Desolate Host | G3: {diamond} Harjatan -> Mistress | G4: {skull} Inquisition -> Maiden -> Avatar\n{moon} Sisters/Host: {G1}, {G2}\n{diamond} Water bosses: {G3}\n{skull} Avatar path: {G4}", chatType = "RAID_WARNING" },
            { name = "KJ Portal", text = "Once groups defeat bosses and Avatar is dead you can board Kil'jaeden ship from Avatar pit or Nether Portal (looks like an eye) at beginning of main hall down the stairs by raid exit/entrance", chatType = "RAID_WARNING" },
            { name = "Desolate Host Rez", text = "We may have to wait to rez after we jump to our deaths after Desolate Host", chatType = "RAID_WARNING" },
            { name = "KJ Ship", text = "On ship kill trash and meet at KJ. (be sure to dispel magic debuff w/ scroll or healers help)", chatType = "RAID_WARNING" },
            { name = "KJ Warning", text = "Please do not nuke KJ at start of fight!! if we spike to < 50% we bug him.... We then end up chasing the corners 10x and likely all fall off :(", chatType = "RAID_WARNING" },
            { name = "Thanks + Alt Run", text = "Thanks all for joining... I will be running this 3 Raid Tour on an alt in 10min. feel free to look for it (search \"tour\") and join in! wsp me if you had been in on this one", chatType = "RAID_WARNING" },
        },
    },

    ["ToV"] = {
        order = 5,
        messages = {
            { name = "Quick Start", text = "Rolling w/ 10man Let's go!!!", chatType = "RAID_WARNING" },
        },
    },

}
