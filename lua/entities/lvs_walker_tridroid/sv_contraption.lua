function ENT:ContraptionThink()
	local OnMoveableFloor = self:CheckGround()

	if not IsValid( self:GetDriver() ) and not self:GetAI() then
		self:ApproachTargetSpeed( 0 )
		self:SetTargetSteer( 0 )
	end

	self:CheckUpRight()
	self:CheckActive()
	self:CheckMotion( OnMoveableFloor )
	self:UpdateLegs()
end

function ENT:UpdateLegs()
	local T = CurTime()

	local PhysObj = self:GetPhysicsObject()

	local Delay = math.max(1.5 - math.max( self:GetVelocity():Length() / 150, math.abs( PhysObj:GetAngleVelocity().z / 23) ), 0.35)

	if ((self._NextLeg or 0) + Delay ) > T then return end

	if not self:GetIsMoving() then return end

	self._NextLeg = T

	-- 3 legs: cycle 1 -> 2 -> 3 -> 1
	local Next = self:GetUpdateLeg() + (self:GetTargetSpeed() >= 0 and 1 or -1)

	if Next > 3 then
		Next = 1
	end

	if Next < 1 then
		Next = 3
	end

	self:SetUpdateLeg( Next )
end

function ENT:CheckUpRight()
	if self:IsPlayerHolding() then return end

	-- Grace period: don't ragdoll within 2 seconds of spawn
	if (self._SpawnTime or 0) + 2 > CurTime() then return end

	if self:HitGround() and self:AngleBetweenNormal( self:GetUp(), Vector(0,0,1) ) < 45 then
		return
	end

	self:BecomeRagdoll()
end

function ENT:CheckActive()
	local ShouldBeActive = self:HitGround() and not self:GetIsRagdoll()

	if ShouldBeActive ~= self:GetEngineActive() then
		self:SetEngineActive( ShouldBeActive )
	end
end

function ENT:ToggleGravity( PhysObj, Enable )
	if PhysObj:IsGravityEnabled() ~= Enable then
		PhysObj:EnableGravity( Enable )
	end
end

function ENT:CheckMotion( OnMoveableFloor )
	if self:GetIsRagdoll() then
		return
	end

	local TargetSpeed = self:GetTargetSpeed()

	if not self:HitGround() then
		self:SetIsMoving( false )
	else
		self:SetIsMoving( math.abs( TargetSpeed ) > 1 )
	end

	local IsHeld = self:IsPlayerHolding()

	if IsHeld then
		self:SetTargetSpeed( 200 )
	end

	if self:HitGround() and not OnMoveableFloor then
		local enable = self:GetIsMoving() or IsHeld

		local phys = self:GetPhysicsObject()

		if not IsValid( phys ) then return end

		if phys:IsMotionEnabled() ~= enable then
			phys:EnableMotion( enable )
			phys:Wake()
		end
	else
		local enable = self:GetIsMoving() or IsHeld or OnMoveableFloor

		local phys = self:GetPhysicsObject()

		if not IsValid( phys ) then return end

		if not phys:IsMotionEnabled() then
			phys:EnableMotion( enable )
			phys:Wake()
		end
	end
end

-- 3 legs + center: triangle layout at 120 degree intervals
-- TODO: adjust positions to match model leg attachment spread
local StartPositions = {
	[1] = Vector(0,0,0),
	[2] = Vector(200,0,0),
	[3] = Vector(-100,173,0),
	[4] = Vector(-100,-173,0),
}

function ENT:CheckGround()
	local NumHits = 0
	local FirstTraceHasHit = false
	local HitMoveable

	local phys = self:GetPhysicsObject()

	if not IsValid( phys ) then return false end

	for id, pos in ipairs( StartPositions ) do
		local masscenter = phys:LocalToWorld( phys:GetMassCenter() + pos )

		-- Debug: visualize trace lines (green = start, red = end)
		debugoverlay.Line( masscenter, masscenter - self:GetUp() * self.HoverTraceLength, 0.1, Color(255,0,0), true )
		debugoverlay.Cross( masscenter, 10, 0.1, Color(0,255,0), true )

		local trace = util.TraceHull( {
			start = masscenter,
			endpos = masscenter - self:GetUp() * self.HoverTraceLength,
			mins = Vector( -self.HoverHullRadius, -self.HoverHullRadius, 0 ),
			maxs = Vector( self.HoverHullRadius, self.HoverHullRadius, 0 ),
			filter = function( entity )
				if self:GetCrosshairFilterLookup()[ entity:EntIndex() ] or entity:IsPlayer() or entity:IsNPC() or entity:IsVehicle() or self.HoverCollisionFilter[ entity:GetCollisionGroup() ] then
					return false
				end

				return true
			end,
		} )

		if id == 1 then
			FirstTraceHasHit = trace.Hit
		end

		if not HitMoveable then
			if IsValid( trace.Entity ) then
				HitMoveable = self.CanMoveOn[ trace.Entity:GetClass() ]
			end
		end

		if not trace.Hit or trace.HitSky then continue end

		NumHits = NumHits + 1
	end

	-- 4 trace positions (center + 3 legs), need at least 2 to consider grounded
	local HitGround = NumHits >= (FirstTraceHasHit and 2 or 1)

	if self:GetNWGround() ~= HitGround then
		self:SetNWGround( HitGround )
	end

	self.HoverHeight = 300 + (100 / 4) * NumHits

	if NumHits <= 2 then
		return true
	end

	return HitMoveable == true
end
