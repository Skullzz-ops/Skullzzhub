pcall(print, "[SkullzzHub] script start")
pcall(warn,  "[SkullzzHub] script start")
local function _hub()
-- Skullzz Hub v4 | StarterPlayerScripts (executor)

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local HttpService      = game:GetService("HttpService")
local Lighting         = game:GetService("Lighting")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ── Theme ──────────────────────────────────────────────
local DARK    = Color3.fromRGB(14,14,20)
local DARKER  = Color3.fromRGB(10,10,15)
local MID     = Color3.fromRGB(20,20,30)
local CARD_ON = Color3.fromRGB(26,28,50)
local CARD_OFF= Color3.fromRGB(17,17,25)
local BORDER  = Color3.fromRGB(36,36,56)
local DIM     = Color3.fromRGB(90,90,120)
local WHITE   = Color3.fromRGB(255,255,255)
local ACCENT  = Color3.fromRGB(90,100,220)
local accentEls = {}   -- frames/strokes to recolor when theme changes
local SKULL_IMG = "rbxassetid://135094534201893"  -- TODO: replace 0 with your uploaded asset ID

-- ── Settings ───────────────────────────────────────────
local AB = {
    Enabled=true, FOV=200, Smoothness=0.7, Damping=1.0,
    Prediction=2, AutoPrediction=false, TargetPart="Head",
    ShowFOVCircle=true, CircleColor=WHITE, CircleThickness=2,
    ShowTargetName=true, ShowHitChance=true,
    TeamCheck=false, CursorLock=false, HoldToAim=false, VisCheck=false,
}
local ESP = {
    Enabled=false, FillColor=Color3.fromRGB(255,50,50),
    OutlineColor=WHITE, FillTransparency=0.5, OutlineTransparency=0,
    ShowNames=true, ShowDistance=true, ShowHealthBar=true,
    ShowTracelines=false, ShowSkeleton=false, ShowSnapline=false,
    ShowBoxes=false, MaxDistance=500, TeamCheck=false,
    SkeletonColor=WHITE, TraceColor=WHITE, BoxColor=WHITE,
}
local MISC = {
    SpeedEnabled=false, Speed=100,
    JumpEnabled=false, JumpPower=150,
    InfiniteJump=false, NoClip=false,
    Fly=false, FlySpeed=60, AntiAFK=true,
    GodMode=false, AntiRagdoll=false,
    AutoShoot=false, AutoShootRate=0.1,
    TriggerBot=false, TriggerFOV=30,
    HitboxExpand=false, HitboxSize=6,
    ClickTeleport=false, Fullbright=false,
    CamFOV=false, CamFOVVal=70,
    SpectatorAlert=false, PanelOpacity=100,
    AutoRejoin=false,
}
local SA   = {Enabled=false}
local MB   = {Enabled=false, MaxMissDist=30}
local RAGE = {Active=false}
local RADAR = {Enabled=false, Range=150, Size=140}
local CROSS = {Enabled=false, Style="dot", Color=WHITE, Size=6, Thickness=1, Gap=4}
local KEYBINDS = {
    panel=Enum.KeyCode.Insert, aimbot=Enum.KeyCode.Delete,
    panic=Enum.KeyCode.End, rage=Enum.KeyCode.CapsLock,
    cycle=Enum.KeyCode.Tab,
}
-- ── Forward decls ──────────────────────────────────────
local notify, Panel, TitleBar, TitleFix
local updateFOV, applyPanelOpacity, buildCrosshair, cleanupAll
local toggleMin  -- minimize<->skull-icon toggle (assigned with the title bar)
-- feature modules (Rebirth/NPC/Troll) register cleanup callbacks here
-- so they can keep their own locals scoped inside do..end blocks
-- (Luau caps a single function at 200 locals — this keeps us under it)
local cleanupHooks = {}

-- ── State ──────────────────────────────────────────────
local currentTarget = nil
local ESPObjects    = {}
local flyBV, flyBG  = nil, nil
local camSpringVel  = Vector3.new(0,0,0)
local origCamType    = Camera.CameraType
local sharedPlayers  = {}   -- updated in Heartbeat, shared with getClosestTarget
local targetPrevPos, prevAimbotTarget, prevTargetScreenP = nil,nil,nil
local targetScreenVelMag, hitChancePct = 0, 0
local cycledTarget, cycleExpiry = nil, 0
local stickyTarget, stickyTargetExpiry = nil, 0
local panelVisible  = true
local activeNotifs  = {}
local playerJoinTimes, lastSpecNotif = {}, {}
local bindCapture   = nil
local frameCount    = 0
local isShooting    = false
local lastAutoShot, lastTriggerShot = 0, 0
local origLight     = {B=Lighting.Brightness, A=Lighting.Ambient, FE=Lighting.FogEnd}
local ragePreFOV, ragePreSmooth, ragePreDamp, ragePreAS
local noclipParts   = {}   -- cached BaseParts for NoClip (refreshed periodically, not every frame)
pcall(function() LP.CharacterAdded:Connect(function() noclipParts={} end) end)  -- rebuild cache on respawn

-- ── ScreenGui ──────────────────────────────────────────
local Gui = Instance.new("ScreenGui")
Gui.Name="SkullzzHub"; Gui.ResetOnSpawn=false
Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset=true
pcall(function() Gui.Parent=gethui() end)
if not Gui.Parent then pcall(function() Gui.Parent=game:GetService("CoreGui") end) end
if not Gui.Parent then Gui.Parent=LP.PlayerGui end

-- ── Loading Screen ─────────────────────────────────────
do
    local QUAD=Enum.EasingStyle.Quad
    -- dim backdrop over the whole screen
    local backdrop=Instance.new("Frame"); backdrop.Size=UDim2.new(1,0,1,0)
    backdrop.BackgroundColor3=Color3.fromRGB(6,6,10); backdrop.BackgroundTransparency=1
    backdrop.BorderSizePixel=0; backdrop.ZIndex=200; backdrop.Parent=Gui
    TweenService:Create(backdrop,TweenInfo.new(0.3),{BackgroundTransparency=0.25}):Play()

    -- centred card
    local card=Instance.new("Frame"); card.Size=UDim2.new(0,300,0,150)
    card.AnchorPoint=Vector2.new(0.5,0.5); card.Position=UDim2.new(0.5,0,0.5,8)
    card.BackgroundColor3=DARKER; card.BackgroundTransparency=1; card.BorderSizePixel=0
    card.ZIndex=201; card.Parent=backdrop
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,14)
    local cStroke=Instance.new("UIStroke",card); cStroke.Color=ACCENT
    cStroke.Thickness=1.5; cStroke.Transparency=1

    local icon=Instance.new("ImageLabel"); icon.Size=UDim2.new(0,54,0,54)
    icon.AnchorPoint=Vector2.new(0.5,0); icon.Position=UDim2.new(0.5,0,0,14)
    icon.BackgroundTransparency=1; icon.Image=SKULL_IMG
    icon.ScaleType=Enum.ScaleType.Fit; icon.ImageTransparency=1
    icon.ZIndex=202; icon.Parent=card

    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,22)
    title.Position=UDim2.new(0,0,0,74); title.BackgroundTransparency=1
    title.Text="SKULLZZ HUB"; title.TextSize=17; title.Font=Enum.Font.GothamBold
    title.TextColor3=WHITE; title.TextTransparency=1; title.ZIndex=202; title.Parent=card

    local sub=Instance.new("TextLabel"); sub.Size=UDim2.new(1,0,0,14)
    sub.Position=UDim2.new(0,0,0,96); sub.BackgroundTransparency=1
    sub.Text="initializing modules..."; sub.TextSize=10; sub.Font=Enum.Font.Gotham
    sub.TextColor3=DIM; sub.TextTransparency=1; sub.ZIndex=202; sub.Parent=card

    -- progress bar
    local track=Instance.new("Frame"); track.Size=UDim2.new(1,-50,0,6)
    track.Position=UDim2.new(0,25,1,-26); track.BackgroundColor3=MID
    track.BackgroundTransparency=1; track.BorderSizePixel=0; track.ZIndex=202; track.Parent=card
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new(0,0,1,0)
    fill.BackgroundColor3=ACCENT; fill.BorderSizePixel=0; fill.ZIndex=203; fill.Parent=track
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    -- fade everything in
    TweenService:Create(card,TweenInfo.new(0.3),{BackgroundTransparency=0}):Play()
    TweenService:Create(cStroke,TweenInfo.new(0.3),{Transparency=0.15}):Play()
    TweenService:Create(icon,TweenInfo.new(0.35),{ImageTransparency=0}):Play()
    TweenService:Create(title,TweenInfo.new(0.35),{TextTransparency=0}):Play()
    TweenService:Create(sub,TweenInfo.new(0.35),{TextTransparency=0.3}):Play()
    TweenService:Create(track,TweenInfo.new(0.35),{BackgroundTransparency=0}):Play()
    -- fill the bar
    TweenService:Create(fill,TweenInfo.new(1.3,QUAD),{Size=UDim2.new(1,0,1,0)}):Play()

    -- fade out + clean up
    task.delay(1.55,function()
        sub.Text="ready"
        local ti=TweenInfo.new(0.4,QUAD)
        TweenService:Create(backdrop,ti,{BackgroundTransparency=1}):Play()
        TweenService:Create(card,ti,{BackgroundTransparency=1}):Play()
        TweenService:Create(cStroke,ti,{Transparency=1}):Play()
        TweenService:Create(icon,ti,{ImageTransparency=1}):Play()
        TweenService:Create(title,ti,{TextTransparency=1}):Play()
        TweenService:Create(sub,ti,{TextTransparency=1}):Play()
        TweenService:Create(track,ti,{BackgroundTransparency=1}):Play()
        TweenService:Create(fill,ti,{BackgroundTransparency=1}):Play()
        task.delay(0.45,function() pcall(function() backdrop:Destroy() end) end)
    end)
end

-- ── 2-D Line System ────────────────────────────────────
local LineHolder = Instance.new("Frame")
LineHolder.Size=UDim2.new(1,0,1,0); LineHolder.BackgroundTransparency=1
LineHolder.BorderSizePixel=0; LineHolder.ZIndex=4; LineHolder.Parent=Gui

local function newLine(thick,col)
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(0,0.5); f.BorderSizePixel=0
    f.BackgroundColor3=col or WHITE
    f.Size=UDim2.new(0,0,0,thick or 1); f.ZIndex=4
    f.Visible=false; f.Parent=LineHolder; return f
end
local function drawLine(fr,p1,p2,col)
    local d=p2-p1; local len=d.Magnitude
    if len<1 then fr.Visible=false; return end
    fr.Position=UDim2.new(0,p1.X,0,p1.Y)
    fr.Size=UDim2.new(0,len,0,fr.Size.Y.Offset)
    fr.Rotation=math.deg(math.atan2(d.Y,d.X))
    if col then fr.BackgroundColor3=col end
    fr.Visible=true
end

-- Bone chains
local BONES_R15={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local BONES_R6={
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

local SnapLine = newLine(1,WHITE); SnapLine.ZIndex=6

-- ── FOV Circle ─────────────────────────────────────────
local FOVCircle=Instance.new("Frame")
FOVCircle.AnchorPoint=Vector2.new(0.5,0.5); FOVCircle.BackgroundTransparency=1
FOVCircle.BorderSizePixel=0; FOVCircle.ZIndex=5; FOVCircle.Parent=Gui
Instance.new("UICorner",FOVCircle).CornerRadius=UDim.new(0.5,0)
local FOVStroke=Instance.new("UIStroke"); FOVStroke.Parent=FOVCircle

updateFOV=function()
    local d=AB.FOV*2
    FOVCircle.Size=UDim2.new(0,d,0,d); FOVCircle.Position=UDim2.new(0.5,0,0.5,0)
    FOVCircle.Visible=AB.ShowFOVCircle and AB.Enabled
    FOVStroke.Color=AB.CircleColor; FOVStroke.Thickness=AB.CircleThickness
end
updateFOV()

-- ── HUD Labels ─────────────────────────────────────────
local TargetLabel=Instance.new("TextLabel")
TargetLabel.Size=UDim2.new(0,160,0,22); TargetLabel.AnchorPoint=Vector2.new(0.5,1)
TargetLabel.Position=UDim2.new(0.5,0,0.5,-AB.FOV-8)
TargetLabel.BackgroundColor3=DARKER; TargetLabel.BackgroundTransparency=0.1
TargetLabel.BorderSizePixel=0; TargetLabel.Text=""
TargetLabel.TextColor3=Color3.fromRGB(90,200,255); TargetLabel.TextSize=11
TargetLabel.Font=Enum.Font.GothamBold; TargetLabel.ZIndex=6
TargetLabel.Visible=false; TargetLabel.Parent=Gui
Instance.new("UICorner",TargetLabel).CornerRadius=UDim.new(0,5)

local HitLabel=Instance.new("TextLabel")
HitLabel.Size=UDim2.new(0,80,0,18); HitLabel.AnchorPoint=Vector2.new(0.5,0)
HitLabel.Position=UDim2.new(0.5,0,0.5,AB.FOV+10)
HitLabel.BackgroundTransparency=1; HitLabel.Text="0%"
HitLabel.TextColor3=Color3.fromRGB(100,255,150); HitLabel.TextSize=11
HitLabel.Font=Enum.Font.GothamBold; HitLabel.ZIndex=6
HitLabel.Visible=false; HitLabel.Parent=Gui

-- ── Crosshair ──────────────────────────────────────────
local CrossParts={}
buildCrosshair=function()
    for _,f in ipairs(CrossParts) do f:Destroy() end; CrossParts={}
    if not CROSS.Enabled then return end
    local cx=Camera.ViewportSize.X/2; local cy=Camera.ViewportSize.Y/2
    local s=CROSS.Size; local g=CROSS.Gap; local t=CROSS.Thickness; local c=CROSS.Color
    local function bar(w,h,ox,oy)
        local f=Instance.new("Frame"); f.Size=UDim2.new(0,w,0,h)
        f.AnchorPoint=Vector2.new(0.5,0.5); f.Position=UDim2.new(0,cx+ox,0,cy+oy)
        f.BackgroundColor3=c; f.BorderSizePixel=0; f.ZIndex=7; f.Parent=Gui
        table.insert(CrossParts,f); return f
    end
    if CROSS.Style=="dot" then
        local d=bar(s,s,0,0); Instance.new("UICorner",d).CornerRadius=UDim.new(0.5,0)
    elseif CROSS.Style=="cross" then
        bar(s,t,0,-(g+s/2)); bar(s,t,0,g+s/2)
        bar(t,s,-(g+s/2),0); bar(t,s,g+s/2,0)
    elseif CROSS.Style=="circle" then
        local f=Instance.new("Frame"); f.Size=UDim2.new(0,s*2,0,s*2)
        f.AnchorPoint=Vector2.new(0.5,0.5); f.Position=UDim2.new(0,cx,0,cy)
        f.BackgroundTransparency=1; f.BorderSizePixel=0; f.ZIndex=7; f.Parent=Gui
        Instance.new("UICorner",f).CornerRadius=UDim.new(0.5,0)
        local st=Instance.new("UIStroke"); st.Color=c; st.Thickness=t; st.Parent=f
        table.insert(CrossParts,f)
    end
end

-- ── Radar ──────────────────────────────────────────────
local RadarFrame=Instance.new("Frame")
RadarFrame.Size=UDim2.new(0,RADAR.Size,0,RADAR.Size)
RadarFrame.Position=UDim2.new(1,-RADAR.Size-10,1,-RADAR.Size-10)
RadarFrame.BackgroundColor3=Color3.fromRGB(10,10,18)
RadarFrame.BackgroundTransparency=0.2; RadarFrame.BorderSizePixel=0
RadarFrame.ZIndex=10; RadarFrame.Visible=false
RadarFrame.Active=true; RadarFrame.Draggable=true; RadarFrame.Parent=Gui
Instance.new("UICorner",RadarFrame).CornerRadius=UDim.new(0,8)
local RadarStroke=Instance.new("UIStroke")
RadarStroke.Color=BORDER; RadarStroke.Thickness=1; RadarStroke.Parent=RadarFrame
table.insert(accentEls,RadarStroke)
local SelfDot=Instance.new("Frame"); SelfDot.Size=UDim2.new(0,6,0,6)
SelfDot.AnchorPoint=Vector2.new(0.5,0.5); SelfDot.Position=UDim2.new(0.5,0,0.5,0)
SelfDot.BackgroundColor3=ACCENT; SelfDot.BorderSizePixel=0; SelfDot.ZIndex=12; SelfDot.Parent=RadarFrame
Instance.new("UICorner",SelfDot).CornerRadius=UDim.new(0.5,0)
table.insert(accentEls,SelfDot)
local radarDots={}

-- ── Stats HUD ──────────────────────────────────────────
local statsEnabled=false
local StatsFrame=Instance.new("Frame")
StatsFrame.Size=UDim2.new(0,200,0,22); StatsFrame.Position=UDim2.new(0.5,-100,0,6)
StatsFrame.BackgroundColor3=DARKER; StatsFrame.BackgroundTransparency=0.2
StatsFrame.BorderSizePixel=0; StatsFrame.ZIndex=20; StatsFrame.Visible=false
StatsFrame.Active=true; StatsFrame.Draggable=true; StatsFrame.Parent=Gui
Instance.new("UICorner",StatsFrame).CornerRadius=UDim.new(0,5)
local StatsLbl=Instance.new("TextLabel"); StatsLbl.Size=UDim2.new(1,0,1,0)
StatsLbl.BackgroundTransparency=1; StatsLbl.TextSize=9; StatsLbl.Font=Enum.Font.GothamBold
StatsLbl.TextColor3=DIM; StatsLbl.ZIndex=21; StatsLbl.Parent=StatsFrame

local SpecLabel=Instance.new("TextLabel")
SpecLabel.Size=UDim2.new(0,230,0,22); SpecLabel.AnchorPoint=Vector2.new(0.5,0)
SpecLabel.Position=UDim2.new(0.5,0,0,32); SpecLabel.BackgroundColor3=Color3.fromRGB(120,30,30)
SpecLabel.BackgroundTransparency=0.2; SpecLabel.BorderSizePixel=0
SpecLabel.TextColor3=Color3.fromRGB(255,150,150); SpecLabel.TextSize=10
SpecLabel.Font=Enum.Font.GothamBold; SpecLabel.ZIndex=20; SpecLabel.Visible=false; SpecLabel.Parent=Gui
Instance.new("UICorner",SpecLabel).CornerRadius=UDim.new(0,5)

-- ── ESP Helpers ────────────────────────────────────────
local function RemoveESP(player)
    local obj=ESPObjects[player]; if not obj then return end
    if obj.Highlight    then pcall(function() obj.Highlight:Destroy()    end) end
    if obj.Billboard    then pcall(function() obj.Billboard:Destroy()    end) end
    if obj.TraceLine    then pcall(function() obj.TraceLine:Destroy()    end) end
    if obj.SkeletonLines then for _,l in ipairs(obj.SkeletonLines) do pcall(function() l:Destroy() end) end end
    if obj.BoxLines     then for _,l in ipairs(obj.BoxLines)     do pcall(function() l:Destroy() end) end end
    ESPObjects[player]=nil
end

local function CreateESP(player)
    if player==LP then return end
    local char=player.Character; if not char then return end
    local head=char:FindFirstChild("Head"); if not head then return end

    local hl=Instance.new("Highlight"); hl.FillColor=ESP.FillColor
    hl.OutlineColor=ESP.OutlineColor; hl.FillTransparency=ESP.FillTransparency
    hl.OutlineTransparency=ESP.OutlineTransparency
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Adornee=char; hl.Parent=char

    local bb=Instance.new("BillboardGui"); bb.Name="ESPTag"
    bb.Size=UDim2.new(0,130,0,44); bb.StudsOffset=Vector3.new(0,3.2,0)
    bb.AlwaysOnTop=true; bb.Enabled=ESP.ShowNames; bb.Adornee=head; bb.Parent=head
    local bbBG=Instance.new("Frame"); bbBG.Size=UDim2.new(1,0,1,0)
    bbBG.BackgroundColor3=Color3.fromRGB(10,10,20); bbBG.BackgroundTransparency=0.35
    bbBG.BorderSizePixel=0; bbBG.Parent=bb
    Instance.new("UICorner",bbBG).CornerRadius=UDim.new(0,6)
    local nameLbl=Instance.new("TextLabel"); nameLbl.Size=UDim2.new(1,-8,0,15)
    nameLbl.Position=UDim2.new(0,4,0,2); nameLbl.BackgroundTransparency=1
    nameLbl.Text=player.DisplayName; nameLbl.TextColor3=WHITE; nameLbl.TextScaled=true
    nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextStrokeTransparency=0.4; nameLbl.Parent=bbBG
    local distLbl=Instance.new("TextLabel"); distLbl.Size=UDim2.new(1,-8,0,12)
    distLbl.Position=UDim2.new(0,4,0,17); distLbl.BackgroundTransparency=1; distLbl.Text=""
    distLbl.TextColor3=Color3.fromRGB(160,200,255); distLbl.TextScaled=true
    distLbl.Font=Enum.Font.Gotham; distLbl.Parent=bbBG
    local hbBG=Instance.new("Frame"); hbBG.Size=UDim2.new(1,-8,0,3)
    hbBG.Position=UDim2.new(0,4,0,31); hbBG.BackgroundColor3=Color3.fromRGB(30,30,30)
    hbBG.BorderSizePixel=0; hbBG.Parent=bbBG
    Instance.new("UICorner",hbBG).CornerRadius=UDim.new(0,2)
    local hbFill=Instance.new("Frame"); hbFill.Size=UDim2.new(1,0,1,0)
    hbFill.BackgroundColor3=Color3.fromRGB(60,220,80); hbFill.BorderSizePixel=0; hbFill.Parent=hbBG
    Instance.new("UICorner",hbFill).CornerRadius=UDim.new(0,2)

    -- Traceline
    local tl=newLine(1,ESP.TraceColor)
    -- Skeleton
    local hasR15=(char:FindFirstChildOfClass("Motor6D") ~= nil)
    local bones=hasR15 and BONES_R15 or BONES_R6
    local skel={}; for _=1,#bones do table.insert(skel,newLine(1,ESP.SkeletonColor)) end
    -- Box (4 lines: top, bottom, left, right edges)
    local boxLines={}; for _=1,4 do table.insert(boxLines,newLine(1,ESP.BoxColor)) end

    ESPObjects[player]={
        Highlight=hl, Billboard=bb, DistLabel=distLbl,
        HealthFill=hbFill, HealthBG=hbBG,
        TraceLine=tl, SkeletonLines=skel, Bones=bones, BoxLines=boxLines,
    }
end

local function HookPlayer(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5); if ESP.Enabled then RemoveESP(p); CreateESP(p) end
    end)
    p.CharacterRemoving:Connect(function() RemoveESP(p) end)
end
for _,p in ipairs(Players:GetPlayers()) do HookPlayer(p); playerJoinTimes[p]=0 end
Players.PlayerAdded:Connect(function(p) HookPlayer(p); playerJoinTimes[p]=tick() end)
Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p); playerJoinTimes[p]=nil; lastSpecNotif[p]=nil
    if radarDots[p] then radarDots[p]:Destroy(); radarDots[p]=nil end
end)

-- ── Misc Helpers ───────────────────────────────────────
local function miscHum()
    local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid")
end
local function applyMovement()
    local h=miscHum(); if not h then return end
    if MISC.SpeedEnabled then h.WalkSpeed=MISC.Speed else h.WalkSpeed=16 end
    h.UseJumpPower=true
    if MISC.JumpEnabled then h.JumpPower=MISC.JumpPower else h.JumpPower=50 end
end
local function enableFly()
    local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if flyBV then flyBV:Destroy() end; if flyBG then flyBG:Destroy() end
    flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e5,1e5,1e5)
    flyBV.Velocity=Vector3.new(0,0,0); flyBV.Parent=hrp
    flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(1e5,1e5,1e5)
    flyBG.D=100; flyBG.CFrame=hrp.CFrame; flyBG.Parent=hrp
end
local function disableFly()
    if flyBV then flyBV:Destroy(); flyBV=nil end
    if flyBG then flyBG:Destroy(); flyBG=nil end
end

LP.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid",5); task.wait(0.1); applyMovement()
    if MISC.Fly then task.wait(0.15); enableFly() end
    -- anti-ragdoll hook per spawn
    local hum=char:WaitForChild("Humanoid",5)
    if hum then
        hum.StateChanged:Connect(function(_,new)
            if not MISC.AntiRagdoll then return end
            if new==Enum.HumanoidStateType.FallingDown or new==Enum.HumanoidStateType.Ragdoll then
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
end)
UserInputService.JumpRequest:Connect(function()
    if not MISC.InfiniteJump then return end
    local h=miscHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
LP.Idled:Connect(function()
    if not MISC.AntiAFK then return end
    VirtualUser:Button1Down(Vector2.new(0,0),Camera.CFrame)
    task.wait(0.1); VirtualUser:Button1Up(Vector2.new(0,0),Camera.CFrame)
end)

-- ── Click Teleport ─────────────────────────────────────
local clickTpConn=nil
local function setClickTp(v)
    MISC.ClickTeleport=v
    if clickTpConn then clickTpConn:Disconnect(); clickTpConn=nil end
    if not v then return end
    clickTpConn=UserInputService.InputBegan:Connect(function(inp,consumed)
        if consumed or inp.UserInputType~=Enum.UserInputType.MouseButton2 then return end
        local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local mpos=UserInputService:GetMouseLocation()
        local ok,ray=pcall(Camera.ScreenPointToRay,Camera,mpos.X,mpos.Y); if not ok then return end
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={LP.Character}
        local res=workspace:Raycast(ray.Origin,ray.Direction*1000,params)
        if res then hrp.CFrame=CFrame.new(res.Position+Vector3.new(0,4,0)) end
    end)
end

-- ── Silent Aim ─────────────────────────────────────────
pcall(function()
    if not hookmetamethod then return end
    local orig; orig=hookmetamethod(game,"__index",function(self,key)
        if SA.Enabled and not checkcaller() then
            if typeof(self)=="Instance" and self:IsA("Mouse") then
                if currentTarget then
                    local char=currentTarget.Character
                    local part=char and char:FindFirstChild(AB.TargetPart)
                    if part then
                        if key=="Hit"    then return CFrame.new(self.UnitRay.Origin,part.Position) end
                        if key=="Target" then return part end
                    end
                end
            end
        end
        return orig(self,key)
    end)
end)

-- ── Config ─────────────────────────────────────────────
applyPanelOpacity=function(pct)
    local t=1-math.clamp(pct/100,0,1)
    if Panel    then Panel.BackgroundTransparency=t end
    if TitleBar then TitleBar.BackgroundTransparency=t end
    if TitleFix then TitleFix.BackgroundTransparency=t end
end
local function buildConfigData()
    return {
        AB={Enabled=AB.Enabled,FOV=AB.FOV,Smoothness=AB.Smoothness,Damping=AB.Damping,
            Prediction=AB.Prediction,AutoPrediction=AB.AutoPrediction,TargetPart=AB.TargetPart,
            ShowFOVCircle=AB.ShowFOVCircle,CircleThickness=AB.CircleThickness,
            ShowTargetName=AB.ShowTargetName,ShowHitChance=AB.ShowHitChance,
            TeamCheck=AB.TeamCheck,CursorLock=AB.CursorLock,HoldToAim=AB.HoldToAim,VisCheck=AB.VisCheck},
        ESP={Enabled=ESP.Enabled,ShowNames=ESP.ShowNames,ShowDistance=ESP.ShowDistance,
            ShowHealthBar=ESP.ShowHealthBar,ShowTracelines=ESP.ShowTracelines,
            ShowSkeleton=ESP.ShowSkeleton,ShowSnapline=ESP.ShowSnapline,ShowBoxes=ESP.ShowBoxes,
            MaxDistance=ESP.MaxDistance,FillTransparency=ESP.FillTransparency,
            OutlineTransparency=ESP.OutlineTransparency,TeamCheck=ESP.TeamCheck},
        MISC={Speed=MISC.Speed,SpeedEnabled=MISC.SpeedEnabled,JumpPower=MISC.JumpPower,
            JumpEnabled=MISC.JumpEnabled,InfiniteJump=MISC.InfiniteJump,NoClip=MISC.NoClip,
            Fly=MISC.Fly,FlySpeed=MISC.FlySpeed,AntiAFK=MISC.AntiAFK,GodMode=MISC.GodMode,
            AntiRagdoll=MISC.AntiRagdoll,AutoShoot=MISC.AutoShoot,AutoShootRate=MISC.AutoShootRate,
            TriggerBot=MISC.TriggerBot,TriggerFOV=MISC.TriggerFOV,HitboxExpand=MISC.HitboxExpand,
            HitboxSize=MISC.HitboxSize,CamFOV=MISC.CamFOV,CamFOVVal=MISC.CamFOVVal,
            SpectatorAlert=MISC.SpectatorAlert,PanelOpacity=MISC.PanelOpacity},
        SA={Enabled=SA.Enabled},MB={Enabled=MB.Enabled,MaxMissDist=MB.MaxMissDist},
        RADAR={Enabled=RADAR.Enabled,Range=RADAR.Range},
        CROSS={Enabled=CROSS.Enabled,Style=CROSS.Style,Size=CROSS.Size,
            Thickness=CROSS.Thickness,Gap=CROSS.Gap},
    }
end
local function applyConfigData(data)
    if data.AB   then for k,v in pairs(data.AB)   do if AB[k]~=nil   then AB[k]=v   end end end
    if data.ESP  then for k,v in pairs(data.ESP)  do if ESP[k]~=nil  then ESP[k]=v  end end end
    if data.MISC then for k,v in pairs(data.MISC) do if MISC[k]~=nil then MISC[k]=v end end end
    if data.SA   then for k,v in pairs(data.SA)   do if SA[k]~=nil   then SA[k]=v   end end end
    if data.MB   then for k,v in pairs(data.MB)   do if MB[k]~=nil   then MB[k]=v   end end end
    if data.RADAR then for k,v in pairs(data.RADAR) do if RADAR[k]~=nil then RADAR[k]=v end end end
    if data.CROSS then for k,v in pairs(data.CROSS) do if CROSS[k]~=nil then CROSS[k]=v end end end
    updateFOV(); applyMovement(); applyPanelOpacity(MISC.PanelOpacity)
    buildCrosshair(); RadarFrame.Visible=RADAR.Enabled
    if MISC.CamFOV then Camera.FieldOfView=MISC.CamFOVVal end
end
local function saveProfile(name)
    local ok=pcall(writefile,"skullzz_"..name..".json",HttpService:JSONEncode(buildConfigData()))
    if notify then notify(ok and "Saved: "..name or "Save failed (no writefile)") end
end
local function loadProfile(name)
    local ok,raw=pcall(readfile,"skullzz_"..name..".json")
    if not ok or not raw or raw=="" then if notify then notify("No profile: "..name) end; return end
    local ok2,data=pcall(HttpService.JSONDecode,HttpService,raw)
    if not ok2 then if notify then notify("Parse error") end; return end
    applyConfigData(data); if notify then notify("Loaded: "..name) end
end

-- ── Cleanup (close / panic) ────────────────────────────
cleanupAll=function()
    AB.Enabled=false; ESP.Enabled=false; SA.Enabled=false; MB.Enabled=false
    MISC.Fly=false; MISC.NoClip=false; MISC.GodMode=false; MISC.AutoShoot=false
    MISC.TriggerBot=false; MISC.InfiniteJump=false; MISC.Fullbright=false
    MISC.HitboxExpand=false; MISC.SpeedEnabled=false; MISC.JumpEnabled=false
    MISC.CamFOV=false; MISC.AntiRagdoll=false; MISC.SpectatorAlert=false
    RAGE.Active=false; RADAR.Enabled=false; CROSS.Enabled=false; statsEnabled=false
    -- feature modules (Rebirth/NPC/Troll) clean themselves up via hooks
    for _,fn in ipairs(cleanupHooks) do pcall(fn) end
    disableFly(); setClickTp(false); updateFOV(); buildCrosshair()
    -- Restore
    local tbl={}; for p in pairs(ESPObjects) do table.insert(tbl,p) end
    for _,p in ipairs(tbl) do RemoveESP(p) end
    Lighting.Brightness=origLight.B; Lighting.Ambient=origLight.A; Lighting.FogEnd=origLight.FE
    Camera.FieldOfView=70; RadarFrame.Visible=false; SpecLabel.Visible=false
    pcall(function() Camera.CameraType=origCamType end)
    applyMovement()
end

-- (Rebirth / NPC / Troll feature logic lives inside their own page
--  do..end blocks near the end of the file, to keep _hub under Luau's
--  200-local limit. Each registers a cleanupHooks callback.)

-- ── Rage Mode ──────────────────────────────────────────
local function applyRage(on)
    RAGE.Active=on
    if on then
        ragePreFOV=AB.FOV; ragePreSmooth=AB.Smoothness; ragePreDamp=AB.Damping; ragePreAS=MISC.AutoShoot
        AB.FOV=600; AB.Smoothness=1.0; AB.Damping=1.0; MISC.AutoShoot=true
    else
        AB.FOV=ragePreFOV or AB.FOV; AB.Smoothness=ragePreSmooth or AB.Smoothness
        AB.Damping=ragePreDamp or AB.Damping; MISC.AutoShoot=ragePreAS or MISC.AutoShoot
    end
    updateFOV(); if notify then notify("RAGE "..(on and "ON" or "OFF")) end
end

-- ── Vis Check ──────────────────────────────────────────
local function isVisible(part)
    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return true end
    local origin=hrp.Position; local target=part.Position; local dir=target-origin
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={LP.Character}
    local res=workspace:Raycast(origin,dir*0.99,params)
    if res then
        local hitChar=res.Instance:FindFirstAncestorOfClass("Model")
        return hitChar==part.Parent
    end
    return true
end

-- ── Aimbot Targeting ───────────────────────────────────
local function getOrigin()
    if AB.CursorLock then local m=UserInputService:GetMouseLocation(); return Vector2.new(m.X,m.Y) end
    return Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
end
local function playerAlive(p)
    local c=p.Character; if not c then return false end
    local h=c:FindFirstChildOfClass("Humanoid"); return h and h.Health>0
end
local function getTargetList()
    local origin=getOrigin(); local out={}
    for _,pl in ipairs(sharedPlayers) do
        repeat
            if pl==LP then break end
            if AB.TeamCheck and pl.Team==LP.Team then break end
            local char=pl.Character; if not char then break end
            local hum=char:FindFirstChildOfClass("Humanoid")
            local part=char:FindFirstChild(AB.TargetPart)
            if not hum or hum.Health<=0 or not part then break end
            if AB.VisCheck and not isVisible(part) then break end
            local sp,on=Camera:WorldToViewportPoint(part.Position); if not on then break end
            local d=(Vector2.new(sp.X,sp.Y)-origin).Magnitude
            if d<AB.FOV then table.insert(out,{player=pl,dist=d}) end
        until true
    end
    table.sort(out,function(a,b) return a.dist<b.dist end)
    return out
end
local function getClosestTarget()
    if cycledTarget and tick()<cycleExpiry then
        if playerAlive(cycledTarget) then
            local char=cycledTarget.Character
            local part=char and char:FindFirstChild(AB.TargetPart)
            if part then
                local sp,on=Camera:WorldToViewportPoint(part.Position)
                if on and (Vector2.new(sp.X,sp.Y)-getOrigin()).Magnitude<AB.FOV then return cycledTarget end
            end
        end
        cycledTarget=nil
    end
    local origin=getOrigin(); local bestDist=AB.FOV; local best=nil
    for _,pl in ipairs(sharedPlayers) do
        repeat
            if pl==LP then break end
            if AB.TeamCheck and pl.Team==LP.Team then break end
            local char=pl.Character; if not char then break end
            local hum=char:FindFirstChildOfClass("Humanoid")
            local part=char:FindFirstChild(AB.TargetPart)
            if not hum or hum.Health<=0 or not part then break end
            if AB.VisCheck and not isVisible(part) then break end
            local sp,on=Camera:WorldToViewportPoint(part.Position); if not on then break end
            local d=(Vector2.new(sp.X,sp.Y)-origin).Magnitude
            if d<bestDist then bestDist=d; best=pl end
        until true
    end
    if AB.CursorLock and best then stickyTarget=best; stickyTargetExpiry=tick()+0.3 end
    return best
end

local function doShoot()
    if isShooting then return end; isShooting=true
    local pos=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    pcall(function() VirtualUser:Button1Down(pos,Camera.CFrame) end)
    task.delay(0.06,function()
        pcall(function() VirtualUser:Button1Up(pos,Camera.CFrame) end)
        task.delay(0.03,function() isShooting=false end)
    end)
end

-- ── Aimbot RenderStep ──────────────────────────────────
RunService:BindToRenderStep("SkullzzAB",Enum.RenderPriority.Last.Value,function(dt)
    local shouldAim=AB.Enabled and (not AB.HoldToAim or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
    if shouldAim then
        currentTarget=getClosestTarget()
    else
        currentTarget=nil
    end

    if currentTarget~=prevAimbotTarget then
        targetPrevPos=nil; prevTargetScreenP=nil
        prevAimbotTarget=currentTarget
    end

    if currentTarget then
        local char=currentTarget.Character
        local part=char and char:FindFirstChild(AB.TargetPart)
        if part then
            local sp,_=Camera:WorldToViewportPoint(part.Position)
            local sp2=Vector2.new(sp.X,sp.Y)
            if prevTargetScreenP then
                local sv=(sp2-prevTargetScreenP).Magnitude/math.max(dt,0.001)
                targetScreenVelMag=targetScreenVelMag*0.7+sv*0.3
                if AB.AutoPrediction then AB.Prediction=math.clamp(math.round(targetScreenVelMag/80),0,8) end
            end
            prevTargetScreenP=sp2
            local aimPos=part.Position
            if targetPrevPos and AB.Prediction>0 then
                local vel=(aimPos-targetPrevPos)/math.max(dt,0.001)
                aimPos=aimPos+vel*(AB.Prediction/60)
            end
            targetPrevPos=part.Position
            -- Take camera control so Roblox's camera script can't fight us
            if Camera.CameraType~=Enum.CameraType.Scriptable then
                Camera.CameraType=Enum.CameraType.Scriptable
            end
            -- LookVector lerp: only rotates toward target, no position/roll drift
            local alpha=math.clamp(1-AB.Smoothness^(dt*60), 0.02, 1)
            local cf=Camera.CFrame
            local targetLV=(aimPos-cf.Position).Unit
            local newLV=cf.LookVector:Lerp(targetLV, alpha)
            if newLV.Magnitude>0 then
                Camera.CFrame=CFrame.new(cf.Position, cf.Position+newLV.Unit)
            end
            -- Hit chance
            local toDist=(part.Position-(LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character.HumanoidRootPart.Position or part.Position)).Magnitude
            local dF=math.clamp(1-toDist/600,0,1)
            local sF=math.clamp(1-(Vector2.new(sp.X,sp.Y)-Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)).Magnitude/math.max(AB.FOV,1),0,1)
            local vF=math.clamp(1-camSpringVel.Magnitude*2,0,1)
            hitChancePct=math.round((dF*0.3+sF*0.4+vF*0.3)*100)
            if AB.ShowTargetName then
                TargetLabel.Text="🎯  "..currentTarget.DisplayName
                TargetLabel.Position=UDim2.new(0.5,0,0.5,-AB.FOV-8)
                TargetLabel.Visible=true
            else TargetLabel.Visible=false end
            if AB.ShowHitChance then
                local hc=hitChancePct/100
                HitLabel.Text=hitChancePct.."%"
                HitLabel.TextColor3=Color3.fromRGB(math.round((1-hc)*255),math.round(hc*200),80)
                HitLabel.Position=UDim2.new(0.5,0,0.5,AB.FOV+10)
                HitLabel.Visible=true
            else HitLabel.Visible=false end
        end
    else
        -- Restore normal camera when not locked
        if Camera.CameraType==Enum.CameraType.Scriptable then
            Camera.CameraType=origCamType
        end
        TargetLabel.Visible=false; HitLabel.Visible=false; hitChancePct=0
    end

    -- Fly input
    if MISC.Fly then
        if not flyBV then enableFly() end
        if flyBV then
            local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local lv=Camera.CFrame.LookVector; local rv=Camera.CFrame.RightVector
                local hl=Vector3.new(lv.X,0,lv.Z); local hr=Vector3.new(rv.X,0,rv.Z)
                if hl.Magnitude>0 then hl=hl.Unit end; if hr.Magnitude>0 then hr=hr.Unit end
                local dir=Vector3.new(0,0,0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+hl end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-hl end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-hr end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+hr end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir+Vector3.new(0,-1,0) end
                if dir.Magnitude>0 then dir=dir.Unit end
                flyBV.Velocity=dir*MISC.FlySpeed; flyBG.CFrame=hrp.CFrame
            end
        end
    end
end)

-- ── Single Consolidated Heartbeat (performance) ────────
RunService.Heartbeat:Connect(function(dt)
    frameCount=frameCount+1
    local now=tick()

    -- cache the player list ONCE per frame, and only when a feature needs it
    -- (avoids 4 separate GetPlayers() table allocations every frame)
    local players
    if MISC.TriggerBot or MISC.HitboxExpand or RADAR.Enabled or ESP.Enabled or AB.Enabled then
        players=Players:GetPlayers(); sharedPlayers=players
    end

    -- ── Always: auto-shoot / triggerbot / godmode / noclip
    if MISC.AutoShoot and AB.Enabled and currentTarget and now-lastAutoShot>=MISC.AutoShootRate then
        lastAutoShot=now; doShoot()
    end
    if MISC.TriggerBot and now-lastTriggerShot>=MISC.AutoShootRate then
        local mpos=UserInputService:GetMouseLocation()
        local curs=Vector2.new(mpos.X,mpos.Y)
        for _,pl in ipairs(players) do
            repeat
                if pl==LP then break end
                local char=pl.Character; if not char then break end
                local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then break end
                for _,pn in ipairs({"Head","UpperTorso","Torso","HumanoidRootPart"}) do
                    local part=char:FindFirstChild(pn)
                    if part then
                        local sp,on=Camera:WorldToViewportPoint(part.Position)
                        if on and (Vector2.new(sp.X,sp.Y)-curs).Magnitude<=MISC.TriggerFOV then
                            lastTriggerShot=now; doShoot(); break
                        end
                    end
                end
            until true
        end
    end
    if MISC.GodMode then
        local char=LP.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MaxHealth>0 and hum.Health<hum.MaxHealth then hum.Health=hum.MaxHealth end
    end
    if MISC.NoClip then
        local char=LP.Character
        if char then
            -- rebuild the cached part list ~twice a second instead of every frame
            if frameCount%30==0 or #noclipParts==0 then
                noclipParts={}
                for _,p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then noclipParts[#noclipParts+1]=p end
                end
            end
            for _,p in ipairs(noclipParts) do
                if p.CanCollide then p.CanCollide=false end  -- only write when needed
            end
        end
    elseif #noclipParts>0 then
        noclipParts={}  -- drop the cache when NoClip is off
    end

    -- ── Every 2 frames: snapline, stats, hitbox ──
    if frameCount%2==0 then
        -- Snapline
        if ESP.ShowSnapline and currentTarget then
            local char=currentTarget.Character
            local part=char and char:FindFirstChild(AB.TargetPart)
            if part then
                local sp,on=Camera:WorldToViewportPoint(part.Position)
                if on then
                    local vp=Camera.ViewportSize
                    drawLine(SnapLine,Vector2.new(vp.X/2,vp.Y),Vector2.new(sp.X,sp.Y),ESP.SkeletonColor)
                else SnapLine.Visible=false end
            else SnapLine.Visible=false end
        else SnapLine.Visible=false end
        -- Stats overlay
        StatsFrame.Visible=statsEnabled
        if statsEnabled then
            StatsLbl.Text="AB:"..(AB.Enabled and "ON" or "off")
                .."  SA:"..(SA.Enabled and "ON" or "off")
                .."  ESP:"..(ESP.Enabled and "ON" or "off")
        end
        -- Hitbox expand
        if MISC.HitboxExpand then
            for _,pl in ipairs(players) do
                if pl~=LP then
                    local char=pl.Character
                    if char then
                        local hrp=char:FindFirstChild("HumanoidRootPart")
                        -- only resize when it isn't already the target size (skip redundant writes)
                        if hrp and hrp.Size.X~=MISC.HitboxSize then
                            pcall(function() hrp.Size=Vector3.new(MISC.HitboxSize,MISC.HitboxSize,MISC.HitboxSize) end)
                        end
                    end
                end
            end
        end
    end

    -- ── Every 3 frames: radar ──
    if frameCount%3==0 then
        if not RADAR.Enabled then
            RadarFrame.Visible=false
            for _,d in pairs(radarDots) do d.Visible=false end
        else
            RadarFrame.Visible=true
            local localChar=LP.Character
            local localHRP=localChar and localChar:FindFirstChild("HumanoidRootPart")
            if localHRP then
                local camYaw=math.atan2(-Camera.CFrame.LookVector.X,-Camera.CFrame.LookVector.Z)
                local cosY,sinY=math.cos(-camYaw),math.sin(-camYaw)
                local used={}
                for _,pl in ipairs(players) do
                    repeat
                    if pl==LP then break end
                    local char=pl.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then if radarDots[pl] then radarDots[pl].Visible=false end; break end
                    local rel=hrp.Position-localHRP.Position
                    local rx=rel.X*cosY-rel.Z*sinY; local rz=rel.X*sinY+rel.Z*cosY
                    local half=RADAR.Size/2; local scale=half/RADAR.Range
                    local px=math.clamp(0.5+rx*scale/RADAR.Size,0.05,0.95)
                    local py=math.clamp(0.5+rz*scale/RADAR.Size,0.05,0.95)
                    local dot=radarDots[pl]
                    if not dot then
                        dot=Instance.new("Frame"); dot.Size=UDim2.new(0,6,0,6)
                        dot.AnchorPoint=Vector2.new(0.5,0.5); dot.BackgroundColor3=Color3.fromRGB(255,70,70)
                        dot.BorderSizePixel=0; dot.ZIndex=12; dot.Parent=RadarFrame
                        Instance.new("UICorner",dot).CornerRadius=UDim.new(0.5,0); radarDots[pl]=dot
                    end
                    dot.Position=UDim2.new(px,0,py,0); dot.Visible=true
                    dot.BackgroundColor3=currentTarget==pl and Color3.fromRGB(255,220,0) or Color3.fromRGB(255,70,70)
                    used[pl]=true
                    until true
                end
                for p,d in pairs(radarDots) do if not used[p] then d.Visible=false end end
            end
        end
    end

    -- ── Every 4 frames: ESP ──
    if frameCount%4==0 then
        if not ESP.Enabled then
            local tbl={}; for p in pairs(ESPObjects) do table.insert(tbl,p) end
            for _,p in ipairs(tbl) do RemoveESP(p) end
        else
            local localChar=LP.Character
            local localRoot=localChar and localChar:FindFirstChild("HumanoidRootPart")
            local vp=Camera.ViewportSize
            local bottom=Vector2.new(vp.X/2,vp.Y)
            for _,pl in ipairs(players) do
              repeat
                if pl==LP then break end
                if ESP.TeamCheck and pl.Team~=nil and pl.Team==LP.Team then RemoveESP(pl); break end
                local char=pl.Character
                local root=char and char:FindFirstChild("HumanoidRootPart")
                if not char or not root then RemoveESP(pl); break end
                local dist=localRoot and math.floor((localRoot.Position-root.Position).Magnitude) or 9999
                if dist>ESP.MaxDistance then
                    if ESPObjects[pl] then RemoveESP(pl) end; break
                end
                if not ESPObjects[pl] then CreateESP(pl) end
                local obj=ESPObjects[pl]; if not obj then break end
                if obj.Highlight then obj.Highlight.Enabled=true end
                if obj.Billboard then obj.Billboard.Enabled=ESP.ShowNames end
                if obj.HealthBG  then obj.HealthBG.Visible=ESP.ShowHealthBar end
                if obj.DistLabel then obj.DistLabel.Text=ESP.ShowDistance and (dist.." st") or "" end
                -- Health bar
                if obj.HealthFill and ESP.ShowHealthBar then
                    local hum=char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.MaxHealth>0 then
                        local pct=math.clamp(hum.Health/hum.MaxHealth,0,1)
                        obj.HealthFill.Size=UDim2.new(pct,0,1,0)
                        obj.HealthFill.BackgroundColor3=Color3.fromRGB(math.round((1-pct)*255),math.round(pct*200),30)
                    end
                end
                -- Traceline
                if obj.TraceLine then
                    if ESP.ShowTracelines then
                        local sp,on=Camera:WorldToViewportPoint(root.Position)
                        if on then drawLine(obj.TraceLine,bottom,Vector2.new(sp.X,sp.Y),ESP.TraceColor)
                        else obj.TraceLine.Visible=false end
                    else obj.TraceLine.Visible=false end
                end
                -- Skeleton
                if obj.SkeletonLines then
                    if ESP.ShowSkeleton then
                        local bones=obj.Bones or BONES_R15
                        for i,bone in ipairs(bones) do
                            local pa=char:FindFirstChild(bone[1]); local pb=char:FindFirstChild(bone[2])
                            local line=obj.SkeletonLines[i]
                            if pa and pb and line then
                                local sa,oa=Camera:WorldToViewportPoint(pa.Position)
                                local sb,ob=Camera:WorldToViewportPoint(pb.Position)
                                if oa and ob then drawLine(line,Vector2.new(sa.X,sa.Y),Vector2.new(sb.X,sb.Y),ESP.SkeletonColor)
                                else line.Visible=false end
                            elseif line then line.Visible=false end
                        end
                    else for _,l in ipairs(obj.SkeletonLines) do l.Visible=false end end
                end
                -- 2D Box ESP
                if obj.BoxLines then
                    if ESP.ShowBoxes then
                        local head=char:FindFirstChild("Head")
                        if head then
                            local topSP,topOn=Camera:WorldToViewportPoint(head.Position+Vector3.new(0,1.5,0))
                            local botSP,botOn=Camera:WorldToViewportPoint(root.Position+Vector3.new(0,-3,0))
                            if topOn and botOn then
                                local h=math.abs(botSP.Y-topSP.Y); local w=h*0.45
                                local cx=(topSP.X+botSP.X)/2; local ty=math.min(topSP.Y,botSP.Y); local by=ty+h
                                local lx=cx-w/2; local rx=cx+w/2
                                drawLine(obj.BoxLines[1],Vector2.new(lx,ty),Vector2.new(rx,ty),ESP.BoxColor)
                                drawLine(obj.BoxLines[2],Vector2.new(lx,by),Vector2.new(rx,by),ESP.BoxColor)
                                drawLine(obj.BoxLines[3],Vector2.new(lx,ty),Vector2.new(lx,by),ESP.BoxColor)
                                drawLine(obj.BoxLines[4],Vector2.new(rx,ty),Vector2.new(rx,by),ESP.BoxColor)
                            else for _,l in ipairs(obj.BoxLines) do l.Visible=false end end
                        end
                    else for _,l in ipairs(obj.BoxLines) do l.Visible=false end end
                end
              until true
            end
        end
    end

    -- ── Every 6 frames: fullbright, camera fov ──
    -- only WRITE when the feature is on; restoring is done once by the toggle /
    -- cleanup, so we never fight the game's own lighting/FOV while disabled
    if frameCount%6==0 then
        if MISC.Fullbright then
            Lighting.Brightness=10; Lighting.Ambient=Color3.fromRGB(200,200,200); Lighting.FogEnd=999999
        end
        if MISC.CamFOV then Camera.FieldOfView=MISC.CamFOVVal end
    end

    -- ── Every 30 frames: spectator detect ──
    if frameCount%30==0 then
        if MISC.SpectatorAlert then
            local specs={}
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl~=LP then
                    local age=now-(playerJoinTimes[pl] or now)
                    if not pl.Character and age>10 then
                        table.insert(specs,pl.DisplayName)
                        if not lastSpecNotif[pl] or now-lastSpecNotif[pl]>25 then
                            lastSpecNotif[pl]=now; if notify then notify("Spectator: "..pl.DisplayName,4) end
                        end
                    end
                end
            end
            if #specs>0 then
                SpecLabel.Text="👁  "..table.concat(specs,", "); SpecLabel.Visible=true
            else SpecLabel.Visible=false end
        else SpecLabel.Visible=false end
    end
end)

-- ── Notifications ──────────────────────────────────────
do
    local NW,NH=220,34
    notify=function(msg,duration)
        duration=duration or 2.5
        local f=Instance.new("Frame"); f.Size=UDim2.new(0,NW,0,NH)
        f.Position=UDim2.new(1,NW+10,1,-(52+#activeNotifs*(NH+6)))
        f.BackgroundColor3=DARKER; f.BorderSizePixel=0; f.ZIndex=30; f.Parent=Gui
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,7)
        local st=Instance.new("UIStroke"); st.Color=ACCENT; st.Thickness=1; st.Parent=f
        local ico=Instance.new("TextLabel"); ico.Size=UDim2.new(0,30,1,0)
        ico.BackgroundTransparency=1; ico.Text="💀"; ico.TextSize=14; ico.Font=Enum.Font.GothamBold
        ico.ZIndex=31; ico.Parent=f
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-36,1,0)
        lbl.Position=UDim2.new(0,32,0,0); lbl.BackgroundTransparency=1; lbl.Text=msg
        lbl.TextColor3=WHITE; lbl.TextSize=11; lbl.Font=Enum.Font.Gotham
        lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=31; lbl.Parent=f
        local targetY=-(52+#activeNotifs*(NH+6)); table.insert(activeNotifs,f)
        TweenService:Create(f,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
            Position=UDim2.new(1,-NW-10,1,targetY)}):Play()
        task.delay(duration,function()
            TweenService:Create(f,TweenInfo.new(0.2),{Position=UDim2.new(1,NW+10,1,targetY)}):Play()
            task.delay(0.25,function()
                for i,x in ipairs(activeNotifs) do if x==f then
                    table.remove(activeNotifs,i); f:Destroy()
                    for j=i,#activeNotifs do
                        TweenService:Create(activeNotifs[j],TweenInfo.new(0.15),{
                            Position=UDim2.new(1,-NW-10,1,-(52+(j-1)*(NH+6)))}):Play()
                    end; break
                end end
            end)
        end)
    end
end

-- ── Hotkeys ────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(inp,consumed)
    if bindCapture then
        if inp.UserInputType==Enum.UserInputType.Keyboard then
            bindCapture(inp.KeyCode); bindCapture=nil
        end; return
    end
    if consumed or inp.UserInputType~=Enum.UserInputType.Keyboard then return end
    local kc=inp.KeyCode
    if kc==KEYBINDS.panel then
        if toggleMin then toggleMin() end
    elseif kc==KEYBINDS.aimbot then
        AB.Enabled=not AB.Enabled; updateFOV(); notify("Aimbot "..(AB.Enabled and "ON" or "OFF"))
    elseif kc==KEYBINDS.panic then
        cleanupAll(); RunService:UnbindFromRenderStep("SkullzzAB"); Gui:Destroy()
    elseif kc==KEYBINDS.rage then
        applyRage(not RAGE.Active)
    elseif kc==KEYBINDS.cycle then
        local list=getTargetList(); if #list==0 then return end
        local idx=1
        for i,entry in ipairs(list) do if entry.player==cycledTarget then idx=i%#list+1; break end end
        cycledTarget=list[idx].player; cycleExpiry=tick()+5
        notify("Target: "..cycledTarget.DisplayName)
    end
end)

-- ═══════════════════════════════════════════════════════
--  GUI — Vape v4 style
-- ═══════════════════════════════════════════════════════
local PW=700; local PH=480; local TH=38; local SBW=140

Panel=Instance.new("Frame"); Panel.Size=UDim2.new(0,PW,0,PH)
Panel.AnchorPoint=Vector2.new(0.5,0.5)
Panel.Position=UDim2.new(0.5,0,0.5,0)
Panel.BackgroundColor3=DARK; Panel.BorderSizePixel=0
Panel.Active=true; Panel.Draggable=true; Panel.Parent=Gui
Instance.new("UICorner",Panel).CornerRadius=UDim.new(0,10)
local PanelStroke=Instance.new("UIStroke"); PanelStroke.Color=BORDER; PanelStroke.Thickness=1; PanelStroke.Parent=Panel
table.insert(accentEls,PanelStroke)

-- Title bar
TitleBar=Instance.new("Frame"); TitleBar.Size=UDim2.new(1,0,0,TH)
TitleBar.BackgroundColor3=DARKER; TitleBar.BorderSizePixel=0; TitleBar.Parent=Panel
Instance.new("UICorner",TitleBar).CornerRadius=UDim.new(0,10)
TitleFix=Instance.new("Frame"); TitleFix.Size=UDim2.new(1,0,0,10)
TitleFix.Position=UDim2.new(0,0,1,-10); TitleFix.BackgroundColor3=DARKER
TitleFix.BorderSizePixel=0; TitleFix.Parent=TitleBar

local TitleIcon=Instance.new("ImageLabel"); TitleIcon.Size=UDim2.new(0,26,0,26)
TitleIcon.AnchorPoint=Vector2.new(0,0.5); TitleIcon.Position=UDim2.new(0,10,0.5,0)
TitleIcon.BackgroundTransparency=1; TitleIcon.Image=SKULL_IMG
TitleIcon.ScaleType=Enum.ScaleType.Fit; TitleIcon.Parent=TitleBar
local TitleText=Instance.new("TextLabel"); TitleText.Size=UDim2.new(0,140,1,0)
TitleText.Position=UDim2.new(0,34,0,0); TitleText.BackgroundTransparency=1
TitleText.Text="SKULLZZ HUB"; TitleText.TextColor3=WHITE; TitleText.TextSize=13
TitleText.Font=Enum.Font.GothamBold; TitleText.TextXAlignment=Enum.TextXAlignment.Left; TitleText.Parent=TitleBar

local FpsLabel=Instance.new("TextLabel"); FpsLabel.Size=UDim2.new(0,120,1,0)
FpsLabel.Position=UDim2.new(0.5,-60,0,0); FpsLabel.BackgroundTransparency=1
FpsLabel.TextColor3=DIM; FpsLabel.TextSize=9; FpsLabel.Font=Enum.Font.Gotham; FpsLabel.Parent=TitleBar
do
    local acc,samp,last=0,0,0
    RunService.Heartbeat:Connect(function(dt)
        acc=acc+1/dt; samp=samp+1; local n=tick()
        if n-last>=0.5 then
            local ping=0; pcall(function() ping=math.round(LP:GetNetworkPing()*1000) end)
            FpsLabel.Text=math.round(acc/samp).." fps  "..ping.."ms"
            acc,samp,last=0,0,n
        end
    end)
end

local CloseBtn=Instance.new("TextButton"); CloseBtn.Size=UDim2.new(0,22,0,22)
CloseBtn.Position=UDim2.new(1,-28,0.5,-11); CloseBtn.BackgroundColor3=Color3.fromRGB(185,50,50)
CloseBtn.Text="✕"; CloseBtn.TextColor3=WHITE; CloseBtn.TextSize=12; CloseBtn.Font=Enum.Font.GothamBold
CloseBtn.BorderSizePixel=0; CloseBtn.ZIndex=2; CloseBtn.Parent=TitleBar
Instance.new("UICorner",CloseBtn).CornerRadius=UDim.new(0,5)
CloseBtn.MouseButton1Click:Connect(function()
    -- full teardown: turn off every feature, stop the render loop, then remove the GUI
    pcall(cleanupAll)
    pcall(function() RunService:UnbindFromRenderStep("SkullzzAB") end)
    pcall(function() Gui:Destroy() end)
end)

local MinBtn=Instance.new("TextButton"); MinBtn.Size=UDim2.new(0,22,0,22)
MinBtn.Position=UDim2.new(1,-54,0.5,-11); MinBtn.BackgroundColor3=MID
MinBtn.Text="−"; MinBtn.TextColor3=DIM; MinBtn.TextSize=15; MinBtn.Font=Enum.Font.GothamBold
MinBtn.BorderSizePixel=0; MinBtn.ZIndex=2; MinBtn.Parent=TitleBar
Instance.new("UICorner",MinBtn).CornerRadius=UDim.new(0,5)

local FullBtn=Instance.new("TextButton"); FullBtn.Size=UDim2.new(0,22,0,22)
FullBtn.Position=UDim2.new(1,-80,0.5,-11); FullBtn.BackgroundColor3=MID
FullBtn.Text="⛶"; FullBtn.TextColor3=DIM; FullBtn.TextSize=12; FullBtn.Font=Enum.Font.GothamBold
FullBtn.BorderSizePixel=0; FullBtn.ZIndex=2; FullBtn.Parent=TitleBar
Instance.new("UICorner",FullBtn).CornerRadius=UDim.new(0,5)

local minimized=false
local fullscreen=false
local function applyPanelSize()
    local w,h=PW,PH
    if fullscreen then
        local vp=(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280,720)
        w=math.floor(vp.X*0.92); h=math.floor(vp.Y*0.9)
    end
    TweenService:Create(Panel,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{
        Size=UDim2.new(0,w,0,h)}):Play()
end

-- ── Minimized skull icon (click to reopen) ─────────────
local MinIcon=Instance.new("TextButton"); MinIcon.Size=UDim2.new(0,48,0,48)
MinIcon.AnchorPoint=Vector2.new(0,0.5); MinIcon.Position=UDim2.new(0,18,0.5,0)
MinIcon.BackgroundColor3=DARKER; MinIcon.AutoButtonColor=false
MinIcon.Text=""; MinIcon.BorderSizePixel=0
MinIcon.Visible=false; MinIcon.Active=true; MinIcon.Draggable=true
MinIcon.ZIndex=60; MinIcon.Parent=Gui
Instance.new("UICorner",MinIcon).CornerRadius=UDim.new(0,12)
local MinImg=Instance.new("ImageLabel"); MinImg.Size=UDim2.new(1,-6,1,-6)
MinImg.AnchorPoint=Vector2.new(0.5,0.5); MinImg.Position=UDim2.new(0.5,0,0.5,0)
MinImg.BackgroundTransparency=1; MinImg.Image=SKULL_IMG
MinImg.ScaleType=Enum.ScaleType.Fit; MinImg.ZIndex=61; MinImg.Parent=MinIcon
local MinIconStroke=Instance.new("UIStroke",MinIcon)
MinIconStroke.Color=ACCENT; MinIconStroke.Thickness=1.5
table.insert(accentEls,MinIconStroke)

local function setMinimized(v)
    minimized=v
    panelVisible=not v
    if v then
        -- shrink-fade the panel out, pop the icon in
        Panel.Visible=false
        MinIcon.Visible=true
        MinIcon.Size=UDim2.new(0,0,0,0)
        TweenService:Create(MinIcon,TweenInfo.new(0.18,Enum.EasingStyle.Back),
            {Size=UDim2.new(0,48,0,48)}):Play()
    else
        MinIcon.Visible=false
        Panel.Visible=true
    end
    pcall(function() FOVCircle.Visible=panelVisible and AB.ShowFOVCircle and AB.Enabled end)
end
toggleMin=function() setMinimized(not minimized) end
MinBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
MinIcon.MouseButton1Click:Connect(function() setMinimized(false) end)
-- subtle hover feedback on the icon
MinIcon.MouseEnter:Connect(function()
    TweenService:Create(MinIcon,TweenInfo.new(0.12),{BackgroundColor3=MID}):Play()
end)
MinIcon.MouseLeave:Connect(function()
    TweenService:Create(MinIcon,TweenInfo.new(0.12),{BackgroundColor3=DARKER}):Play()
end)

FullBtn.MouseButton1Click:Connect(function()
    fullscreen=not fullscreen
    FullBtn.TextColor3=fullscreen and WHITE or DIM
    FullBtn.BackgroundColor3=fullscreen and ACCENT or MID
    applyPanelSize()
end)

-- Body area
local Body=Instance.new("Frame"); Body.Size=UDim2.new(1,0,1,-TH)
Body.Position=UDim2.new(0,0,0,TH); Body.BackgroundTransparency=1
Body.ClipsDescendants=true; Body.Parent=Panel

-- ── Left Sidebar (scrollable for many game tabs) ───────
local Sidebar=Instance.new("ScrollingFrame"); Sidebar.Size=UDim2.new(0,SBW,1,0)
Sidebar.BackgroundColor3=DARKER; Sidebar.BorderSizePixel=0; Sidebar.Parent=Body
Sidebar.ScrollBarThickness=3; Sidebar.ScrollBarImageColor3=ACCENT
Sidebar.ScrollingDirection=Enum.ScrollingDirection.Y
Sidebar.CanvasSize=UDim2.new(0,0,0,0); Sidebar.AutomaticCanvasSize=Enum.AutomaticSize.Y
local SB_Layout=Instance.new("UIListLayout"); SB_Layout.Padding=UDim.new(0,0)
SB_Layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
SB_Layout.SortOrder=Enum.SortOrder.LayoutOrder; SB_Layout.Parent=Sidebar
local SideDiv=Instance.new("Frame"); SideDiv.Size=UDim2.new(0,1,1,0)
SideDiv.Position=UDim2.new(0,SBW,0,0); SideDiv.BackgroundColor3=BORDER
SideDiv.BorderSizePixel=0; SideDiv.Parent=Body

-- Active category indicator line (re-parented into the active button so it
-- scrolls with the list and always tracks the selection)
local SideIndicator=Instance.new("Frame"); SideIndicator.Size=UDim2.new(0,3,0,30)
SideIndicator.Position=UDim2.new(0,0,0.5,-15); SideIndicator.BackgroundColor3=ACCENT
SideIndicator.BorderSizePixel=0; SideIndicator.ZIndex=3
table.insert(accentEls,SideIndicator)

-- ── Content Area ───────────────────────────────────────
local ContentArea=Instance.new("Frame")
ContentArea.Size=UDim2.new(1,-SBW-1,1,0)
ContentArea.Position=UDim2.new(0,SBW+1,0,0)
ContentArea.BackgroundTransparency=1; ContentArea.ClipsDescendants=true; ContentArea.Parent=Body

-- ── UI helpers (used by both pages and module cards) ───
local _ord=0; local function O() _ord=_ord+1; return _ord end

local function makeToggle(parent,label,default,onChange,lo)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,28)
    row.BackgroundTransparency=1; row.LayoutOrder=lo or O(); row.Parent=parent
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-52,1,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=Color3.fromRGB(160,160,195)
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,44,0,20)
    btn.Position=UDim2.new(1,-44,0.5,-10); btn.BackgroundColor3=default and ACCENT or MID
    btn.Text=default and "ON" or "OFF"; btn.TextColor3=WHITE; btn.TextSize=9
    btn.Font=Enum.Font.GothamBold; btn.BorderSizePixel=0; btn.Parent=row
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
    local state=default
    btn.MouseButton1Click:Connect(function()
        state=not state
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=state and ACCENT or MID}):Play()
        btn.Text=state and "ON" or "OFF"; onChange(state)
    end)
    return btn
end

local function makeSlider(parent,label,min,max,default,step,fmt,onChange,lo)
    local c=Instance.new("Frame"); c.Size=UDim2.new(1,0,0,44)
    c.BackgroundTransparency=1; c.LayoutOrder=lo or O(); c.Parent=parent
    local function fv(v) return fmt and string.format(fmt,v) or tostring(v) end
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,16)
    lbl.BackgroundTransparency=1; lbl.Text=label.."  "..fv(default)
    lbl.TextColor3=Color3.fromRGB(160,160,195); lbl.TextSize=10; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=c
    local track=Instance.new("Frame"); track.Size=UDim2.new(1,0,0,5)
    track.Position=UDim2.new(0,0,0,24); track.BackgroundColor3=MID; track.BorderSizePixel=0; track.Parent=c
    Instance.new("UICorner",track).CornerRadius=UDim.new(0,3)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3=ACCENT; fill.BorderSizePixel=0; fill.Parent=track
    Instance.new("UICorner",fill).CornerRadius=UDim.new(0,3)
    local thumb=Instance.new("TextButton"); thumb.Size=UDim2.new(0,12,0,12)
    thumb.AnchorPoint=Vector2.new(0.5,0.5); thumb.Position=UDim2.new((default-min)/(max-min),0,0.5,0)
    thumb.BackgroundColor3=WHITE; thumb.Text=""; thumb.BorderSizePixel=0; thumb.Parent=track
    Instance.new("UICorner",thumb).CornerRadius=UDim.new(0.5,0)
    local dragging=false
    thumb.MouseButton1Down:Connect(function() dragging=true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging or inp.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local rel=math.clamp((inp.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local value=min+math.round((rel*(max-min))/step)*step
        fill.Size=UDim2.new(rel,0,1,0); thumb.Position=UDim2.new(rel,0,0.5,0)
        lbl.Text=label.."  "..fv(value); onChange(value)
    end)
end

local function makeColorRow(parent,label,presets,onChange,lo)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,46)
    row.BackgroundTransparency=1; row.LayoutOrder=lo or O(); row.Parent=parent
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,14)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=Color3.fromRGB(160,160,195)
    lbl.TextSize=10; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
    local selDot=nil
    for i,color in ipairs(presets) do
        local sw=Instance.new("Frame"); sw.Size=UDim2.new(0,22,0,22)
        sw.Position=UDim2.new(0,(i-1)*28,0,16); sw.BackgroundColor3=color; sw.BorderSizePixel=0; sw.Parent=row
        Instance.new("UICorner",sw).CornerRadius=UDim.new(0,5)
        local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,6,0,6)
        dot.AnchorPoint=Vector2.new(0.5,0.5); dot.Position=UDim2.new(0.5,0,0.5,0)
        dot.BackgroundColor3=WHITE; dot.BorderSizePixel=0; dot.Visible=false; dot.Parent=sw
        Instance.new("UICorner",dot).CornerRadius=UDim.new(0.5,0)
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
        btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=sw
        btn.MouseButton1Click:Connect(function()
            onChange(color); if selDot then selDot.Visible=false end; dot.Visible=true; selDot=dot
        end)
    end
end

local function makeDivider(parent,text,lo)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,20)
    f.BackgroundTransparency=1; f.LayoutOrder=lo or O(); f.Parent=parent
    local line=Instance.new("Frame"); line.Size=UDim2.new(1,0,0,1)
    line.Position=UDim2.new(0,0,0.5,0); line.BackgroundColor3=BORDER; line.BorderSizePixel=0; line.Parent=f
    if text and text~="" then
        local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,#text*6.4+10,1,0)
        bg.AnchorPoint=Vector2.new(0,0.5); bg.Position=UDim2.new(0,6,0.5,0)
        bg.BackgroundColor3=DARK; bg.BorderSizePixel=0; bg.Parent=f
        local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,0,1,0)
        t.BackgroundTransparency=1; t.Text=text; t.TextColor3=DIM
        t.TextSize=9; t.Font=Enum.Font.GothamBold; t.Parent=bg
    end
end

local function makeButton(parent,label,onClick,lo)
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,30)
    btn.BackgroundColor3=MID; btn.Text=label; btn.TextColor3=WHITE; btn.TextSize=11
    btn.Font=Enum.Font.GothamBold; btn.BorderSizePixel=0; btn.LayoutOrder=lo or O(); btn.Parent=parent
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    local st=Instance.new("UIStroke"); st.Color=ACCENT; st.Thickness=1; st.Transparency=0.5; st.Parent=btn
    btn.MouseButton1Click:Connect(onClick); return btn
end

-- ── Category Page Factory ──────────────────────────────
local function makePage()
    local sf=Instance.new("ScrollingFrame"); sf.Size=UDim2.new(1,0,1,0)
    sf.BackgroundTransparency=1; sf.BorderSizePixel=0; sf.ScrollBarThickness=3
    sf.ScrollBarImageColor3=Color3.fromRGB(55,65,145); sf.CanvasSize=UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize=Enum.AutomaticSize.Y; sf.Visible=false; sf.Parent=ContentArea
    local lo=Instance.new("UIListLayout"); lo.Padding=UDim.new(0,4)
    lo.HorizontalAlignment=Enum.HorizontalAlignment.Center
    lo.SortOrder=Enum.SortOrder.LayoutOrder; lo.Parent=sf
    local pd=Instance.new("UIPadding"); pd.PaddingTop=UDim.new(0,8)
    pd.PaddingBottom=UDim.new(0,12); pd.PaddingLeft=UDim.new(0,10); pd.PaddingRight=UDim.new(0,10)
    pd.Parent=sf; return sf
end

-- ── Module Card Builder (Vape v4 style) ────────────────
-- Click = toggle, right-click / ⚙ = expand settings in-place
local function makeModCard(parent, modName, stateRef, stateKey, toggleFn, desc, settingsFn)
    local function isOn() return stateRef[stateKey] end
    local CARD_H=40
    local card=Instance.new("Frame"); card.Size=UDim2.new(1,0,0,CARD_H)
    card.BackgroundColor3=isOn() and CARD_ON or CARD_OFF; card.BorderSizePixel=0
    card.ClipsDescendants=true; card.LayoutOrder=O(); card.Parent=parent
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,7)

    -- Left accent bar (visible when enabled)
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(0,3,0,24)
    bar.Position=UDim2.new(0,6,0.5,-12); bar.BackgroundColor3=ACCENT; bar.BorderSizePixel=0
    bar.Parent=card; Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)
    bar.Visible=isOn(); table.insert(accentEls,bar)

    local nameLbl=Instance.new("TextLabel"); nameLbl.Size=UDim2.new(1,-54,0,CARD_H)
    nameLbl.Position=UDim2.new(0,18,0,0); nameLbl.BackgroundTransparency=1
    nameLbl.Text=modName; nameLbl.TextColor3=isOn() and WHITE or DIM
    nameLbl.TextSize=12; nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.Parent=card

    local gearBtn=Instance.new("TextButton"); gearBtn.Size=UDim2.new(0,28,0,28)
    gearBtn.Position=UDim2.new(1,-34,0.5,-14); gearBtn.BackgroundColor3=MID
    gearBtn.Text="⚙"; gearBtn.TextColor3=DIM; gearBtn.TextSize=13; gearBtn.Font=Enum.Font.GothamBold
    gearBtn.BorderSizePixel=0; gearBtn.ZIndex=2; gearBtn.Parent=card
    Instance.new("UICorner",gearBtn).CornerRadius=UDim.new(0,5)

    -- Expand panel (settings + description)
    local expandH = settingsFn and 210 or 80
    local expand=Instance.new("Frame"); expand.Size=UDim2.new(1,-4,0,expandH)
    expand.Position=UDim2.new(0,2,0,CARD_H+2); expand.BackgroundColor3=MID
    expand.BorderSizePixel=0; expand.Visible=false; expand.Parent=card
    Instance.new("UICorner",expand).CornerRadius=UDim.new(0,6)
    local expSF=Instance.new("ScrollingFrame"); expSF.Size=UDim2.new(1,0,1,0)
    expSF.BackgroundTransparency=1; expSF.BorderSizePixel=0; expSF.ScrollBarThickness=2
    expSF.ScrollBarImageColor3=ACCENT; expSF.CanvasSize=UDim2.new(0,0,0,0)
    expSF.AutomaticCanvasSize=Enum.AutomaticSize.Y; expSF.Parent=expand
    local expLO=Instance.new("UIListLayout"); expLO.Padding=UDim.new(0,4)
    expLO.HorizontalAlignment=Enum.HorizontalAlignment.Center
    expLO.SortOrder=Enum.SortOrder.LayoutOrder; expLO.Parent=expSF
    local expPD=Instance.new("UIPadding"); expPD.PaddingTop=UDim.new(0,7); expPD.PaddingBottom=UDim.new(0,7); expPD.PaddingLeft=UDim.new(0,7); expPD.PaddingRight=UDim.new(0,7); expPD.Parent=expSF

    -- Description label (always shown in expand)
    local descLbl=Instance.new("TextLabel"); descLbl.Size=UDim2.new(1,0,0,40)
    descLbl.BackgroundTransparency=1; descLbl.Text=desc
    descLbl.TextColor3=DIM; descLbl.TextSize=9; descLbl.Font=Enum.Font.Gotham
    descLbl.TextXAlignment=Enum.TextXAlignment.Left; descLbl.TextWrapped=true
    descLbl.LayoutOrder=1; descLbl.ZIndex=3; descLbl.Parent=expSF

    -- Populate settings inside expand
    if settingsFn then settingsFn(expSF) end

    local expanded=false
    local function doToggle()
        local v=not isOn()
        stateRef[stateKey]=v; toggleFn(v)
        TweenService:Create(card,TweenInfo.new(0.1),{BackgroundColor3=v and CARD_ON or CARD_OFF}):Play()
        nameLbl.TextColor3=v and WHITE or DIM; bar.Visible=v
    end
    local function doExpand()
        expanded=not expanded
        expand.Visible=expanded
        local target=expanded and CARD_H+expandH+4 or CARD_H
        TweenService:Create(card,TweenInfo.new(0.14,Enum.EasingStyle.Quad),{Size=UDim2.new(1,0,0,target)}):Play()
        gearBtn.TextColor3=expanded and WHITE or DIM
    end

    -- Left area clicks = toggle, gear = expand
    local hitArea=Instance.new("TextButton"); hitArea.Size=UDim2.new(1,-40,0,CARD_H)
    hitArea.BackgroundTransparency=1; hitArea.Text=""; hitArea.ZIndex=2; hitArea.Parent=card
    hitArea.MouseButton1Click:Connect(doToggle)
    hitArea.MouseButton2Click:Connect(doExpand)
    gearBtn.MouseButton1Click:Connect(doExpand)
end

-- ── Action Card (one-shot button, no toggle state) ─────
local function makeActionCard(parent, cardName, btnLabel, onClick, desc)
    local CARD_H=40
    local card=Instance.new("Frame"); card.Size=UDim2.new(1,0,0,CARD_H)
    card.BackgroundColor3=CARD_OFF; card.BorderSizePixel=0
    card.ClipsDescendants=true; card.LayoutOrder=O(); card.Parent=parent
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,7)
    local nameLbl=Instance.new("TextLabel"); nameLbl.Size=UDim2.new(1,-100,0,CARD_H)
    nameLbl.Position=UDim2.new(0,12,0,0); nameLbl.BackgroundTransparency=1
    nameLbl.Text=cardName; nameLbl.TextColor3=WHITE
    nameLbl.TextSize=12; nameLbl.Font=Enum.Font.GothamBold
    nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.Parent=card
    local actBtn=Instance.new("TextButton"); actBtn.Size=UDim2.new(0,82,0,26)
    actBtn.Position=UDim2.new(1,-88,0.5,-13); actBtn.BackgroundColor3=ACCENT
    actBtn.Text=btnLabel; actBtn.TextColor3=WHITE; actBtn.TextSize=10
    actBtn.Font=Enum.Font.GothamBold; actBtn.BorderSizePixel=0; actBtn.Parent=card
    Instance.new("UICorner",actBtn).CornerRadius=UDim.new(0,5)
    table.insert(accentEls,actBtn)
    local expand=Instance.new("Frame"); expand.Size=UDim2.new(1,-4,0,52)
    expand.Position=UDim2.new(0,2,0,CARD_H+2); expand.BackgroundColor3=MID
    expand.BorderSizePixel=0; expand.Visible=false; expand.Parent=card
    Instance.new("UICorner",expand).CornerRadius=UDim.new(0,6)
    local descLbl=Instance.new("TextLabel"); descLbl.Size=UDim2.new(1,-12,1,0)
    descLbl.Position=UDim2.new(0,6,0,0); descLbl.BackgroundTransparency=1; descLbl.Text=desc
    descLbl.TextColor3=DIM; descLbl.TextSize=9; descLbl.Font=Enum.Font.Gotham
    descLbl.TextXAlignment=Enum.TextXAlignment.Left; descLbl.TextWrapped=true; descLbl.Parent=expand
    local expanded=false
    local function doExpand()
        expanded=not expanded; expand.Visible=expanded
        TweenService:Create(card,TweenInfo.new(0.14,Enum.EasingStyle.Quad),
            {Size=UDim2.new(1,0,0,expanded and CARD_H+56 or CARD_H)}):Play()
    end
    actBtn.MouseButton1Click:Connect(function()
        TweenService:Create(actBtn,TweenInfo.new(0.06),{BackgroundColor3=Color3.fromRGB(50,50,170)}):Play()
        task.delay(0.18,function()
            TweenService:Create(actBtn,TweenInfo.new(0.12),{BackgroundColor3=ACCENT}):Play()
        end)
        onClick()
    end)
    card.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton2 then doExpand() end
    end)
end

-- ═══════════════════════════════════════════════════════
--  Pages
-- ═══════════════════════════════════════════════════════
local CombatPage      = makePage()
local ESPPage         = makePage()
local MovePage        = makePage()
local ExtrasPage      = makePage()
local ConfigPage      = makePage()
local BillionairePage = makePage()
local TrollPage       = makePage()
local DropPage        = makePage()
local GamesPage       = makePage()
local LemonsPage      = makePage()
local allPages={CombatPage,ESPPage,MovePage,ExtrasPage,ConfigPage,BillionairePage,TrollPage,DropPage,GamesPage,LemonsPage}

-- ── Sidebar Buttons ────────────────────────────────────
local CATS={
    {label="COMBAT",   page=CombatPage},
    {label="ESP",      page=ESPPage},
    {label="MOVEMENT", page=MovePage},
    {label="EXTRAS",   page=ExtrasPage},
    {label="CONFIG",   page=ConfigPage},
    {label="💰 RICH",  page=BillionairePage},
    {label="😈 TROLL", page=TrollPage},
    {label="🔴 DROP",  page=DropPage},
    {label="🎮 GAMES", page=GamesPage},
    {label="🍋 LEMONS", page=LemonsPage},
}
local function switchCat(idx)
    for _,p in ipairs(allPages) do p.Visible=false end
    CATS[idx].page.Visible=true
    -- move the accent bar into the selected button (scrolls + tracks correctly)
    SideIndicator.Parent=CATS[idx]._btn
    SideIndicator.Position=UDim2.new(0,0,0.5,-15)
    for i,c in ipairs(CATS) do c._btn.TextColor3=i==idx and WHITE or DIM end
end
for i,cat in ipairs(CATS) do
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,46)
    btn.BackgroundTransparency=1; btn.Text=cat.label
    btn.TextColor3=i==1 and WHITE or DIM; btn.TextSize=10; btn.Font=Enum.Font.GothamBold
    btn.BorderSizePixel=0; btn.LayoutOrder=i; btn.Parent=Sidebar
    btn.MouseButton1Click:Connect(function() switchCat(i) end)
    cat._btn=btn
end
SideIndicator.Parent=CATS[1]._btn  -- initial selection
CombatPage.Visible=true

-- ═══════════════════════════════════════════════════════
--  COMBAT modules
-- ═══════════════════════════════════════════════════════
local COLORS_PRESET={WHITE,Color3.fromRGB(255,70,70),Color3.fromRGB(70,200,255),
    Color3.fromRGB(100,255,130),Color3.fromRGB(255,220,50),Color3.fromRGB(170,70,255)}

-- Rage mode row (special full-width button)
do
    local rageRow=Instance.new("Frame"); rageRow.Size=UDim2.new(1,0,0,34)
    rageRow.BackgroundTransparency=1; rageRow.LayoutOrder=O(); rageRow.Parent=CombatPage
    local rb=Instance.new("TextButton"); rb.Size=UDim2.new(1,0,1,0)
    rb.BackgroundColor3=Color3.fromRGB(50,18,18); rb.Text="⚡  RAGE MODE"
    rb.TextColor3=Color3.fromRGB(220,80,80); rb.TextSize=12; rb.Font=Enum.Font.GothamBold
    rb.BorderSizePixel=0; rb.Parent=rageRow
    Instance.new("UICorner",rb).CornerRadius=UDim.new(0,7)
    local rst=Instance.new("UIStroke"); rst.Color=Color3.fromRGB(160,40,40); rst.Thickness=1; rst.Parent=rb
    rb.MouseButton1Click:Connect(function()
        applyRage(not RAGE.Active)
        rb.BackgroundColor3=RAGE.Active and Color3.fromRGB(160,35,35) or Color3.fromRGB(50,18,18)
        rb.TextColor3=RAGE.Active and WHITE or Color3.fromRGB(220,80,80)
    end)
end

makeModCard(CombatPage,"Aimbot",AB,"Enabled",function(v) AB.Enabled=v; updateFOV() end,
    "Locks onto the nearest enemy within your FOV. Smoothness: 0=instant snap, 0.98=very slow follow. Pair with Prediction for moving targets.",
    function(sf)
        makeSlider(sf,"FOV",50,600,AB.FOV,5,"%.0f px",function(v)
            AB.FOV=v; updateFOV()
            TargetLabel.Position=UDim2.new(0.5,0,0.5,-v-8)
            HitLabel.Position=UDim2.new(0.5,0,0.5,v+10)
        end)
        makeSlider(sf,"Smoothness",0,0.98,AB.Smoothness,0.01,"%.2f",function(v) AB.Smoothness=v end)
        makeSlider(sf,"Prediction",0,8,AB.Prediction,1,"%.0f fr",function(v) AB.Prediction=v end)
        makeToggle(sf,"Auto Prediction",AB.AutoPrediction,function(v) AB.AutoPrediction=v end)
        makeToggle(sf,"Hold to Aim (RMB)",AB.HoldToAim,function(v) AB.HoldToAim=v end)
        makeToggle(sf,"Visibility Check",AB.VisCheck,function(v) AB.VisCheck=v end)
        makeToggle(sf,"Team Check",AB.TeamCheck,function(v) AB.TeamCheck=v end)
        makeToggle(sf,"Cursor Lock",AB.CursorLock,function(v) AB.CursorLock=v end)
        makeToggle(sf,"Show FOV Circle",AB.ShowFOVCircle,function(v) AB.ShowFOVCircle=v; updateFOV() end)
        makeToggle(sf,"Show Hit %",AB.ShowHitChance,function(v) AB.ShowHitChance=v end)
        makeSlider(sf,"Circle Thickness",1,6,AB.CircleThickness,1,"%.0f",function(v) AB.CircleThickness=v; updateFOV() end)
        makeColorRow(sf,"Circle Color",COLORS_PRESET,function(c) AB.CircleColor=c; updateFOV() end)
    end)

makeModCard(CombatPage,"Silent Aim",SA,"Enabled",function(v) SA.Enabled=v end,
    "Overrides Mouse.Hit and Mouse.Target so your weapon detects the enemy even if your crosshair is off them. Works with most games that read mouse position.")

makeModCard(CombatPage,"Auto Shoot",MISC,"AutoShoot",function(v) MISC.AutoShoot=v end,
    "Automatically clicks when the aimbot has a locked target. Requires Aimbot to be enabled. Pair with a low fire rate for burst control.",
    function(sf)
        makeSlider(sf,"Fire Rate",1,20,math.round(1/MISC.AutoShootRate),1,"%.0f /s",function(v) MISC.AutoShootRate=1/v end)
    end)

makeModCard(CombatPage,"Trigger Bot",MISC,"TriggerBot",function(v) MISC.TriggerBot=v end,
    "Fires automatically when your cursor passes over an enemy hitbox. Works independently of the aimbot — useful for flick-and-release playstyles.",
    function(sf)
        makeSlider(sf,"Trigger Radius",5,120,MISC.TriggerFOV,5,"%.0f px",function(v) MISC.TriggerFOV=v end)
        makeSlider(sf,"Fire Rate",1,20,math.round(1/MISC.AutoShootRate),1,"%.0f /s",function(v) MISC.AutoShootRate=1/v end)
    end)

-- ═══════════════════════════════════════════════════════
--  ESP modules
-- ═══════════════════════════════════════════════════════
local ESP_FILL={Color3.fromRGB(255,50,50),Color3.fromRGB(255,140,30),Color3.fromRGB(60,200,100),
    Color3.fromRGB(60,140,255),Color3.fromRGB(220,80,255),WHITE}
local ESP_OUT ={WHITE,Color3.fromRGB(255,70,70),Color3.fromRGB(70,200,255),
    Color3.fromRGB(255,220,50),Color3.fromRGB(170,70,255),Color3.fromRGB(10,10,10)}

makeModCard(ESPPage,"Highlights",ESP,"Enabled",function(v)
    ESP.Enabled=v
    if not v then local tbl={}; for p in pairs(ESPObjects) do table.insert(tbl,p) end
    for _,p in ipairs(tbl) do RemoveESP(p) end end
end,
"Draws colored highlight overlays on all enemies using Roblox's built-in Highlight system, always visible through walls.",
function(sf)
    makeSlider(sf,"Fill Transparency",0,1,ESP.FillTransparency,0.05,"%.2f",function(v)
        ESP.FillTransparency=v; for _,o in pairs(ESPObjects) do if o.Highlight then o.Highlight.FillTransparency=v end end
    end)
    makeSlider(sf,"Outline Transparency",0,1,ESP.OutlineTransparency,0.05,"%.2f",function(v)
        ESP.OutlineTransparency=v; for _,o in pairs(ESPObjects) do if o.Highlight then o.Highlight.OutlineTransparency=v end end
    end)
    makeSlider(sf,"Max Distance",50,2000,ESP.MaxDistance,25,"%.0f st",function(v) ESP.MaxDistance=v end)
    makeToggle(sf,"Team Check",ESP.TeamCheck,function(v) ESP.TeamCheck=v end)
    makeColorRow(sf,"Fill Color",ESP_FILL,function(c)
        ESP.FillColor=c; for _,o in pairs(ESPObjects) do if o.Highlight then o.Highlight.FillColor=c end end
    end)
    makeColorRow(sf,"Outline Color",ESP_OUT,function(c)
        ESP.OutlineColor=c; for _,o in pairs(ESPObjects) do if o.Highlight then o.Highlight.OutlineColor=c end end
    end)
end)

makeModCard(ESPPage,"Name Tags",ESP,"ShowNames",function(v) ESP.ShowNames=v
    for _,o in pairs(ESPObjects) do if o.Billboard then o.Billboard.Enabled=v end end
end,"Shows each enemy's display name and distance above their head in a floating tag.")

makeModCard(ESPPage,"Health Bar",ESP,"ShowHealthBar",function(v) ESP.ShowHealthBar=v end,
    "Displays a color-coded HP bar (green→red) beneath the name tag, updating in real time.")

makeModCard(ESPPage,"Tracelines",ESP,"ShowTracelines",function(v) ESP.ShowTracelines=v end,
    "Draws 2D lines from the bottom-center of your screen to each visible enemy.",
    function(sf)
        makeColorRow(sf,"Line Color",COLORS_PRESET,function(c) ESP.TraceColor=c end)
    end)

makeModCard(ESPPage,"Skeleton",ESP,"ShowSkeleton",function(v) ESP.ShowSkeleton=v end,
    "Renders bone-to-bone connection lines on each enemy. Supports both R15 (14 bones) and R6 (5 bones).",
    function(sf)
        makeColorRow(sf,"Bone Color",COLORS_PRESET,function(c) ESP.SkeletonColor=c end)
    end)

makeModCard(ESPPage,"2D Boxes",ESP,"ShowBoxes",function(v) ESP.ShowBoxes=v end,
    "Draws a 2D bounding box around each enemy's screen-space height from head to feet.",
    function(sf)
        makeColorRow(sf,"Box Color",COLORS_PRESET,function(c) ESP.BoxColor=c end)
    end)

makeModCard(ESPPage,"Snapline to Target",ESP,"ShowSnapline",function(v) ESP.ShowSnapline=v end,
    "Draws a single highlighted line to only your current aimbot lock target.")

-- ═══════════════════════════════════════════════════════
--  MOVEMENT modules
-- ═══════════════════════════════════════════════════════
makeModCard(MovePage,"Speed Hack",MISC,"SpeedEnabled",function(v) MISC.SpeedEnabled=v; applyMovement() end,
    "Sets your character's WalkSpeed to a custom value. Disable to restore default speed.",
    function(sf)
        makeSlider(sf,"Speed",16,300,MISC.Speed,1,"%.0f",function(v) MISC.Speed=v; if MISC.SpeedEnabled then applyMovement() end end)
    end)

makeModCard(MovePage,"Jump Hack",MISC,"JumpEnabled",function(v) MISC.JumpEnabled=v; applyMovement() end,
    "Sets your character's JumpPower to a custom value.",
    function(sf)
        makeSlider(sf,"Jump Power",50,400,MISC.JumpPower,5,"%.0f",function(v) MISC.JumpPower=v; if MISC.JumpEnabled then applyMovement() end end)
    end)

makeModCard(MovePage,"Infinite Jump",MISC,"InfiniteJump",function(v) MISC.InfiniteJump=v end,
    "Lets you jump again in mid-air by re-triggering the Jump state on each jump request.")

makeModCard(MovePage,"NoClip",MISC,"NoClip",function(v) MISC.NoClip=v end,
    "Disables collision on all character parts so you can walk through walls and terrain.")

makeModCard(MovePage,"Fly",MISC,"Fly",function(v) MISC.Fly=v; if not v then disableFly() end end,
    "Frees you from gravity. Use WASD to fly horizontally, Space to go up, Left Ctrl to go down.",
    function(sf)
        makeSlider(sf,"Fly Speed",10,300,MISC.FlySpeed,5,"%.0f",function(v) MISC.FlySpeed=v end)
    end)

makeModCard(MovePage,"Anti-AFK",MISC,"AntiAFK",function(v) MISC.AntiAFK=v end,
    "Sends a virtual click whenever Roblox's idle timer fires, preventing auto-kick.")

makeModCard(MovePage,"Click Teleport",MISC,"ClickTeleport",function(v) setClickTp(v) end,
    "Right-click anywhere in the world to instantly teleport your character to that position.")

-- ═══════════════════════════════════════════════════════
--  EXTRAS modules
-- ═══════════════════════════════════════════════════════
local CROSS_STYLES={"dot","cross","circle"}
local csIdx=1

makeModCard(ExtrasPage,"Crosshair",CROSS,"Enabled",function(v) CROSS.Enabled=v; buildCrosshair() end,
    "Draws a custom crosshair at the center of your screen. Choose from dot, cross, or circle styles.",
    function(sf)
        -- Style picker
        local sRow=Instance.new("Frame"); sRow.Size=UDim2.new(1,0,0,26)
        sRow.BackgroundTransparency=1; sRow.LayoutOrder=O(); sRow.Parent=sf
        local sLbl=Instance.new("TextLabel"); sLbl.Size=UDim2.new(0.5,0,1,0)
        sLbl.BackgroundTransparency=1; sLbl.Text="Style"; sLbl.TextColor3=Color3.fromRGB(160,160,195)
        sLbl.TextSize=10; sLbl.Font=Enum.Font.Gotham; sLbl.TextXAlignment=Enum.TextXAlignment.Left; sLbl.Parent=sRow
        local sVal=Instance.new("TextLabel"); sVal.Size=UDim2.new(0.5,0,1,0)
        sVal.Position=UDim2.new(0.5,0,0,0); sVal.BackgroundTransparency=1
        sVal.Text=CROSS_STYLES[csIdx]; sVal.TextColor3=ACCENT; sVal.TextSize=10; sVal.Font=Enum.Font.GothamBold
        sVal.TextXAlignment=Enum.TextXAlignment.Right; sVal.Parent=sRow
        sVal.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                csIdx=csIdx%#CROSS_STYLES+1; CROSS.Style=CROSS_STYLES[csIdx]; sVal.Text=CROSS_STYLES[csIdx]
                if CROSS.Enabled then buildCrosshair() end
            end
        end)
        makeSlider(sf,"Size",2,24,CROSS.Size,1,"%.0f",function(v) CROSS.Size=v; if CROSS.Enabled then buildCrosshair() end end)
        makeSlider(sf,"Gap",0,14,CROSS.Gap,1,"%.0f",function(v) CROSS.Gap=v; if CROSS.Enabled then buildCrosshair() end end)
        makeSlider(sf,"Thickness",1,5,CROSS.Thickness,1,"%.0f",function(v) CROSS.Thickness=v; if CROSS.Enabled then buildCrosshair() end end)
        makeColorRow(sf,"Color",COLORS_PRESET,function(c) CROSS.Color=c; if CROSS.Enabled then buildCrosshair() end end)
    end)

makeModCard(ExtrasPage,"Radar",RADAR,"Enabled",function(v) RADAR.Enabled=v; RadarFrame.Visible=v end,
    "Shows a 2D minimap in the corner rotating with your camera. Enemies appear as red dots; your current target is gold.",
    function(sf)
        makeSlider(sf,"Range",50,600,RADAR.Range,10,"%.0f st",function(v) RADAR.Range=v end)
    end)

makeModCard(ExtrasPage,"Fullbright",MISC,"Fullbright",function(v)
        MISC.Fullbright=v
        if not v then  -- restore the game's lighting immediately on disable
            Lighting.Brightness=origLight.B; Lighting.Ambient=origLight.A; Lighting.FogEnd=origLight.FE
        end
    end,
    "Overrides the game's lighting to maximum brightness, removing fog and darkness.")

makeModCard(ExtrasPage,"Camera FOV",MISC,"CamFOV",function(v) MISC.CamFOV=v; if not v then Camera.FieldOfView=70 end end,
    "Changes your camera's field of view. Higher values show more of the scene but may feel fisheye.",
    function(sf)
        makeSlider(sf,"FOV Value",50,120,MISC.CamFOVVal,1,"%.0f°",function(v) MISC.CamFOVVal=v; if MISC.CamFOV then Camera.FieldOfView=v end end)
    end)

makeModCard(ExtrasPage,"Hitbox Expander",MISC,"HitboxExpand",function(v) MISC.HitboxExpand=v end,
    "Inflates the HumanoidRootPart of enemies client-side, making them easier to hit with client-side raycasting games.",
    function(sf)
        makeSlider(sf,"Hitbox Size",4,30,MISC.HitboxSize,0.5,"%.1f st",function(v) MISC.HitboxSize=v end)
    end)

makeModCard(ExtrasPage,"God Mode",MISC,"GodMode",function(v) MISC.GodMode=v end,
    "Restores your character's health to max every frame, making you unkillable client-side.")

makeModCard(ExtrasPage,"Anti-Ragdoll",MISC,"AntiRagdoll",function(v) MISC.AntiRagdoll=v end,
    "Prevents your character from entering ragdoll or FallingDown states, keeping you upright after knockbacks.")

makeModCard(ExtrasPage,"Spectator Alert",MISC,"SpectatorAlert",function(v) MISC.SpectatorAlert=v end,
    "Detects players who are spectating (no character for 10+ seconds) and shows a persistent banner with their names.")

makeModCard(ExtrasPage,"Stats Overlay",{v=false},"v",function(v) statsEnabled=v; StatsFrame.Visible=v end,
    "Shows a small draggable HUD at the top of your screen displaying the current on/off state of each major feature.")

-- ═══════════════════════════════════════════════════════
--  CONFIG page (traditional controls)
-- ═══════════════════════════════════════════════════════
makeDivider(ConfigPage,"PROFILES")
do
    for _,slot in ipairs({"default","slot2","slot3"}) do
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,28)
        row.BackgroundTransparency=1; row.LayoutOrder=O(); row.Parent=ConfigPage
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.45,0,1,0)
        lbl.BackgroundTransparency=1; lbl.Text=slot; lbl.TextColor3=Color3.fromRGB(160,160,195)
        lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
        local sBtn=Instance.new("TextButton"); sBtn.Size=UDim2.new(0.26,0,0,22)
        sBtn.Position=UDim2.new(0.49,0,0.5,-11); sBtn.BackgroundColor3=MID
        sBtn.Text="SAVE"; sBtn.TextColor3=WHITE; sBtn.TextSize=9; sBtn.Font=Enum.Font.GothamBold
        sBtn.BorderSizePixel=0; sBtn.Parent=row; Instance.new("UICorner",sBtn).CornerRadius=UDim.new(0,4)
        local lBtn=Instance.new("TextButton"); lBtn.Size=UDim2.new(0.26,0,0,22)
        lBtn.Position=UDim2.new(0.77,0,0.5,-11); lBtn.BackgroundColor3=MID
        lBtn.Text="LOAD"; lBtn.TextColor3=WHITE; lBtn.TextSize=9; lBtn.Font=Enum.Font.GothamBold
        lBtn.BorderSizePixel=0; lBtn.Parent=row; Instance.new("UICorner",lBtn).CornerRadius=UDim.new(0,4)
        sBtn.MouseButton1Click:Connect(function() saveProfile(slot) end)
        lBtn.MouseButton1Click:Connect(function() loadProfile(slot) end)
    end
end

makeDivider(ConfigPage,"THEME")
do
    local THEMES={
        Color3.fromRGB(90,100,220),Color3.fromRGB(220,70,70),Color3.fromRGB(60,200,200),
        Color3.fromRGB(80,220,100),Color3.fromRGB(220,170,40),Color3.fromRGB(220,80,200),
        WHITE,Color3.fromRGB(200,120,50),
    }
    makeColorRow(ConfigPage,"Accent",THEMES,function(c)
        ACCENT=c
        for _,e in ipairs(accentEls) do
            if e:IsA("UIStroke") then e.Color=c
            elseif e:IsA("Frame") then e.BackgroundColor3=c end
        end
        if SubLine then SubLine.BackgroundColor3=c end
        SideIndicator.BackgroundColor3=c
    end)
end

makeDivider(ConfigPage,"KEYBINDS")
do
    local BIND_DEFS={
        {key="panel",  label="Toggle Panel"},
        {key="aimbot", label="Toggle Aimbot"},
        {key="panic",  label="Panic / Destroy"},
        {key="rage",   label="Rage Mode"},
        {key="cycle",  label="Cycle Target"},
    }
    for _,def in ipairs(BIND_DEFS) do
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,26)
        row.BackgroundTransparency=1; row.LayoutOrder=O(); row.Parent=ConfigPage
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.55,0,1,0)
        lbl.BackgroundTransparency=1; lbl.Text=def.label; lbl.TextColor3=Color3.fromRGB(160,160,195)
        lbl.TextSize=10; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
        local kBtn=Instance.new("TextButton"); kBtn.Size=UDim2.new(0.45,-4,0,20)
        kBtn.Position=UDim2.new(0.55,4,0.5,-10); kBtn.BackgroundColor3=MID
        kBtn.Text=tostring(KEYBINDS[def.key]):gsub("Enum.KeyCode.","")
        kBtn.TextColor3=ACCENT; kBtn.TextSize=9; kBtn.Font=Enum.Font.GothamBold
        kBtn.BorderSizePixel=0; kBtn.Parent=row; Instance.new("UICorner",kBtn).CornerRadius=UDim.new(0,4)
        local captKey=def.key
        kBtn.MouseButton1Click:Connect(function()
            kBtn.Text="[press key]"; kBtn.TextColor3=WHITE
            bindCapture=function(kc)
                KEYBINDS[captKey]=kc
                kBtn.Text=tostring(kc):gsub("Enum.KeyCode.","")
                kBtn.TextColor3=ACCENT; notify("Rebound: "..def.label)
            end
        end)
    end
end

makeDivider(ConfigPage,"MISC")
makeToggle(ConfigPage,"Anti-AFK",MISC.AntiAFK,function(v) MISC.AntiAFK=v end)
do
    -- Auto Rejoin: when a disconnect/kick error pops up, teleport back in.
    -- Tries the SAME server first, falls back to a new server if it's gone.
    local TPS=game:GetService("TeleportService")
    local GuiSvc=game:GetService("GuiService")
    local placeId=game.PlaceId
    local jobId=game.JobId
    local rejoinConn=nil
    local rejoining=false
    local function doRejoin()
        if rejoining then return end
        rejoining=true
        task.wait(1)
        local ok=pcall(function() TPS:TeleportToPlaceInstance(placeId,jobId,LP) end)
        if not ok then pcall(function() TPS:Teleport(placeId,LP) end) end
    end
    makeToggle(ConfigPage,"Auto Rejoin",MISC.AutoRejoin,function(v)
        MISC.AutoRejoin=v
        if rejoinConn then rejoinConn:Disconnect(); rejoinConn=nil end
        if v then
            rejoinConn=GuiSvc.ErrorMessageChanged:Connect(function()
                if MISC.AutoRejoin then doRejoin() end
            end)
            if notify then notify("Auto Rejoin armed") end
        end
    end)
    table.insert(cleanupHooks, function()
        MISC.AutoRejoin=false
        if rejoinConn then rejoinConn:Disconnect(); rejoinConn=nil end
    end)
end
makeSlider(ConfigPage,"Panel Opacity",5,100,MISC.PanelOpacity,5,"%.0f%%",function(v)
    MISC.PanelOpacity=v; applyPanelOpacity(v)
end)
do
    local infoLbl=Instance.new("TextLabel"); infoLbl.Size=UDim2.new(1,0,0,28)
    infoLbl.BackgroundTransparency=1; infoLbl.Text="skullzz hub  v4  |  right-click cards for settings"
    infoLbl.TextColor3=Color3.fromRGB(36,36,60); infoLbl.TextSize=9; infoLbl.Font=Enum.Font.Gotham
    infoLbl.TextXAlignment=Enum.TextXAlignment.Center; infoLbl.LayoutOrder=O(); infoLbl.Parent=ConfigPage
end

-- ── Auto-load default profile ──────────────────────────
task.defer(function() loadProfile("default") end)

-- ═══════════════════════════════════════════════════════
--  BILLIONAIRE page
-- ═══════════════════════════════════════════════════════
do
    -- ── feature logic (scoped inside this block to save _hub locals) ──
    local REBIRTH = {AutoEnabled=false, Delay=1}
    local NPC = {AutoEnabled=false}
    local rebirthCount, rebirthTask = 0, nil
    local autoBuyTask, npcBuyCount = nil, 0
    local rebirthCountLbl, npcBuyCountLbl
    local rebirthEvent
    pcall(function()
        rebirthEvent=game:GetService("ReplicatedStorage").Modules.Systems.Rebirth.Services.RebirthNetwork._doRebirth
    end)
    local function doRebirth()
        local success=false
        pcall(function()
            if not rebirthEvent then
                rebirthEvent=game:GetService("ReplicatedStorage").Modules.Systems.Rebirth.Services.RebirthNetwork._doRebirth
            end
            local result=rebirthEvent:InvokeServer(31)
            if result then
                success=true
                rebirthCount=rebirthCount+1
                if rebirthCountLbl then rebirthCountLbl.Text="Total Rebirths: "..rebirthCount end
                if notify then notify("Rebirth #"..rebirthCount.." done!") end
            else
                if notify then notify("Rebirth: requirements not met") end
            end
        end)
        return success
    end
    local function setAutoRebirth(v)
        REBIRTH.AutoEnabled=v
        if rebirthTask then task.cancel(rebirthTask); rebirthTask=nil end
        if v then
            rebirthTask=task.spawn(function()
                while REBIRTH.AutoEnabled do
                    local ok=doRebirth()
                    task.wait(ok and 0.5 or math.max(REBIRTH.Delay,0.5))
                end
            end)
        end
    end

    local NPC_LIST = {
        {name="Business Bacon", cost=75},
        {name="Influencer",     cost=450},
        {name="Tix Man",        cost=3500},
        {name="Tix Investor",   cost=25000},
        {name="Hacker",         cost=150000},
        {name="Millionaire",    cost=2500000},
        {name="Crypto Bro",     cost=17500000},
        {name="DJ",             cost=250000000},
        {name="Mr. Frost",      cost=3500000000},
        {name="Mr. Pyro",       cost=50000000000},
        {name="Rapper",         cost=500000000000},
        {name="Royal King",     cost=5000000000000},
        {name="Dark King",      cost=25000000000000},
        {name="Artist",         cost=150000000000000},
        {name="Billionaire",    cost=400000000000000},
        {name="President",      cost=2e15},
        {name="Ninja",          cost=4e17},
        {name="Grandma",        cost=1.75e18},
    }
    local selectedNPC = NPC_LIST[1]
    local selectedNPCIdx = 1
    local npcBuyEvent
    pcall(function()
        npcBuyEvent=game:GetService("ReplicatedStorage").Modules.Systems.Shop.Services.ShopNetwork._buyNPC
    end)
    local function getCash()
        local cash=0
        pcall(function()
            local ls=LP:FindFirstChild("leaderstats")
            if not ls then return end
            for _,v in ipairs(ls:GetChildren()) do
                if (v:IsA("NumberValue") or v:IsA("IntValue")) then
                    cash=v.Value; return
                end
            end
        end)
        return cash
    end
    local function doNPCBuy()
        local bought=false
        pcall(function()
            if not npcBuyEvent then
                npcBuyEvent=game:GetService("ReplicatedStorage").Modules.Systems.Shop.Services.ShopNetwork._buyNPC
            end
            local cash=getCash()
            if cash>0 and cash < selectedNPC.cost then
                if notify then notify("Not enough cash for "..selectedNPC.name) end
                return
            end
            local result=npcBuyEvent:InvokeServer(selectedNPC.name, 1)
            if result then
                bought=true
                npcBuyCount=npcBuyCount+1
                if npcBuyCountLbl then npcBuyCountLbl.Text="Bought: "..npcBuyCount end
                if notify then notify("Bought "..selectedNPC.name.."!") end
            else
                if notify then notify(selectedNPC.name..": not enough cash or already maxed") end
            end
        end)
        return bought
    end
    local function setAutoBuyNPC(v)
        NPC.AutoEnabled=v
        if autoBuyTask then task.cancel(autoBuyTask); autoBuyTask=nil end
        if v then
            autoBuyTask=task.spawn(function()
                while NPC.AutoEnabled do
                    local cash=getCash()
                    if cash>0 and cash >= selectedNPC.cost then
                        doNPCBuy(); task.wait(1)
                    else
                        task.wait(2)
                    end
                end
            end)
        end
    end
    table.insert(cleanupHooks, function()
        REBIRTH.AutoEnabled=false; if rebirthTask then task.cancel(rebirthTask); rebirthTask=nil end
        NPC.AutoEnabled=false; if autoBuyTask then task.cancel(autoBuyTask); autoBuyTask=nil end
    end)

    local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,38)
    hdr.BackgroundTransparency=1; hdr.Text="💰  BECOME A BILLIONAIRE"
    hdr.TextColor3=Color3.fromRGB(255,220,50); hdr.TextSize=15; hdr.Font=Enum.Font.GothamBold
    hdr.TextXAlignment=Enum.TextXAlignment.Center; hdr.LayoutOrder=O(); hdr.Parent=BillionairePage

    rebirthCountLbl=Instance.new("TextLabel"); rebirthCountLbl.Size=UDim2.new(1,0,0,22)
    rebirthCountLbl.BackgroundTransparency=1; rebirthCountLbl.Text="Total Rebirths: 0"
    rebirthCountLbl.TextColor3=Color3.fromRGB(180,160,255); rebirthCountLbl.TextSize=11
    rebirthCountLbl.Font=Enum.Font.GothamBold
    rebirthCountLbl.TextXAlignment=Enum.TextXAlignment.Center
    rebirthCountLbl.LayoutOrder=O(); rebirthCountLbl.Parent=BillionairePage

    makeDivider(BillionairePage,"REBIRTH")

    makeActionCard(BillionairePage,"Remote Rebirth","REBIRTH NOW",doRebirth,
        "Calls the server rebirth event once immediately. Checks if requirements are met; shows notification if not.")

    makeModCard(BillionairePage,"Auto Rebirth",REBIRTH,"AutoEnabled",
        function(v) setAutoRebirth(v) end,
        "Waits for rebirth requirements to be met before firing. Chains immediately on success; waits full delay on failure.",
        function(sf)
            makeSlider(sf,"Delay (on fail)",0.5,30,REBIRTH.Delay,0.5,"%.1f s",function(v) REBIRTH.Delay=v end)
        end)

    makeDivider(BillionairePage,"BUY NPC")

    -- NPC selector (arrow picker — avoids scroll-frame clipping)
    do
        local pickerCard=Instance.new("Frame"); pickerCard.Size=UDim2.new(1,0,0,38)
        pickerCard.BackgroundColor3=CARD_OFF; pickerCard.BorderSizePixel=0
        pickerCard.LayoutOrder=O(); pickerCard.Parent=BillionairePage
        Instance.new("UICorner",pickerCard).CornerRadius=UDim.new(0,7)

        local leftBtn=Instance.new("TextButton"); leftBtn.Size=UDim2.new(0,32,1,0)
        leftBtn.BackgroundTransparency=1; leftBtn.Text="◀"; leftBtn.TextColor3=ACCENT
        leftBtn.TextSize=14; leftBtn.Font=Enum.Font.GothamBold; leftBtn.Parent=pickerCard

        local nameLbl=Instance.new("TextLabel"); nameLbl.Size=UDim2.new(1,-64,0,20)
        nameLbl.Position=UDim2.new(0,32,0,4); nameLbl.BackgroundTransparency=1
        nameLbl.Text=NPC_LIST[1].name; nameLbl.TextColor3=WHITE
        nameLbl.TextSize=11; nameLbl.Font=Enum.Font.GothamBold
        nameLbl.TextXAlignment=Enum.TextXAlignment.Center; nameLbl.Parent=pickerCard

        local idxLbl=Instance.new("TextLabel"); idxLbl.Size=UDim2.new(1,-64,0,12)
        idxLbl.Position=UDim2.new(0,32,0,23); idxLbl.BackgroundTransparency=1
        idxLbl.Text="1 / "..#NPC_LIST; idxLbl.TextColor3=DIM
        idxLbl.TextSize=9; idxLbl.Font=Enum.Font.Gotham
        idxLbl.TextXAlignment=Enum.TextXAlignment.Center; idxLbl.Parent=pickerCard

        local rightBtn=Instance.new("TextButton"); rightBtn.Size=UDim2.new(0,32,1,0)
        rightBtn.Position=UDim2.new(1,-32,0,0); rightBtn.BackgroundTransparency=1
        rightBtn.Text="▶"; rightBtn.TextColor3=ACCENT
        rightBtn.TextSize=14; rightBtn.Font=Enum.Font.GothamBold; rightBtn.Parent=pickerCard

        local function updatePicker()
            selectedNPC=NPC_LIST[selectedNPCIdx]
            nameLbl.Text=selectedNPC.name
            idxLbl.Text=selectedNPCIdx.." / "..#NPC_LIST
        end
        leftBtn.MouseButton1Click:Connect(function()
            selectedNPCIdx=(selectedNPCIdx-2)%#NPC_LIST+1; updatePicker()
        end)
        rightBtn.MouseButton1Click:Connect(function()
            selectedNPCIdx=selectedNPCIdx%#NPC_LIST+1; updatePicker()
        end)
    end

    npcBuyCountLbl=Instance.new("TextLabel"); npcBuyCountLbl.Size=UDim2.new(1,0,0,18)
    npcBuyCountLbl.BackgroundTransparency=1; npcBuyCountLbl.Text="Bought: 0"
    npcBuyCountLbl.TextColor3=Color3.fromRGB(180,160,255); npcBuyCountLbl.TextSize=10
    npcBuyCountLbl.Font=Enum.Font.GothamBold
    npcBuyCountLbl.TextXAlignment=Enum.TextXAlignment.Center
    npcBuyCountLbl.LayoutOrder=O(); npcBuyCountLbl.Parent=BillionairePage

    makeActionCard(BillionairePage,"Buy NPC Now","BUY NOW",doNPCBuy,
        "Buys one of the selected NPC immediately. Checks your cash first and skips the call if you can't afford it.")

    makeModCard(BillionairePage,"Auto Buy NPC",NPC,"AutoEnabled",
        function(v) setAutoBuyNPC(v) end,
        "Monitors your cash every 2 seconds and buys the selected NPC as soon as you can afford it. Stops on disable or Panic.")
end -- BILLIONAIRE do..end

-- ═══════════════════════════════════════════════════════
--  TROLL page
-- ═══════════════════════════════════════════════════════
do
    -- ── feature logic (scoped inside this block to save _hub locals) ──
    local TROLL = {Spin=false, SpinPower=20000, FlingDuration=1.2, AnnoyEnabled=false}
    local spinConn, annoyTask, selectedVictim, victimNameLbl
    local function getMyParts()
        local char=LP.Character
        if not char then return nil end
        local hrp=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        local hum=char:FindFirstChildOfClass("Humanoid")
        return char,hrp,hum
    end
    local function getVictimHRP()
        if not selectedVictim then return nil end
        local vchar=selectedVictim.Character
        if not vchar then return nil end
        return vchar:FindFirstChild("HumanoidRootPart") or vchar:FindFirstChild("Torso") or vchar:FindFirstChild("UpperTorso")
    end
    local function setVel(part, ang, lin)
        pcall(function() part.AssemblyAngularVelocity=ang end)
        pcall(function() part.AssemblyLinearVelocity=lin end)
        pcall(function() part.RotVelocity=ang end)
        pcall(function() part.Velocity=lin end)
    end
    local function setSpin(on)
        TROLL.Spin=on
        if spinConn then spinConn:Disconnect(); spinConn=nil end
        if on then
            local _,_,hum=getMyParts()
            if hum then pcall(function() hum.PlatformStand=true end) end
            spinConn=RunService.Heartbeat:Connect(function()
                local _,hrp,_=getMyParts()
                if not hrp then return end
                local p=TROLL.SpinPower
                setVel(hrp, Vector3.new(p,p,p), Vector3.new(0,0,0))
            end)
            if notify then notify("Spinbot ON — touch people to fling") end
        else
            local _,_,hum=getMyParts()
            if hum then pcall(function() hum.PlatformStand=false end) end
            if notify then notify("Spinbot OFF") end
        end
    end
    local function flingVictim()
        local vhrp=getVictimHRP()
        if not vhrp then if notify then notify("No victim / they have no character") end return end
        local _,hrp,hum=getMyParts()
        if not hrp then return end
        if notify then notify("Flinging "..selectedVictim.Name.."!") end
        local returnCF=hrp.CFrame
        if hum then pcall(function() hum.PlatformStand=true end) end
        local t=0; local conn
        local function finish()
            if conn then conn:Disconnect(); conn=nil end
            if hum then pcall(function() hum.PlatformStand=false end) end
            pcall(function()
                setVel(hrp, Vector3.new(0,0,0), Vector3.new(0,0,0))
                hrp.CFrame=returnCF
            end)
            task.delay(0.05, function()
                pcall(function()
                    setVel(hrp, Vector3.new(0,0,0), Vector3.new(0,0,0))
                    hrp.CFrame=returnCF
                end)
            end)
        end
        conn=RunService.Heartbeat:Connect(function(dt)
            t=t+dt
            local v=getVictimHRP()
            if not v or t>TROLL.FlingDuration then
                finish(); return
            end
            pcall(function() hrp.CFrame=v.CFrame end)
            local p=TROLL.SpinPower
            setVel(hrp, Vector3.new(p,p,p), Vector3.new(0,50,0))
        end)
    end
    local function flingAll()
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=LP and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                local saved=selectedVictim; selectedVictim=pl
                flingVictim()
                task.wait(TROLL.FlingDuration+0.15)
                selectedVictim=saved
            end
        end
    end
    local function tpToVictim()
        local vhrp=getVictimHRP()
        if not vhrp then if notify then notify("No victim selected") end return end
        local _,hrp,_=getMyParts()
        if not hrp then return end
        pcall(function() hrp.CFrame=vhrp.CFrame*CFrame.new(0,0,3) end)
    end
    local function setAnnoy(on)
        TROLL.AnnoyEnabled=on
        if annoyTask then task.cancel(annoyTask); annoyTask=nil end
        if on then
            annoyTask=task.spawn(function()
                while TROLL.AnnoyEnabled do
                    local vhrp=getVictimHRP()
                    local _,hrp,_=getMyParts()
                    if vhrp and hrp then
                        pcall(function() hrp.CFrame=vhrp.CFrame*CFrame.new(0,0,2) end)
                    end
                    task.wait(0.1)
                end
            end)
            if notify then notify("Stalk Mode ON") end
        else
            if notify then notify("Stalk Mode OFF") end
        end
    end
    table.insert(cleanupHooks, function()
        TROLL.Spin=false; if spinConn then spinConn:Disconnect(); spinConn=nil end
        TROLL.AnnoyEnabled=false; if annoyTask then task.cancel(annoyTask); annoyTask=nil end
        pcall(function()
            local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand=false end
        end)
    end)

    local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,38)
    hdr.BackgroundTransparency=1; hdr.Text="😈  MESS WITH FRIENDS"
    hdr.TextColor3=Color3.fromRGB(255,120,200); hdr.TextSize=15; hdr.Font=Enum.Font.GothamBold
    hdr.TextXAlignment=Enum.TextXAlignment.Center; hdr.LayoutOrder=O(); hdr.Parent=TrollPage

    makeDivider(TrollPage,"TARGET")

    -- Victim picker (◀ ▶ cycles through real players)
    do
        local pickerCard=Instance.new("Frame"); pickerCard.Size=UDim2.new(1,0,0,38)
        pickerCard.BackgroundColor3=CARD_OFF; pickerCard.BorderSizePixel=0
        pickerCard.LayoutOrder=O(); pickerCard.Parent=TrollPage
        Instance.new("UICorner",pickerCard).CornerRadius=UDim.new(0,7)

        local leftBtn=Instance.new("TextButton"); leftBtn.Size=UDim2.new(0,32,1,0)
        leftBtn.BackgroundTransparency=1; leftBtn.Text="◀"; leftBtn.TextColor3=ACCENT
        leftBtn.TextSize=14; leftBtn.Font=Enum.Font.GothamBold; leftBtn.Parent=pickerCard

        victimNameLbl=Instance.new("TextLabel"); victimNameLbl.Size=UDim2.new(1,-64,1,0)
        victimNameLbl.Position=UDim2.new(0,32,0,0); victimNameLbl.BackgroundTransparency=1
        victimNameLbl.Text="(no players)"; victimNameLbl.TextColor3=WHITE
        victimNameLbl.TextSize=11; victimNameLbl.Font=Enum.Font.GothamBold
        victimNameLbl.TextXAlignment=Enum.TextXAlignment.Center; victimNameLbl.Parent=pickerCard

        local rightBtn=Instance.new("TextButton"); rightBtn.Size=UDim2.new(0,32,1,0)
        rightBtn.Position=UDim2.new(1,-32,0,0); rightBtn.BackgroundTransparency=1
        rightBtn.Text="▶"; rightBtn.TextColor3=ACCENT
        rightBtn.TextSize=14; rightBtn.Font=Enum.Font.GothamBold; rightBtn.Parent=pickerCard

        local function others()
            local t={}
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl~=LP then table.insert(t,pl) end
            end
            return t
        end
        local function refresh()
            local list=others()
            if #list==0 then selectedVictim=nil; victimNameLbl.Text="(no players)"; return end
            -- keep current if still valid, else pick first
            local stillThere=false
            for _,pl in ipairs(list) do if pl==selectedVictim then stillThere=true break end end
            if not stillThere then selectedVictim=list[1] end
            victimNameLbl.Text=selectedVictim.Name
        end
        local function step(dir)
            local list=others()
            if #list==0 then refresh(); return end
            local cur=1
            for i,pl in ipairs(list) do if pl==selectedVictim then cur=i break end end
            cur=(cur-1+dir)%#list+1
            selectedVictim=list[cur]; victimNameLbl.Text=selectedVictim.Name
        end
        leftBtn.MouseButton1Click:Connect(function() step(-1) end)
        rightBtn.MouseButton1Click:Connect(function() step(1) end)
        Players.PlayerAdded:Connect(function() task.wait(0.5); refresh() end)
        Players.PlayerRemoving:Connect(function() task.wait(0.2); refresh() end)
        refresh()
    end

    makeDivider(TrollPage,"FLING")

    makeActionCard(TrollPage,"Fling Target","FLING",flingVictim,
        "Teleports onto the selected player and spins to fling them away, then snaps you back to exactly where you were standing — they get launched, you stay put.")

    makeActionCard(TrollPage,"Fling Everyone","FLING ALL",flingAll,
        "Flings every other player one by one, returning to your spot between each. Loud and obvious — expect chaos.")

    makeModCard(TrollPage,"Spinbot",TROLL,"Spin",function(v) setSpin(v) end,
        "Continuously spins your character. Anyone who walks into you gets flung. Toggle off or hit Panic to stop spinning.",
        function(sf)
            makeSlider(sf,"Spin Power",5000,80000,TROLL.SpinPower,1000,"%.0f",function(v) TROLL.SpinPower=v end)
            makeSlider(sf,"Fling Time",0.4,3,TROLL.FlingDuration,0.1,"%.1f s",function(v) TROLL.FlingDuration=v end)
        end)

    makeDivider(TrollPage,"ANNOY")

    makeActionCard(TrollPage,"Teleport To","TP",tpToVictim,
        "Instantly teleports you next to the selected player. Great for following friends around.")

    makeModCard(TrollPage,"Stalk Mode",TROLL,"AnnoyEnabled",function(v) setAnnoy(v) end,
        "Glues you to the selected player, teleporting onto them 10x a second so you follow their every move. Disable or hit Panic to stop.")
end -- TROLL do..end

-- ═══════════════════════════════════════════════════════
--  DROP page  (Drop Balls for Brainrots — auto collect)
-- ═══════════════════════════════════════════════════════
do
    -- ── feature logic (scoped inside this block to save _hub locals) ──
    local DROP = {AutoEnabled=false, Slots=6, Delay=0.5,
                  AutoDrop=false, BallLevel=1, AutoLevel=false, DropDelay=0.5,
                  AutoEquip=false, EquipDelay=3,
                  FarmDrop=false, FarmBurst=5}
    local autoTask=nil
    local dropTask=nil
    local equipTask=nil
    local farmTask=nil
    local currentPlot=nil          -- e.g. "Plot2"
    local plotLbl, slotsLbl        -- UI labels, assigned below

    -- the Collect remote (sleitnick net package)
    local collectEvent
    pcall(function()
        collectEvent=game:GetService("ReplicatedStorage").Packages._Index["sleitnick_net@0.2.0"].net["RF/Collect"]
    end)
    -- the BallDrop remote (client -> server request to drop a ball)
    local dropEvent
    pcall(function()
        dropEvent=game:GetService("ReplicatedStorage").Packages._Index["sleitnick_net@0.2.0"].net["RE/BallDrop"]
    end)
    -- the EquipBestBrainrots remote (auto-equip your strongest brainrots)
    local equipEvent
    pcall(function()
        equipEvent=game:GetService("ReplicatedStorage").Packages._Index["sleitnick_net@0.2.0"].net["RF/EquipBestBrainrots"]
    end)

    -- find the player's plot by matching common owner patterns
    local function detectPlot()
        local found=nil
        pcall(function()
            -- find a container that holds the plots
            local container
            for _,name in ipairs({"Plots","Plot","Tycoons","Bases","Islands"}) do
                container=workspace:FindFirstChild(name)
                if container then break end
            end
            if not container then return end
            for _,plot in ipairs(container:GetChildren()) do
                -- 1) attribute on the plot
                for _,attr in ipairs({"Owner","OwnerName","OwnerId","Player","UserId"}) do
                    local val=plot:GetAttribute(attr)
                    if val~=nil then
                        local s=tostring(val)
                        if s==LP.Name or s==LP.DisplayName or s==tostring(LP.UserId) then
                            found=plot.Name; return
                        end
                    end
                end
                -- 2) value object child on the plot
                for _,cn in ipairs({"Owner","OwnerName","Player","Holder","UserId"}) do
                    local ov=plot:FindFirstChild(cn)
                    if ov then
                        if ov:IsA("ObjectValue") and ov.Value==LP then found=plot.Name; return end
                        if (ov:IsA("StringValue") or ov:IsA("IntValue") or ov:IsA("NumberValue")) then
                            local s=tostring(ov.Value)
                            if s==LP.Name or s==LP.DisplayName or s==tostring(LP.UserId) then
                                found=plot.Name; return
                            end
                        end
                    end
                end
            end
        end)
        return found
    end

    local function refreshPlot()
        currentPlot=detectPlot()
        if plotLbl then
            plotLbl.Text = currentPlot and ("Plot: "..currentPlot) or "Plot: (not found — set manually)"
            plotLbl.TextColor3 = currentPlot and Color3.fromRGB(120,255,150) or Color3.fromRGB(255,150,80)
        end
    end

    -- collect one slot; returns true if the server accepted it
    local function collectSlot(slot)
        if not currentPlot or not collectEvent then return false end
        local ok,res=pcall(function()
            return collectEvent:InvokeServer(currentPlot, tostring(slot))
        end)
        return ok and res and true or false
    end

    -- collect every slot 1..DROP.Slots once
    local function collectAll()
        if not currentPlot then if notify then notify("No plot detected — set it on the DROP tab") end return end
        if not collectEvent then if notify then notify("Collect remote not found") end return end
        local got=0
        for i=1,DROP.Slots do
            if collectSlot(i) then got=got+1 end
            task.wait(0.05)
        end
        if notify then notify("Collected "..got.."/"..DROP.Slots.." slots") end
    end

    local function setAuto(v)
        DROP.AutoEnabled=v
        if autoTask then task.cancel(autoTask); autoTask=nil end
        if v then
            if not currentPlot then refreshPlot() end
            autoTask=task.spawn(function()
                while DROP.AutoEnabled do
                    if currentPlot and collectEvent then
                        for i=1,DROP.Slots do
                            if not DROP.AutoEnabled then break end
                            collectSlot(i); task.wait(0.05)
                        end
                    else
                        refreshPlot()
                    end
                    task.wait(math.max(DROP.Delay,0.1))
                end
            end)
        end
    end

    local MAX_LEVEL=50  -- a real ball tier is small; anything bigger is a count, ignore it
    -- find your unlocked ball level (the FireServer arg scales 1,2,3...)
    -- STRICT: only a value whose name clearly means level/tier — never a "Balls" count
    local function detectBallLevel()
        local best=nil
        pcall(function()
            local function consider(name,value)
                local num=tonumber(value)
                if not num then return end
                num=math.floor(num)
                if num<1 or num>MAX_LEVEL then return end  -- reject counts like 422
                local n=string.lower(tostring(name))
                -- require BOTH a ball reference AND a level/tier word
                if string.find(n,"ball") and (string.find(n,"level") or string.find(n,"tier")) then
                    if not best or num>best then best=num end
                end
            end
            local ls=LP:FindFirstChild("leaderstats")
            if ls then
                for _,v in ipairs(ls:GetChildren()) do
                    if v:IsA("ValueBase") then consider(v.Name,v.Value) end
                end
            end
            for _,v in ipairs(LP:GetDescendants()) do
                if v:IsA("ValueBase") then consider(v.Name,v.Value) end
            end
            for an,av in pairs(LP:GetAttributes()) do consider(an,av) end
        end)
        return best
    end

    -- the level to send: auto-detected (if found & sane), else the manual slider
    local function currentBallLevel()
        if DROP.AutoLevel then
            local lvl=detectBallLevel()
            if lvl and lvl>=1 and lvl<=MAX_LEVEL then return lvl end
        end
        -- clamp manual value too, so a bad input can never send a huge number
        return math.clamp(math.floor(DROP.BallLevel),1,MAX_LEVEL)
    end

    -- drop one ball (server request)
    local function dropBall()
        if not dropEvent then if notify then notify("BallDrop remote not found") end return false end
        local ok=pcall(function() dropEvent:FireServer(currentBallLevel()) end)
        return ok
    end

    local function dropOnce()
        if dropBall() and notify then notify("Dropped ball (lvl "..currentBallLevel()..")") end
    end

    local function setAutoDrop(v)
        DROP.AutoDrop=v
        if dropTask then task.cancel(dropTask); dropTask=nil end
        if v then
            dropTask=task.spawn(function()
                while DROP.AutoDrop do
                    dropBall()
                    task.wait(math.max(DROP.DropDelay,0.1))
                end
            end)
        end
    end

    -- equip your best brainrots (server request, no args)
    local function equipBest()
        if not equipEvent then if notify then notify("EquipBest remote not found") end return false end
        local ok=pcall(function() equipEvent:InvokeServer() end)
        return ok
    end

    local function equipOnce()
        if equipBest() and notify then notify("Equipped best brainrots") end
    end

    local function setAutoEquip(v)
        DROP.AutoEquip=v
        if equipTask then task.cancel(equipTask); equipTask=nil end
        if v then
            equipTask=task.spawn(function()
                while DROP.AutoEquip do
                    equipBest()
                    task.wait(math.max(DROP.EquipDelay,0.5))
                end
            end)
        end
    end

    -- Ball Drop Farm: hammer level-1 drops as fast as possible to farm drop stats
    local function setBallFarm(v)
        DROP.FarmDrop=v
        if farmTask then task.cancel(farmTask); farmTask=nil end
        if v then
            farmTask=task.spawn(function()
                while DROP.FarmDrop do
                    if dropEvent then
                        for i=1,math.max(1,math.floor(DROP.FarmBurst)) do
                            if not DROP.FarmDrop then break end
                            pcall(function() dropEvent:FireServer(1) end)
                        end
                    end
                    task.wait()  -- one frame; burst x ~60/sec
                end
            end)
            if notify then notify("Ball Drop Farm ON — spamming lvl 1") end
        else
            if notify then notify("Ball Drop Farm OFF") end
        end
    end

    table.insert(cleanupHooks, function()
        DROP.AutoEnabled=false; if autoTask then task.cancel(autoTask); autoTask=nil end
        DROP.AutoDrop=false; if dropTask then task.cancel(dropTask); dropTask=nil end
        DROP.AutoEquip=false; if equipTask then task.cancel(equipTask); equipTask=nil end
        DROP.FarmDrop=false; if farmTask then task.cancel(farmTask); farmTask=nil end
    end)

    -- detect on join + when respawning
    task.defer(refreshPlot)
    pcall(function()
        LP.CharacterAdded:Connect(function() task.wait(1); refreshPlot() end)
    end)

    -- ── UI ──
    local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,38)
    hdr.BackgroundTransparency=1; hdr.Text="🔴  DROP BALLS"
    hdr.TextColor3=Color3.fromRGB(255,90,90); hdr.TextSize=15; hdr.Font=Enum.Font.GothamBold
    hdr.TextXAlignment=Enum.TextXAlignment.Center; hdr.LayoutOrder=O(); hdr.Parent=DropPage

    plotLbl=Instance.new("TextLabel"); plotLbl.Size=UDim2.new(1,0,0,20)
    plotLbl.BackgroundTransparency=1; plotLbl.Text="Plot: (detecting...)"
    plotLbl.TextColor3=Color3.fromRGB(180,180,210); plotLbl.TextSize=11; plotLbl.Font=Enum.Font.GothamBold
    plotLbl.TextXAlignment=Enum.TextXAlignment.Center; plotLbl.LayoutOrder=O(); plotLbl.Parent=DropPage

    makeDivider(DropPage,"PLOT")

    -- manual plot override (◀ ▶ cycles Plot1..Plot12) + re-detect
    do
        local card=Instance.new("Frame"); card.Size=UDim2.new(1,0,0,38)
        card.BackgroundColor3=CARD_OFF; card.BorderSizePixel=0
        card.LayoutOrder=O(); card.Parent=DropPage
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,7)
        local leftBtn=Instance.new("TextButton"); leftBtn.Size=UDim2.new(0,32,1,0)
        leftBtn.BackgroundTransparency=1; leftBtn.Text="◀"; leftBtn.TextColor3=ACCENT
        leftBtn.TextSize=14; leftBtn.Font=Enum.Font.GothamBold; leftBtn.Parent=card
        local mid=Instance.new("TextLabel"); mid.Size=UDim2.new(1,-64,1,0)
        mid.Position=UDim2.new(0,32,0,0); mid.BackgroundTransparency=1
        mid.Text="set plot manually"; mid.TextColor3=WHITE
        mid.TextSize=10; mid.Font=Enum.Font.GothamBold
        mid.TextXAlignment=Enum.TextXAlignment.Center; mid.Parent=card
        local rightBtn=Instance.new("TextButton"); rightBtn.Size=UDim2.new(0,32,1,0)
        rightBtn.Position=UDim2.new(1,-32,0,0); rightBtn.BackgroundTransparency=1
        rightBtn.Text="▶"; rightBtn.TextColor3=ACCENT
        rightBtn.TextSize=14; rightBtn.Font=Enum.Font.GothamBold; rightBtn.Parent=card
        local manualIdx=1
        local function setManual()
            currentPlot="Plot"..manualIdx
            mid.Text="forced: "..currentPlot
            if plotLbl then
                plotLbl.Text="Plot: "..currentPlot.." (manual)"
                plotLbl.TextColor3=Color3.fromRGB(255,220,120)
            end
        end
        leftBtn.MouseButton1Click:Connect(function() manualIdx=math.max(1,manualIdx-1); setManual() end)
        rightBtn.MouseButton1Click:Connect(function() manualIdx=math.min(12,manualIdx+1); setManual() end)
    end

    makeActionCard(DropPage,"Re-detect Plot","DETECT",refreshPlot,
        "Re-scans the workspace for the plot you own. Use this if the auto-detect didn't find it on join.")

    makeDivider(DropPage,"COLLECT")

    makeActionCard(DropPage,"Collect Now","COLLECT",collectAll,
        "Fires the Collect remote once for every slot (1 to your slot count). Make sure the correct plot is shown above.")

    makeModCard(DropPage,"Auto Collect",DROP,"AutoEnabled",function(v) setAuto(v) end,
        "Loops collection across all your slots on a timer. Set how many slots you have and how often to collect. Stops on disable or Panic.",
        function(sf)
            makeSlider(sf,"Slots",1,12,DROP.Slots,1,"%.0f",function(v) DROP.Slots=v end)
            makeSlider(sf,"Delay",0.1,10,DROP.Delay,0.1,"%.1f s",function(v) DROP.Delay=v end)
        end)

    makeDivider(DropPage,"DROP BALLS")

    makeActionCard(DropPage,"Drop Ball Now","DROP",dropOnce,
        "Fires the BallDrop remote once at your current ball level. Level is set in Auto Drop's settings below.")

    makeModCard(DropPage,"Auto Drop",DROP,"AutoDrop",function(v) setAutoDrop(v) end,
        "Spam-drops balls on a timer. Set 'Ball Level' to the tier you've unlocked (bump it as you progress). 'Auto Best Level' tries to read it for you — leave OFF unless it detects correctly.",
        function(sf)
            makeToggle(sf,"Auto Best Level",DROP.AutoLevel,function(v) DROP.AutoLevel=v end)
            makeSlider(sf,"Ball Level (manual)",1,30,DROP.BallLevel,1,"%.0f",function(v) DROP.BallLevel=v end)
            makeSlider(sf,"Drop Delay",0.1,5,DROP.DropDelay,0.1,"%.1f s",function(v) DROP.DropDelay=v end)
        end)

    makeModCard(DropPage,"Ball Drop Farm",DROP,"FarmDrop",function(v) setBallFarm(v) end,
        "Hammers level-1 ball drops as fast as possible to farm drop statistics. Burst = drops per frame. Turn down if it lags or kicks you. Stops on disable or Panic.",
        function(sf)
            makeSlider(sf,"Burst / frame",1,20,DROP.FarmBurst,1,"%.0f",function(v) DROP.FarmBurst=v end)
        end)

    makeDivider(DropPage,"BRAINROTS")

    makeActionCard(DropPage,"Equip Best","EQUIP",equipOnce,
        "Fires RF/EquipBestBrainrots once to auto-equip your strongest brainrots.")

    makeModCard(DropPage,"Auto Equip Best",DROP,"AutoEquip",function(v) setAutoEquip(v) end,
        "Re-equips your best brainrots on a timer so newly-won ones get slotted automatically. Stops on disable or Panic.",
        function(sf)
            makeSlider(sf,"Equip Delay",0.5,30,DROP.EquipDelay,0.5,"%.1f s",function(v) DROP.EquipDelay=v end)
        end)
end -- DROP do..end

-- ═══════════════════════════════════════════════════════
--  GAMES page  (supported games — click to teleport)
-- ═══════════════════════════════════════════════════════
do
    -- placeId of 0 = not set yet (paste the game's roblox.com link's number)
    local GAMES = {
        {name="Become a Billionaire", placeId=0, note="Rebirth + NPC auto-buy"},
        {name="Drop Balls for Brainrots", placeId=0, note="Auto drop / collect / equip / farm"},
    }
    local TeleportService=game:GetService("TeleportService")

    local function joinGame(g)
        if not g.placeId or g.placeId==0 then
            if notify then notify(g.name..": placeId not set yet") end
            return
        end
        if notify then notify("Teleporting to "..g.name.."...") end
        pcall(function() TeleportService:Teleport(g.placeId, LP) end)
    end

    local hdr=Instance.new("TextLabel"); hdr.Size=UDim2.new(1,0,0,38)
    hdr.BackgroundTransparency=1; hdr.Text="🎮  SUPPORTED GAMES"
    hdr.TextColor3=Color3.fromRGB(120,200,255); hdr.TextSize=15; hdr.Font=Enum.Font.GothamBold
    hdr.TextXAlignment=Enum.TextXAlignment.Center; hdr.LayoutOrder=O(); hdr.Parent=GamesPage

    local subHdr=Instance.new("TextLabel"); subHdr.Size=UDim2.new(1,0,0,18)
    subHdr.BackgroundTransparency=1; subHdr.Text="click PLAY to teleport into a supported game"
    subHdr.TextColor3=DIM; subHdr.TextSize=10; subHdr.Font=Enum.Font.Gotham
    subHdr.TextXAlignment=Enum.TextXAlignment.Center; subHdr.LayoutOrder=O(); subHdr.Parent=GamesPage

    makeDivider(GamesPage,"GAMES")

    for _,g in ipairs(GAMES) do
        local card=Instance.new("Frame"); card.Size=UDim2.new(1,0,0,52)
        card.BackgroundColor3=CARD_OFF; card.BorderSizePixel=0
        card.LayoutOrder=O(); card.Parent=GamesPage
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,7)
        local bar=Instance.new("Frame"); bar.Size=UDim2.new(0,3,0,32)
        bar.Position=UDim2.new(0,6,0.5,-16); bar.BackgroundColor3=ACCENT; bar.BorderSizePixel=0
        bar.Parent=card; Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)
        table.insert(accentEls,bar)

        local nameLbl=Instance.new("TextLabel"); nameLbl.Size=UDim2.new(1,-110,0,20)
        nameLbl.Position=UDim2.new(0,16,0,8); nameLbl.BackgroundTransparency=1
        nameLbl.Text=g.name; nameLbl.TextColor3=WHITE; nameLbl.TextSize=12
        nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
        nameLbl.TextTruncate=Enum.TextTruncate.AtEnd; nameLbl.Parent=card

        local noteLbl=Instance.new("TextLabel"); noteLbl.Size=UDim2.new(1,-110,0,14)
        noteLbl.Position=UDim2.new(0,16,0,28); noteLbl.BackgroundTransparency=1
        noteLbl.Text=g.note; noteLbl.TextColor3=DIM; noteLbl.TextSize=9
        noteLbl.Font=Enum.Font.Gotham; noteLbl.TextXAlignment=Enum.TextXAlignment.Left
        noteLbl.TextTruncate=Enum.TextTruncate.AtEnd; noteLbl.Parent=card

        local playBtn=Instance.new("TextButton"); playBtn.Size=UDim2.new(0,82,0,28)
        playBtn.Position=UDim2.new(1,-90,0.5,-14); playBtn.BackgroundColor3=ACCENT
        playBtn.Text="PLAY"; playBtn.TextColor3=WHITE; playBtn.TextSize=10
        playBtn.Font=Enum.Font.GothamBold; playBtn.BorderSizePixel=0; playBtn.Parent=card
        Instance.new("UICorner",playBtn).CornerRadius=UDim.new(0,5)
        table.insert(accentEls,playBtn)
        playBtn.MouseButton1Click:Connect(function()
            TweenService:Create(playBtn,TweenInfo.new(0.06),{BackgroundColor3=Color3.fromRGB(50,50,170)}):Play()
            task.delay(0.18,function() TweenService:Create(playBtn,TweenInfo.new(0.12),{BackgroundColor3=ACCENT}):Play() end)
            joinGame(g)
        end)
    end

    do
        local info=Instance.new("TextLabel"); info.Size=UDim2.new(1,0,0,40)
        info.BackgroundTransparency=1
        info.Text="more games coming soon — this list grows as new games get supported"
        info.TextColor3=Color3.fromRGB(70,70,100); info.TextSize=9; info.Font=Enum.Font.Gotham
        info.TextWrapped=true; info.TextXAlignment=Enum.TextXAlignment.Center
        info.LayoutOrder=O(); info.Parent=GamesPage
    end
end -- GAMES do..end

do -- 🍋 LEMONS (Sell Lemons tycoon)
    -- ── State ───────────────────────────────────────────
    local LEMONS={AutoUpgrade=false, UpgradeDelay=1.0}

    -- Add more names here as user provides them
    local UPGRADE_LIST={
        "Lemon Stand","Lemon Trading","Lemon Depot","Lemon Labs",
        "Lemon Republic","Lemon Robotics","LemonDash","LemonX","LemonX Ground",
    }
    local selUpgrade="Lemon Stand"
    local upgradeTask=nil
    local selBtns={}   -- {name -> {row, dot}} for radio UI

    -- ── Logic ───────────────────────────────────────────
    local function findTycoon()
        local mine=nil
        for _,t in ipairs(workspace:GetChildren()) do
            if t.Name:match("^Tycoon") and not mine then
                pcall(function()
                    local ow=t:FindFirstChild("Owner")
                    if not ow then return end
                    if ow.Value==LP or ow.Value==LP.Name then mine=t end
                end)
            end
        end
        return mine
    end

    local function doUpgradeOne(name)
        local t=findTycoon(); if not t then return end
        pcall(function()
            t.Purchases[name][name][name].Upgrade:InvokeServer(1)
        end)
    end

    local function doUpgrade()
        -- single upgrade for "Upgrade Once" button (uses selector)
        local t=findTycoon(); if not t then
            if notify then notify("Lemons: tycoon not found") end; return
        end
        local ok,err=pcall(function()
            t.Purchases[selUpgrade][selUpgrade][selUpgrade].Upgrade:InvokeServer(1)
        end)
        if not ok and notify then notify("Lemons: "..tostring(err):sub(1,60)) end
    end

    local function setAutoUpgrade(v)
        LEMONS.AutoUpgrade=v
        if upgradeTask then task.cancel(upgradeTask); upgradeTask=nil end
        if v then
            upgradeTask=task.spawn(function()
                while LEMONS.AutoUpgrade do
                    -- upgrade every item in the list each tick
                    for _,name in ipairs(UPGRADE_LIST) do
                        doUpgradeOne(name)
                    end
                    task.wait(LEMONS.UpgradeDelay)
                end
            end)
        end
    end

    table.insert(cleanupHooks,function()
        LEMONS.AutoUpgrade=false
        if upgradeTask then task.cancel(upgradeTask); upgradeTask=nil end
    end)

    -- ── Auto Buy ────────────────────────────────────────
    local AUTOBUY={Enabled=false, Delay=0.5}
    local buyTask=nil

    local function parseMoney(str)
        if not str then return nil end
        local n=tostring(str):gsub(",",""):match("([%d%.]+)")
        return n and tonumber(n) or nil
    end

    local function getCash()
        -- try leaderstats
        local ls=LP:FindFirstChild("leaderstats")
        if ls then
            for _,v in ipairs(ls:GetChildren()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("NumberValue") then
                    local nm=v.Name:lower()
                    if nm:find("cash") or nm:find("money") or nm:find("coin") or nm:find("lemon") or nm:find("dollar") or nm:find("balance") then
                        return v.Value
                    end
                end
            end
        end
        -- try player attributes
        for _,nm in ipairs({"Cash","Money","Coins","Dollars","Lemons","Balance","currency"}) do
            local ok,val=pcall(function() return LP:GetAttribute(nm) end)
            if ok and type(val)=="number" then return val end
        end
        return math.huge -- can't find cash; let server validate
    end

    local function getButtonPrice(btn)
        -- 1. NumberValue/IntValue child named Price/Cost
        for _,c in ipairs(btn:GetChildren()) do
            if c:IsA("NumberValue") or c:IsA("IntValue") then
                local nm=c.Name:lower()
                if nm:find("price") or nm:find("cost") or nm:find("value") or nm:find("amount") then
                    return c.Value
                end
            end
        end
        -- 2. Attribute on the button
        for _,nm in ipairs({"Price","Cost","Value","Amount"}) do
            local ok,val=pcall(function() return btn:GetAttribute(nm) end)
            if ok and type(val)=="number" and val>0 then return val end
        end
        -- 3. Parse $ from a TextLabel inside Billboard
        local bb=btn:FindFirstChild("Billboard")
        if bb then
            for _,c in ipairs(bb:GetDescendants()) do
                if c:IsA("TextLabel") then
                    local t=c.Text or ""
                    if t:find("%$") then
                        local v=parseMoney(t)
                        if v and v>0 then return v end
                    end
                end
            end
        end
        return 0 -- price unknown; will attempt anyway
    end

    local function scanButtons(tycoon)
        local result={}
        local purch=tycoon:FindFirstChild("Purchases"); if not purch then return result end
        for _,desc in ipairs(purch:GetDescendants()) do
            if desc.Name=="Purchase" and
               (desc:IsA("RemoteFunction") or desc:IsA("RemoteEvent")) then
                -- Walk up the tree to find an ancestor whose parent is named "Buttons"
                -- That ancestor is the button, regardless of how many layers deep Purchase is
                local cur=desc.Parent
                local btn=nil
                local cat=nil
                while cur and cur~=purch do
                    if cur.Parent and cur.Parent.Name=="Buttons" then
                        btn=cur
                        cat=cur.Parent.Parent
                        break
                    end
                    cur=cur.Parent
                end
                if btn then
                    table.insert(result,{
                        remote=desc,
                        isEvent=desc:IsA("RemoteEvent"),
                        price=getButtonPrice(btn),
                        name=btn.Name,
                        cat=cat and cat.Name or "?",
                    })
                end
            end
        end
        return result
    end

    local function scanDebug()
        local t=findTycoon()
        if not t then
            if notify then notify("Scan: no tycoon found") end; return
        end
        local purch=t:FindFirstChild("Purchases")
        if not purch then
            if notify then notify("Scan: no Purchases in "..t.Name) end; return
        end
        local cats=purch:GetChildren()
        if #cats==0 then
            if notify then notify("Scan: Purchases is empty") end; return
        end
        local btns=scanButtons(t)
        if #btns==0 then
            if notify then notify("Scan: "..t.Name.." has "..#cats.." cats but 0 buttons") end
        else
            if notify then notify("Scan: "..t.Name.." → "..#btns.." button(s) found") end
            for i,b in ipairs(btns) do
                if i<=4 then
                    if notify then task.delay((i-1)*1.5,function()
                        notify(b.cat.."/"..b.name.." $"..b.price)
                    end) end
                end
            end
        end
    end

    local function doBuyOne()
        local t=findTycoon()
        if not t then
            if notify then notify("AutoBuy: tycoon not found") end; return false
        end
        local buttons=scanButtons(t)
        if #buttons==0 then
            if notify then notify("AutoBuy: no buttons found in "..t.Name) end; return false
        end
        table.sort(buttons,function(a,b) return a.price<b.price end)
        local bought=0
        local skippedOwned=0
        local skippedAfford=0
        local realErr=nil
        for _,b in ipairs(buttons) do
            local ok,res
            if b.isEvent then
                ok=pcall(function() b.remote:FireServer(false) end)
                res=nil
            else
                ok,res=pcall(function() return b.remote:InvokeServer(false) end)
            end
            if ok then
                if res==false then
                    skippedAfford=skippedAfford+1
                else
                    bought=bought+1
                    if notify then notify("Bought: "..b.name) end
                end
            else
                local err=tostring(res)
                local low=err:lower()
                if low:find("already") or low:find("purchased") or low:find("owned")
                   or low:find("not purchasable") or low:find("disabled") then
                    skippedOwned=skippedOwned+1
                else
                    realErr=err
                    warn("[SkullzzHub AutoBuy] "..b.name.." ERR: "..err)
                end
            end
        end
        if bought==0 and notify then
            if realErr then
                local short=realErr:match(": (.+)$") or realErr
                notify("AutoBuy ERR: "..short:sub(1,70))
            else
                notify("AutoBuy: "..#buttons.." found | "..skippedOwned.." owned | "..skippedAfford.." too expensive")
            end
        end
        return bought>0
    end

    local function setAutoBuy(v)
        AUTOBUY.Enabled=v
        if buyTask then task.cancel(buyTask); buyTask=nil end
        if v then
            doBuyOne()
            buyTask=task.spawn(function()
                while AUTOBUY.Enabled do
                    task.wait(AUTOBUY.Delay)
                    doBuyOne()
                end
            end)
        end
    end

    table.insert(cleanupHooks,function()
        AUTOBUY.Enabled=false
        if buyTask then task.cancel(buyTask); buyTask=nil end
    end)

    -- ── UI ──────────────────────────────────────────────
    makeDivider(LemonsPage,"AUTO UPGRADE")

    makeModCard(LemonsPage,"Auto Upgrade",LEMONS,"AutoUpgrade",
        function(v) setAutoUpgrade(v) end,
        "Repeatedly upgrades the selected stand in your tycoon. Pick the target below.",
        function(sf)
            makeSlider(sf,"Delay",0.1,10,LEMONS.UpgradeDelay,0.1,"%.1f s",
                function(v) LEMONS.UpgradeDelay=v end)
            makeButton(sf,"Upgrade Once",function() doUpgrade() end)
        end
    )

    makeDivider(LemonsPage,"UPGRADE TARGET")

    -- Radio-style selector: one row per upgrade item
    local function updateSelUI()
        for n,refs in pairs(selBtns) do
            local on=(n==selUpgrade)
            refs.row.BackgroundColor3=on and CARD_ON or CARD_OFF
            refs.dot.BackgroundColor3=on and ACCENT or DIM
        end
    end

    for _,itemName in ipairs(UPGRADE_LIST) do
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,36)
        row.BackgroundColor3=(itemName==selUpgrade) and CARD_ON or CARD_OFF
        row.BorderSizePixel=0; row.LayoutOrder=O(); row.Parent=LemonsPage
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
        local st=Instance.new("UIStroke",row); st.Color=BORDER; st.Thickness=1
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-40,1,0)
        lbl.Position=UDim2.new(0,12,0,0); lbl.BackgroundTransparency=1
        lbl.Text=itemName; lbl.TextColor3=WHITE; lbl.Font=Enum.Font.GothamBold
        lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row
        local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,10,0,10)
        dot.AnchorPoint=Vector2.new(1,0.5); dot.Position=UDim2.new(1,-12,0.5,0)
        dot.BackgroundColor3=(itemName==selUpgrade) and ACCENT or DIM
        dot.BorderSizePixel=0; dot.Parent=row
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
        local clickBtn=Instance.new("TextButton"); clickBtn.Size=UDim2.new(1,0,1,0)
        clickBtn.BackgroundTransparency=1; clickBtn.Text=""; clickBtn.Parent=row
        selBtns[itemName]={row=row,dot=dot}
        clickBtn.MouseButton1Click:Connect(function()
            selUpgrade=itemName; updateSelUI()
        end)
    end

    makeDivider(LemonsPage,"AUTO BUY")
    makeModCard(LemonsPage,"Auto Buy",AUTOBUY,"Enabled",
        function(v) setAutoBuy(v) end,
        "Scans your tycoon for all purchase buttons and buys everything you can afford on repeat.",
        function(sf)
            makeSlider(sf,"Delay",0.3,5,AUTOBUY.Delay,0.1,"%.1f s",
                function(v) AUTOBUY.Delay=v end)
            makeButton(sf,"Buy Once",function() doBuyOne() end)
            makeButton(sf,"Scan Debug",function() scanDebug() end)
        end
    )

end -- LEMONS do..end

end -- _hub()

warn("[SkullzzHub] _hub defined, calling now")
xpcall(_hub, function(e)
    warn("[SkullzzHub] RUNTIME ERROR: "..tostring(e))
    pcall(function()
        local sg=Instance.new("ScreenGui"); sg.IgnoreGuiInset=true; sg.ResetOnSpawn=false
        pcall(function() sg.Parent=gethui()                                                                                                      end)
        if not sg.Parent then pcall(function() sg.Parent=game:GetService("CoreGui") end) end
        if not sg.Parent then pcall(function() sg.Parent=game.Players.LocalPlayer.PlayerGui end) end
        local f=Instance.new("Frame"); f.Size=UDim2.new(0,520,0,120)
        f.AnchorPoint=Vector2.new(0.5,0.5); f.Position=UDim2.new(0.5,0,0.5,0)
        f.BackgroundColor3=Color3.fromRGB(10,0,0); f.BorderSizePixel=0; f.Parent=sg
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
        local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,-12,1,-8)
        t.Position=UDim2.new(0,6,0,4); t.BackgroundTransparency=1
        t.Text="[SkullzzHub] LOAD ERROR — screenshot and report:\n"..tostring(e)
        t.TextColor3=Color3.fromRGB(255,80,80); t.TextSize=11
        t.Font=Enum.Font.GothamBold; t.TextWrapped=true
        t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=f
    end)
end)
