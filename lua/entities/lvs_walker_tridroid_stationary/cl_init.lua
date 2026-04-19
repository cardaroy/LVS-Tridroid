include("shared.lua")
include("cl_camera.lua")
include("cl_prediction.lua")
include("sh_weapons.lua")

function ENT:OnFrame()
	self:PredictPoseParamaters()
	self:DamageFX()
	self:CalcHeadAim()
--	self:CalcGunAim()
end

function ENT:DamageFX()
	self.nextDFX = self.nextDFX or 0

	if self.nextDFX < CurTime() then
		self.nextDFX = CurTime() + 0.05

		if self:GetIsRagdoll() then
			if math.random(0,45) < 3 then
				if math.random(1,2) == 1 then
					-- TODO: adjust spark position to match model
					local Pos = self:LocalToWorld( Vector(0,0,250) + VectorRand() * 80 )
					local effectdata = EffectData()
						effectdata:SetOrigin( Pos )
					util.Effect( "cball_explode", effectdata, true, true )

					sound.Play( "lvs/vehicles/atte/spark"..math.random(1,4)..".ogg", Pos, 75 )
				end
			end
		end

		local HP = self:GetHP()
		local MaxHP = self:GetMaxHP()

		if HP > MaxHP * 0.5 then return end

		-- TODO: adjust smoke/fire positions to match model
		local effectdata = EffectData()
			effectdata:SetOrigin( self:LocalToWorld( Vector(0,0,260) + VectorRand() * 80 ) )
			effectdata:SetEntity( self )
		util.Effect( "lvs_engine_blacksmoke", effectdata )

		if HP <= MaxHP * 0.25 then
			local effectdata = EffectData()
				effectdata:SetOrigin( self:LocalToWorld( Vector(0,0,210) ) )
				effectdata:SetNormal( self:GetUp() )
				effectdata:SetMagnitude( math.Rand(1,3) )
				effectdata:SetEntity( self )
			util.Effect( "lvs_exhaust_fire", effectdata )
		end
	end
end

-- TODO: adjust glow positions/colors to match model
ENT.GlowPos1 = Vector(0,0,295)
ENT.GlowColor = Color( 255, 0, 0, 255)
ENT.GlowMaterial = Material( "sprites/light_glow02_add" )

function ENT:PreDrawTranslucent()
	if self:GetIsRagdoll() then return false end

	render.SetMaterial( self.GlowMaterial )
	render.DrawSprite( self:LocalToWorld( self.GlowPos1 ), 32, 32, self.GlowColor )

	return false
end

local zoom = 0
local zoom_mat = Material( "vgui/zoom" )

function ENT:PaintZoom( X, Y, ply )
	local TargetZoom = ply:lvsKeyDown( "ZOOM" ) and 1 or 0

	zoom = zoom + (TargetZoom - zoom) * RealFrameTime() * 10

	X = X * 0.5
	Y = Y * 0.5

	surface.SetDrawColor( Color(255,255,255,255 * zoom) )
	surface.SetMaterial( zoom_mat )
	surface.DrawTexturedRectRotated( X + X * 0.5, Y * 0.5, X, Y, 0 )
	surface.DrawTexturedRectRotated( X + X * 0.5, Y + Y * 0.5, Y, X, 270 )
	surface.DrawTexturedRectRotated( X * 0.5, Y * 0.5, Y, X, 90 )
	surface.DrawTexturedRectRotated( X * 0.5, Y + Y * 0.5, X, Y, 180 )
end

local COLOR_RED = Color(255,0,0,255)
local COLOR_WHITE = Color(255,255,255,255)

function ENT:LVSHudPaint( X, Y, ply )
	if ply ~= self:GetDriver() then
		return
	end

	local Col = self:WeaponsInRange() and COLOR_WHITE or COLOR_RED

	local Pos2D = self:GetEyeTrace().HitPos:ToScreen()

	self:PaintCrosshairCenter( Pos2D, Col )
	self:PaintCrosshairOuter( Pos2D, Col )
	self:LVSPaintHitMarker( Pos2D )

	self:PaintZoom( X, Y, ply )
end

ENT.IconEngine = Material( "lvs/engine.png" )

function ENT:LVSHudPaintInfoText( X, Y, W, H, ScrX, ScrY, ply )
	local Vel = self:GetVelocity():Length()

	local speed = math.Round( LVS:GetUnitValue( Vel ), 0 )
	draw.DrawText( LVS:GetUnitName().." ", "LVS_FONT", X + 72, Y + 35, color_white, TEXT_ALIGN_RIGHT )
	draw.DrawText( speed, "LVS_FONT_HUD_LARGE", X + 72, Y + 20, color_white, TEXT_ALIGN_LEFT )

	if ply ~= self:GetDriver() then return end

	local hX = X + W - H * 0.5
	local hY = Y + H * 0.25 + H * 0.25

	surface.SetMaterial( self.IconEngine )
	surface.SetDrawColor( 0, 0, 0, 200 )
	surface.DrawTexturedRectRotated( hX + 4, hY + 1, H * 0.5, H * 0.5, 0 )
	surface.SetDrawColor( color_white )
	surface.DrawTexturedRectRotated( hX + 2, hY - 1, H * 0.5, H * 0.5, 0 )

	if not self:GetEngineActive() then
		draw.SimpleText( "X", "LVS_FONT", hX, hY, Color(0,0,0,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	else
		local Throttle = Vel / 150
		self:LVSDrawCircle( hX, hY, H * 0.35, math.min( Throttle, 1 ) )
	end
end

function ENT:CalcHeadAim()
	--Find the bone index for "head" in the model's skeleton, if you can't find it return end
	local headBone = self:LookupBone("head")
	if not headBone then return end

	--Get the networked aim direction vector (set by SetAIAimVector) and convert it to local angles of the entity
	local aimDir = self:GetAimVector()
	local aimAng = self:WorldToLocalAngles( aimDir:Angle() )

	--Read the networked gun index (0, 1, or 2) to offset head yaw by 120 degrees per gun
	local gunIndex = self:GetNWInt("GunIndex", 0)

	--Calculate the target angles: aim direction + gun rotation offset, no roll
	local targetAng = Angle(0, aimAng.y + gunIndex * 120 + 60, 0)

	--Initialise the smoothed head angle on first call (starts facing forward)
	self._HeadAng = self._HeadAng or Angle(0,0,0)
	--Smoothly interpolate the head angle towards the target angle for natural movement
	self._HeadAng = LerpAngle( RealFrameTime() * 4, self._HeadAng, targetAng )
	--Apply the smoothed head angle to the head bone
	self:ManipulateBoneAngles( headBone, self._HeadAng )

	--For aiming the current turret bone
	local gunBone = "gunA"

	
--	local gunTargetAng = Angle(-aimAng.x, 0, 0)

	self._gunAng = self._gunAng or Angle(0,0,0)

	if gunIndex == 1 then
		gunBone = self:LookupBone("gunA")
		gunTargetAng = Angle(0, 0, -aimAng.x)
	elseif gunIndex == 2 then
		gunBone = self:LookupBone("gunB")
		gunTargetAng = Angle(aimAng.x, 0, 0)
	elseif gunIndex == 0 then
		gunBone = self:LookupBone("gunC")
		gunTargetAng = Angle(-aimAng.x, 0, 0)
	end

	if not gunBone then return end

--	local gunTargetAng = Angle(-aimAng.x, 0, 0)
	self._gunAng = self._gunAng or Angle(0,0,0)

	self._gunAng = LerpAngle( RealFrameTime() * 2, self._gunAng, gunTargetAng)

	self:ManipulateBoneAngles( gunBone, self._gunAng )
end
--[[
function ENT:CalcGunAim()
	--gun bones are "gunA", "gunB", "gunC"

	local aimDir = self:GetAimVector()
	local aimAng = self:WorldToLocalAngles( aimDir:Angle() )

	local gunIndex = self:GetNWInt("GunIndex", 0)

	local gunBone

	if gunIndex == 0 then
		gunBone = "gunA"
	elseif gunIndex == 1 then
		gunBone = "gunB"
	elseif gunIndex == 2 then
		gunBone = "gunC"
	end

	if not gunBone then return end

	self._gunAng = self._gunAng or Angle(0,0,0)

	self._gunAng = LerpAngle( RealFrameTime() * 2, self._gunAng, targetAng)

	self:ManipulateBoneAngles( gunBone, self._gunAng )
end
--]]