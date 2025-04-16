//=============================================================================
// NewIPInfoServerConfig.uc
// Copyright (C) 2025 0xC0ncord <concord@fuwafuwatime.moe>
//
// This program is free software; you can redistribute and/or modify
// it under the terms of the Open Unreal Mod License version 1.1.
//=============================================================================

class NewIPInfoServerConfig extends Object
	config(NewIPInfo)
	PerObjectConfig;

var() config string HeaderText;
var() config string ContentText;

var() config string NewIPAddress;
var() config string NewFavoriteName;

var() config bool bUseSpawnProtection;
var() config int IdleTimeoutSeconds;

defaultproperties
{
    HeaderText="$(255,0,0)We are changing IPs!"
    ContentText="$(255,255,255)Our server will be at $(0,192,255)$1$(255,255,255) starting on $(0,255,0)January 1st, 1970. $(255,255,255)Save the date!||By $(255,0,255)checking the box below$(255,255,255), we'll favorite our new IP for you automatically."
    NewIPAddress="127.0.0.1:7777"
    NewFavoriteName="$(255,0,0)(NEW IP: Jan 1 1970) $(255,255,255)Clan Awesome's Server"
    bUseSpawnProtection=True
    IdleTimeoutSeconds=120
}
