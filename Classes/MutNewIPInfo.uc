//=============================================================================
// MutNewIPInfo.uc
// Copyright (C) 2025 0xC0ncord <concord@fuwafuwatime.moe>
//
// This program is free software; you can redistribute and/or modify
// it under the terms of the Open Unreal Mod License version 1.1.
//=============================================================================

class MutNewIPInfo extends Mutator;

// Note to mod authors: if you are making a customized version of NewIPInfo,
// feel free to remove this line. It is used to track internal versions of the
// mod for official releases.
const INTERNAL_VERSION = $$"__VERSIONSTRING__"$$;

var NewIPInfoRules Rules;
var array<PlayerController> Pending;

function PostBeginPlay()
{
    if(class'NewIPInfoServerConfig'.default.bUseSpawnProtection)
    {
        Rules = Spawn(class'NewIPInfoRules');
        Rules.NextGameRules = Level.Game.GameRulesModifiers;
        Level.Game.GameRulesModifiers = Rules;
    }
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local Controller C;
    local NewIPInfoManager M;

    if(
        PlayerController(Other) != None
        && Camera(Other) == None
        && MessagingSpectator(Other) == None
        && !Other.IsA('BTGhostController') // ignore BTimes ghosts
    )
    {
        // wait for them to get a PRI first
        Pending[Pending.Length] = PlayerController(Other);
    }
    else if(string(Other.Class) == "DruidsPlayerAgreement110.PlayerAgreementManager")
    {
        // flush pending managers, as we might get ticked after player agreement
        UpdatePendingManagers();

        // find who owns this agreement manager
        for(C = Level.ControllerList; C != None; C = C.NextController)
        {
            if(PlayerController(C) != None && Other.Owner == C)
            {
                foreach C.ChildActors(class'NewIPInfoManager', M)
                    break;

                if(M != None)
                {
                    // shim it
                    M.ServerShimAgreement(Other);
                    break;
                }
            }
        }
    }
    return true;
}

function Tick(float dt)
{
    UpdatePendingManagers();
}

function UpdatePendingManagers()
{
    while(Pending.Length > 0)
    {
        CreateManagerFor(Pending[0]);
        Pending.Remove(0, 1);
    }
}

function CreateManagerFor(PlayerController PC)
{
    local NewIPInfoManager A;

    if(PC == None)
        return;

    A = Spawn(class'NewIPInfoManager', PC);
    A.Setup();
}

defaultproperties
{
    bAddToServerPackages=True
    GroupName="NewIP"
    FriendlyName="New IP Info Broadcaster"
    Description="Displays a message (and potentially auto-favorites) for players with information on your server's IP address changing."
}
