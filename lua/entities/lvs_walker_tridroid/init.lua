AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_camera.lua" )
AddCSLuaFile( "cl_prediction.lua" )
AddCSLuaFile( "sh_weapons.lua" )
include("shared.lua")
include("sv_contraption.lua")
include("sv_controls.lua")
include("sv_ragdoll.lua")
include("sv_ai.lua")
include("sh_weapons.lua")

ENT.SpawnNormalOffset = 200
ENT.SpawnNormalOffsetSpawner = 250

function ENT:OnSpawn( PObj )
	PObj:SetMass( 4000 )
	self._SpawnTime = CurTime()

	-- TODO: adjust seat position to match model
	local DriverSeat = self:AddDriverSeat( Vector(0,0,265), Angle(0,-90,0) )
	DriverSeat.HidePlayer = true

	-- 3 legs at 120 degree intervals
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

	for _, data in ipairs( Legs ) do
		local ID = self:LookupAttachment( data.name )
		local Att = self:GetAttachment( ID )

		if not Att then self:Remove() return end

		local Leg = ents.Create( "lvs_walker_tridroid_leg" )
		Leg:SetPos( Att.Pos )
		Leg:SetAngles( self:LocalToWorldAngles( Angle(0,data.ang,0) ) )
		Leg:Spawn()
		Leg:Activate()
		Leg:SetParent( self, ID )
		Leg:SetBase( self )
		Leg:SetLocationIndex( data.id )
	end

	-- TODO: adjust armor positions/sizes to match model
	self:AddArmor( Vector(0,0,215), Angle(0,0,0), Vector(-60,-60,-70), Vector(60,60,50), 600, 4000 )

	-- TODO: adjust weak point positions to match model
	self:AddDS( {
		pos = Vector(0,0,600),
		ang = Angle(0,0,0),
		mins = Vector(-20,-20,-20),
		maxs = Vector(20,20,20),
		Callback = function( tbl, ent, dmginfo )
			if dmginfo:GetDamage() <= 0 then return end

			dmginfo:ScaleDamage( 2 )

			if ent:GetHP() > 1500 or ent:GetIsRagdoll() then return end

			ent:BecomeRagdoll()

			local effectdata = EffectData()
				effectdata:SetOrigin( ent:LocalToWorld( Vector(0,0,250) ) )
			util.Effect( "lvs_explosion_nodebris", effectdata )
		end
	} )

	local ID = self:LookupAttachment( "muzzle" )
	local Muzzle = self:GetAttachment( ID )
	self.SNDTurret = self:AddSoundEmitter( self:WorldToLocal( Muzzle.Pos ), "lvs/vehicles/hsd/fire.mp3", "lvs/vehicles/hsd/fire.mp3" )
	self.SNDTurret:SetSoundLevel( 110 )
	self.SNDTurret:SetParent( self, ID )
end

function ENT:OnTick()
	self:ContraptionThink()
end

function ENT:OnMaintenance()
	self:UnRagdoll()
end

function ENT:AlignView( ply, SetZero )
	if not IsValid( ply ) then return end

	timer.Simple( 0, function()
		if not IsValid( ply ) or not IsValid( self ) then return end

		ply:SetEyeAngles( Angle(0,90,0) )
	end)
end

