function ENT:UnRagdoll()
	if not self.Constrainer then return end

	self:SetTargetSpeed( 200 )
	self:SetIsRagdoll( false )

	for _, ent in pairs( self.Constrainer ) do
		if not IsValid( ent ) then continue end

		if ent == self then continue end

		ent:Remove()
	end

	self.Constrainer = nil

	self.DoNotDuplicate = false
end

function ENT:BecomeRagdoll()
	if self.Constrainer then return end

	self:SetIsRagdoll( true )

	self:EmitSound( "lvs/vehicles/atte/becomeragdoll.ogg", 85 )

	self.Constrainer = {
		[0] = self,
	}

	self.DoNotDuplicate = true

	-- TODO: adjust leg segment models/positions/angles to match tridroid model
	local LegSegments = {
		[1] = {
			mdl = "models/tridroid/cis_tridroid_lowerleg.mdl",
			pos = Vector(230, 0, 230),
			ang = Angle(-30,0,0),
		} --[[
		[2] = {
			mdl = "models/tridroid/cis_tridroid_upperleg.mdl",
			pos = Vector(0,-15,20),
			ang = Angle(0,0,-17),
		}, --]]
	}

	-- 3 legs at 120 degree intervals
	-- TODO: adjust attachment names and angles to match model
	local Legs = {
		[1] = {
			id = "F",
			name = "leg_front",
			ang = 0,
		},
		[2] = {
			id = "RL",
			name = "leg_rear_left",
			ang = 120,
		},
		[3] = {
			id = "RR",
			name = "leg_rear_right",
			ang = -120,
		},
	}

	local Fric = 1500
	local Index = 0

	for _, data in pairs( Legs ) do
		Index = Index + 1

		local ID = self:LookupAttachment( data.name )
		local Att = self:GetAttachment( ID )

		if not Att then return end

		local ent = ents.Create( "lvs_walker_atte_component" )
		-- TODO: set actual upper leg model
		ent:SetModel( "models/tridroid/cis_tridroid_upperleg.mdl" )
		ent:SetPos( Att.Pos )
		ent:SetAngles( self:LocalToWorldAngles( Angle(0,data.ang,0) ) )
		ent:Spawn()
		ent:Activate()
		ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
		ent:SetBase( self )
		self:DeleteOnRemove( ent )
		self:TransferCPPI( ent )
		ent.DoNotDuplicate = true

		self.Constrainer[ Index ] = ent

		local Lock = 40
		constraint.Axis( ent, self, 0, 0, Vector(0,0,0), self:WorldToLocal( ent:GetPos() ), 0, 0, 0, 0, Vector(0,0,1) ).DoNotDuplicate = true
		constraint.AdvBallsocket(ent, self, 0, 0, Vector(0,0,0), Vector(0,0,0), 0, 0, -Lock, -Lock, -Lock, Lock, Lock, Lock, 0, 0, 0, 0, 1).DoNotDuplicate = true
		
		for id, legdata in ipairs( LegSegments ) do
			local legent = ents.Create( "lvs_walker_atte_component" )
			legent:SetModel( legdata.mdl )
			legent:SetPos( ent:LocalToWorld( legdata.pos ) )
			legent:SetAngles( ent:LocalToWorldAngles( legdata.ang ) )
			legent:Spawn()
			legent:Activate()
			legent:SetCollisionGroup( COLLISION_GROUP_WORLD )
			legent:SetBase( self )
			self:DeleteOnRemove( legent )
			self:TransferCPPI( legent )
			legent.DoNotDuplicate = true

			Index = Index + 1

			self.Constrainer[ Index ] = legent

			if id == 1 then
				-- Pivot at the knee: legent was spawned at ent:LocalToWorld(legdata.pos),
				-- so legent's origin IS the knee. Use that as the pivot on both sides.
				local kneeLocal = ent:WorldToLocal( legent:GetPos() )
				constraint.AdvBallsocket(ent, legent, 0, 0, kneeLocal, Vector(0,0,0), 0, 0, -Lock, -Lock, -Lock, Lock, Lock, Lock, math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), 0, 1).DoNotDuplicate = true
			end
			--[[
			if id == 2 then
				local AttID = ent:LookupAttachment( "upper" )
				local AttData = ent:GetAttachment( AttID )
				if AttData then
					constraint.AdvBallsocket(ent, legent, 0, 0, ent:WorldToLocal( AttData.Pos ), legent:WorldToLocal( AttData.Pos ), 0, 0, -Lock, -Lock, -Lock, Lock, Lock, Lock, math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), 0, 1).DoNotDuplicate = true
				end
			end

			if id == 3 then
				local lower = self.Constrainer[ Index - 2 ]
				local upper = self.Constrainer[ Index - 1 ]

				if not IsValid( lower ) or not IsValid( upper ) then continue end

				local ID1 = legent:LookupAttachment( "upper_end" )
				local Att1 = legent:GetAttachment( ID1 )

				local ID2 = legent:LookupAttachment( "lower_end" )
				local Att2 = legent:GetAttachment( ID2 )

				if Att1 then
					constraint.AdvBallsocket(legent, upper, 0, 0, legent:WorldToLocal( Att1.Pos ), upper:WorldToLocal( Att1.Pos ), 0, 0, -Lock, -Lock, -Lock, Lock, Lock, Lock, math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), 0, 1).DoNotDuplicate = true
				end
				if Att2 then
					constraint.AdvBallsocket(legent, lower, 0, 0, legent:WorldToLocal( Att2.Pos ), lower:WorldToLocal( Att2.Pos ), 0, 0, -Lock, -Lock, -Lock, Lock, Lock, Lock, math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), 0, 1).DoNotDuplicate = true
				end
			end

			if id == 4 then
				local shaft = self.Constrainer[ Index - 1 ]

				if not IsValid( shaft ) then continue end

				constraint.AdvBallsocket(legent, shaft, 0, 0, Vector(0,0,0), shaft:WorldToLocal( legent:GetPos() ), 0, 0, -Lock, -Lock, -Lock, Lock, Lock, Lock, math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), math.Rand(-Fric,Fric), 0, 1).DoNotDuplicate = true
			end --]]
			
			
		end
	end 


	self:ForceMotion()
end

function ENT:NudgeRagdoll()
	if not istable( self.Constrainer ) then return end

	for _, ent in pairs( self.Constrainer ) do
		if not IsValid( ent ) or ent == self then continue end

		local PhysObj = ent:GetPhysicsObject()

		if not IsValid( PhysObj ) then continue end

		PhysObj:EnableMotion( false )

		ent:SetPos( ent:GetPos() + self:GetUp() * 100 )

		timer.Simple( FrameTime() * 2, function()
			if not IsValid( ent ) then return end

			local PhysObj = ent:GetPhysicsObject()
			if IsValid( PhysObj ) then
				PhysObj:EnableMotion( true )
			end
		end)
	end
end

function ENT:ForceMotion()
	local phys = self:GetPhysicsObject()

	if not IsValid( phys ) then return end

	if not phys:IsMotionEnabled() then
		phys:EnableMotion( true )
	end
end
