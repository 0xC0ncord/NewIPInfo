//=============================================================================
// NewIPInfoManager.uc
// Copyright (C) 2025 0xC0ncord <concord@fuwafuwatime.moe>
//
// This program is free software; you can redistribute and/or modify
// it under the terms of the Open Unreal Mod License version 1.1.
//=============================================================================

class NewIPInfoManager extends ReplicationInfo
    dependson(ExtendedConsole);

var NewIPInfoServerConfig ServerConfig;

var PlayerController PC;
var bool bWasSpectator;
var bool bInitialized;
var bool bOpened;
var vector PawnLocation;
var float IdleTimeout;
var bool bIsFavorite;
var bool bNoPlayerAgreementShim;

var string NewIPHeaderText;
var string NewIPContentText;
var string NewIPAddress;
var string NewFavoriteName;

var NewIPInfoPage InfoPage;

var class<GUIPage> PlayerAgreementMenuClass;
var GUIPage AgreementPage;
var Actor AgreementManager;
var int AgreementTimeout;
var bool bUpdateAgreementTimeout;

var NewIPInfoConfig ConfigData;

replication
{
    reliable if(Role == ROLE_Authority)
        NewIPHeaderText, NewIPContentText,
        NewIPAddress, NewFavoriteName;
    reliable if(Role < ROLE_Authority)
        ServerAcknowledge;
}

simulated function PostNetReceive()
{
    if(InfoPage != None && !InfoPage.bClosed)
        InfoPage.SetText();
}

function Setup(NewIPInfoServerConfig SC)
{
    ServerConfig = SC;
    PC = PlayerController(Owner);
    bWasSpectator = PC.PlayerReplicationInfo.bOnlySpectator;

    NewIPHeaderText = SC.HeaderText;
    NewIPContentText = SC.ContentText;
    NewIPAddress = SC.NewIPAddress;
    NewFavoriteName = SC.NewFavoriteName;

    if(!SC.bUseSpawnProtection)
    {
        if(!bWasSpectator)
        {
            if(PC.Pawn != None)
                PC.Pawn.Died(None, class'DamageType', PC.Pawn.Location);

            PC.PlayerReplicationInfo.bOnlySpectator = true;
            PC.GotoState('Spectating');
        }
    }
    else
    {
        if(Level.NetMode == NM_DedicatedServer)
            Disable('Tick');

        if(PC.Pawn != None)
        {
            PC.Pawn.SetPhysics(PHYS_None); // to avoid getting pushed around
            PawnLocation = PC.Pawn.Location;
        }
    }

    IdleTimeout = Level.TimeSeconds + SC.IdleTimeoutSeconds;
    PC.LastActiveTime = IdleTimeout;

    bInitialized = true;
}

simulated function Tick(float dt)
{
    local string ConfigDataName;

    if(Role == ROLE_Authority)
    {
        if(ServerConfig.bUseSpawnProtection)
        {
            // actual spawn protection handled by game rules
            PC.Pawn.SetPhysics(PHYS_None);
            if(PC.Pawn.Location != PawnLocation)
                PC.Pawn.SetLocation(PawnLocation);
        }

        // make sure the player doesn't get kicked while this menu is open
        if(PC.LastActiveTime != IdleTimeout && Level.TimeSeconds < IdleTimeout)
            PC.LastActiveTime = IdleTimeout;

        if(bUpdateAgreementTimeout)
        {
            bUpdateAgreementTimeout = False;
            AgreementTimeout = int(AgreementManager.GetPropertyText("Timeout"));
            AgreementManager.LifeSpan = 0;
        }

        // if we are a server and this isn't the host's controller
        if(Viewport(PC.Player) == None)
            return;
    }

    if(bOpened && !ConfigData.bAcknowledged)
    {
        // check for player agreement and shim it so as to not break it
        if(!bNoPlayerAgreementShim)
        {
            if(PlayerAgreementMenuClass == None)
                PlayerAgreementMenuClass = class<GUIPage>(DynamicLoadObject("DruidsPlayerAgreement110.PlayerAgreementPage", class'Class', true));

            if(PlayerAgreementMenuClass == None)
            {
                // mod doesnt appear to be installed, no shimming necessary
                bNoPlayerAgreementShim = true;
            }
            else
            {
                // the mod exists, check if its menu is opened
                AgreementPage = GUIController(PC.Player.GUIController).FindMenuByClass(PlayerAgreementMenuClass);
                if(AgreementPage != None)
                {
                    // if we don't find it, try again every tick just in case
                    ShimPlayerAgreement();
                }
            }
        }

        if(GUIController(PC.Player.GUIController).TopPage() != InfoPage)
        {
            Log(ConfigData.bAcknowledged);
            Log(GUIController(PC.Player.GUIController).TopPage());
            ReopenMenuOnTop();
        }

        return;
    }

    PC = Level.GetLocalPlayerController();
    if(
        PC == None
        || (
            Level.NetMode == NM_ListenServer
            && PC != Owner
        )
    )
    {
        return;
    }

    ConfigDataName = Level.GetAddressURL();
    ConfigData = NewIPInfoConfig(FindObject("Package." $ ConfigDataName, class'NewIPInfoConfig'));
    if(ConfigData == None)
        ConfigData = new(None, ConfigDataName) class'NewIPInfoConfig';

    if(ConfigData.bAcknowledged)
    {
        ServerAcknowledge();
        Disable('Tick');
    }
    else
    {
        CheckFavorite();
        ShowMenu();
        bOpened = true;
    }
}

simulated function CheckFavorite()
{
    local int i;
    local ExtendedConsole.ServerFavorite Favorite;
    local string CurrentIP;
    local int CurrentPort;
    local string NewIP;
    local int NewPort;

	CurrentIP = Level.GetAddressURL();
    i = InStr(CurrentIP, ":");

	CurrentIP = Left(CurrentIP, i);
    CurrentPort = int(Mid(CurrentIP, i + 1));

    i = InStr(NewIP, ":");
	NewIP = Left(NewIPAddress, i);
    NewPort = int(Mid(NewIP, i + 1));

    // check if the new IP is already favorited
    Favorite.IP = NewIP;
    Favorite.Port = NewPort;
    if(class'ExtendedConsole'.static.InFavorites(Favorite))
    {
        LOGD("New IP already in favorites! Nothing to do!");
        LOGD("Favorite.IP:" @ Favorite.IP);
        LOGD("Favorite.Port:" @ Favorite.Port);
        LOGD("Favorite.QueryPort:" @ Favorite.QueryPort);
        return;
    }

    // then, check if the current IP is favorited. if so, we'll
    // add the new IP to favorites automatically
    Favorite.IP = CurrentIP;
    Favorite.Port = CurrentPort;
    // current query port could be different from the new one
    Favorite.QueryPort = CurrentPort + 1;
    if(class'ExtendedConsole'.static.InFavorites(Favorite))
    {
        LOGD("Current IP in favorites! Updating bIsFavorite!");
        LOGD("Favorite.IP:" @ Favorite.IP);
        LOGD("Favorite.Port:" @ Favorite.Port);
        LOGD("Favorite.QueryPort:" @ Favorite.QueryPort);
        bIsFavorite = true;
    }
}

simulated function AddFavorite()
{
    local int i;
    local ExtendedConsole.ServerFavorite NewFavorite;

    i = InStr(NewIPAddress, ":");
    NewFavorite.IP = Left(NewIPAddress, i);
    NewFavorite.Port = int(Mid(NewIPAddress, i + 1));
    NewFavorite.ServerName = class'NewIPInfoPage'.static.Colorize(NewFavoriteName);
    class'ExtendedConsole'.static.AddFavorite(NewFavorite);
}

simulated function ShowMenu()
{
    if(
        PC == None
        || PC.Player == None
        || PC.Player.GUIController == None
    )
    {
        return;
    }

    PC.Player.GUIController.OpenMenu(string(class'NewIPInfoPage'));
    InfoPage = NewIPInfoPage(GUIController(PC.Player.GUIController).TopPage());
    if(InfoPage != None)
    {
        InfoPage.Manager = Self;
        InfoPage.ckAddFavorite.Checked(bIsFavorite);
        InfoPage.SetText();
    }
}

function ServerShimAgreement(Actor A)
{
    AgreementManager = A;
    bUpdateAgreementTimeout = True; // update timeout on next frame
    Enable('Tick');
}

simulated function ShimPlayerAgreement()
{
    AgreementPage.SetVisibility(false);
    AgreementPage.SetTimer(0, false);
}

simulated function UnShimPlayerAgreement()
{
    AgreementPage.SetVisibility(true);
    AgreementPage.SetTimer(1, true);
}

// hack to reopen our menu so that it's at the top of the stack
simulated function ReopenMenuOnTop()
{
    InfoPage.Manager = None;
    InfoPage.bClosed = true;
    GUIController(PC.Player.GUIController).RemoveMenu(InfoPage, false);

    ShowMenu();
}

function ServerAcknowledge()
{
    Destroy();
}

function Destroyed()
{
    if(AgreementManager != None)
    {
        // note that the agreement manager could be destroyed early if the player already agreed before
        AgreementManager.LifeSpan = AgreementTimeout;
    }
    else
    {
        // do NOT respawn player here if player agreement must do something
        if(bInitialized && PC == None)
        {
            Level.Game.NumPlayers--;
            Level.Game.NumSpectators++;
        }

        if(PC != None)
        {
            if(ServerConfig.bUseSpawnProtection && PC.Pawn != None)
            {
                PC.Pawn.DeactivateSpawnProtection();
                PC.Pawn.SetMovementPhysics();
            }
            else if(!bWasSpectator)
            {
                PC.bBehindView = false;
                PC.FixFOV();
                PC.ServerViewSelf();
                PC.PlayerReplicationInfo.bOnlySpectator = false;
                PC.PlayerReplicationInfo.Reset();
                PC.Adrenaline = 0;
                PC.BroadcastLocalizedMessage(Level.Game.GameMessageClass, 1, PC.PlayerReplicationInfo);
                PC.GotoState('PlayerWaiting');
                if(Level.Game.bTeamGame)
                    Level.Game.ChangeTeam(PC, Level.Game.PickTeam(int(PC.GetURLOption("Team")), None), false);
                if(Level.Game.IsA('InvasionX'))
                {
                    PC.PlayerReplicationInfo.NumLives = 0;
                    PC.PlayerReplicationInfo.bOutOfLives = false;
                    Level.Game.RestartPlayer(PC);
                    PC.ServerGivePawn();
                }
            }
        }
    }
}

defaultproperties
{
    NetUpdateFrequency=0.25
    NetPriority=3.0
    bSkipActorPropertyReplication=True
    bReplicateMovement=False
    bAlwaysRelevant=False
    bOnlyRelevantToOwner=True
}
