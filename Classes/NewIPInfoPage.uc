//=============================================================================
// NewIPInfoPage.uc
// Copyright (C) 2025 0xC0ncord <concord@fuwafuwatime.moe>
//
// This program is free software; you can redistribute and/or modify
// it under the terms of the Open Unreal Mod License version 1.1.
//=============================================================================

class NewIPInfoPage extends GUIPage;

var automated GUISectionBackground sbBackground, sbButtons;
var automated GUILabel txHeader;
var automated GUIScrollTextBox lbText;
var automated GUIButton btAcknowledge;

var string Text_Acknowledge;

var NewIPInfoManager Manager;
var bool bClosed;

function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
    Super.InitComponent(MyController, MyOwner);

    bClosed = false;

    btAcknowledge.Caption = Text_Acknowledge;
}

function SetText()
{
    txHeader.Caption = Colorize(Manager.NewIPHeaderText);
    if(Manager.bAddFavorite)
    {
        lbText.MyScrollText.SetContent(
            Colorize(Repl(Manager.NewIPContentText, "$1", Manager.NewIPAddress))
            @ "||" $ Colorize(Manager.NewIPAlreadyFavoriteText)
        );
    }
    else
    {
        lbText.MyScrollText.SetContent(
            Colorize(Manager.NewIPContentText)
        );
    }
}

function bool InternalOnPreDraw(Canvas C)
{
    return false;
}

function bool InternalOnCanClose(optional bool bCanceled)
{
    // don't allow closing by pressing Escape
    if(Manager == None)
        return true;
    return bClosed;
}

function InternalOnClose(optional bool bCanceled)
{
    return;
}

function bool Acknowledge(GUIComponent Sender)
{
    bClosed = true;

    if(Manager != None)
    {
        Manager.ConfigData.bAcknowledged = true;
        Manager.ConfigData.SaveConfig();
        Manager.MaybeAddFavorite();

        if(Manager.AgreementPage != None)
            Manager.UnShimPlayerAgreement();
        Manager.ServerAcknowledge();
    }

    Controller.CloseMenu(false);
    Manager = None;
    return true;
}

static final function string Colorize(string S)
{
    local int Pos;
    local int i, x;
    local string Tmp, Next;
    local byte R, G, B, n;

    Pos = InStr(S, "$(");
    while(Pos != -1)
    {
        R = 0;
        G = 0;
        B = 0;
        n = 0;

        i = Pos + 2;
        while(true)
        {
            x = i;
            Next = Mid(S, x, 1);

            while(Next != "," && Next != ")" && x <= Len(S))
            {
                x++;
                Next = Mid(S, x, 1);
            }

            Tmp = Mid(S, i, x - i);
            switch(n)
            {
                case 0:
                    R = byte(Tmp);
                    break;
                case 1:
                    G = byte(Tmp);
                    break;
                case 2:
                default:
                    B = byte(Tmp);
                    break;
            }
            n++;

            if(Next == ")" || x > Len(S))
            {
                Tmp = Mid(S, Pos, x - Pos + 1);
                S = Repl(S, Tmp, Chr(0x1b) $ (Chr(Max(R, 1))) $ (Chr(Max(G, 1))) $ (Chr(Max(B, 1))));
                break;
            }
            i = x + 1;
        }

        Pos = InStr(S, "$(");
    }
    return S;
}

defaultproperties
{
    Begin Object Class=AltSectionBackground Name=sbBackground_
        LeftPadding=0.0
        RightPadding=0.0
        FontScale=FNS_Small
        WinTop=0.151621
        WinLeft=0.210134
        WinWidth=0.579732
        WinHeight=0.361461
        bBoundToParent=True
        bScaleToParent=True
        OnPreDraw=sbBackground_.InternalPreDraw
    End Object
    sbBackground=AltSectionBackground'sbBackground_'

    Begin Object Class=AltSectionBackground Name=sbButtons_
        LeftPadding=0.0
        RightPadding=0.0
        FontScale=FNS_Small
        WinTop=0.523650
        WinLeft=0.210134
        WinWidth=0.579732
        WinHeight=0.160828
        bBoundToParent=True
        bScaleToParent=True
        OnPreDraw=sbButtons_.InternalPreDraw
    End Object
    sbButtons=AltSectionBackground'sbButtons_'
{
    Begin Object Class=GUILabel Name=txHeader_
        TextAlign=TXTA_Center
        FontScale=FNS_Large
        WinTop=0.185881
        WinLeft=0.229686
        WinWidth=0.540628
        WinHeight=0.041664
        bBoundToParent=True
        bScaleToParent=True
        bNeverFocus=True
    End Object
    txHeader=GUILabel'txHeader_'

    Begin Object Class=GUIScrollTextBox Name=lbText_
        bNoTeletype=True
        CharDelay=0.002500
        EOLDelay=0.000000
        OnCreateComponent=lbText_.InternalOnCreateComponent
        FontScale=FNS_Small
        WinTop=0.245370
        WinHeight=0.227087
        WinLeft=0.229686
        WinWidth=0.540628
        bBoundToParent=True
        bScaleToParent=True
        bNeverFocus=True
    End Object
    lbText=GUIScrollTextBox'lbText_'

    Begin Object Class=GUIButton Name=btAcknowledge_
        FontScale=FNS_Small
        WinTop=0.572187
        WinHeight=0.061350
        WinLeft=0.396128
        WinWidth=0.207744
        bBoundToParent=True
        bScaleToParent=True
        OnClick=NewIPInfoPage.Acknowledge
        OnKeyEvent=btAcknowledge_.InternalOnKeyEvent
    End Object
    btAcknowledge=GUIButton'btAcknowledge_'

    Text_Acknowledge="Acknowledge"

    bAllowedAsLast=True
    bRenderWorld=False
    WinHeight=1.000000
    OnCanClose=NewIPInfoPage.InternalOnCanClose
    OnClose=NewIPInfoPage.InternalOnClose
    OnPreDraw=NewIPInfoPage.InternalOnPreDraw
}
