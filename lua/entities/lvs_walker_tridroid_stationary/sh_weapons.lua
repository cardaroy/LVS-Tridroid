-- TODO: adjust turret height offset to match model

function ENT:WeaponsInRange()
	local Forward = self:GetForward()
	local AimForward = self:GetAimVector()

	-- Check pitch: don't fire if aiming more than 45 degrees up or down
	local pitch = self:WorldToLocalAngles( AimForward:Angle() ).p
	if pitch > 30 or pitch < -30 then return false end

	return self:AngleBetweenNormal( Forward, AimForward ) < 180
end

function ENT:StopTurret()
	-- placeholder for any continuous-fire weapon shutdown
end

function ENT:InitWeapons()
	-- TODO: define actual weapons based on the tri-droid's armament
	-- The Octuptarra typically has rotating laser cannons on its head

	local weapon = {}
	weapon.Icon = Material("lvs/weapons/hmg.png")
	weapon.Ammo = 100
	weapon.Delay = 2
	weapon.HeatRateUp = 0.1
	weapon.HeatRateDown = 0.5
	weapon.OnOverheat = function( ent )
		timer.Simple( 0.4, function()
			if not IsValid( ent ) then return end

			ent:EmitSound("lvs/overheat.wav")
		end )
	end
	weapon.Attack = function( ent )
		if not ent:WeaponsInRange() then return true end

		-- TODO: adjust muzzle attachment name to match model
		local ID = ent:LookupAttachment( "muzzle" )
		local Muzzle = ent:GetAttachment( ID )

		if not Muzzle then return end

		local bullet = {}
		bullet.Src 	= Muzzle.Pos
		bullet.Dir 	= ent:WeaponsInRange() and (ent:GetEyeTrace().HitPos - Muzzle.Pos):GetNormalized() or -Muzzle.Ang:Right()
		bullet.Spread 	= Vector(0,0,0)
		bullet.TracerName = "lvs_laser_red_aat"
		bullet.Force	= 15000
		bullet.HullSize 	= 1
		bullet.Damage	= 150
		bullet.SplashDamage = 200
		bullet.SplashDamageRadius = 1500
		bullet.Velocity = 10000
		bullet.Attacker 	= ent:GetDriver()
		bullet.Callback = function(att, tr, dmginfo)
			local effectdata = EffectData()
				effectdata:SetOrigin( tr.HitPos )
			util.Effect( "lvs_laser_explosion_aat", effectdata )
		end
		ent:LVSFireBullet( bullet )

		local effectdata = EffectData()
		effectdata:SetStart( Vector(255,50,50) )
		effectdata:SetOrigin( bullet.Src )
		effectdata:SetNormal( Muzzle.Ang:Up() )
		effectdata:SetEntity( ent )
		util.Effect( "lvs_muzzle_colorable", effectdata )

		ent:TakeAmmo()

		-- Cycle gun index 0->1->2->0 and network it so client can rotate the head
		local idx = (ent:GetNWInt("GunIndex", 0) + 1) % 3
		ent:SetNWInt("GunIndex", idx)

		if not IsValid( ent.SNDTurret ) then return end

		ent.SNDTurret:PlayOnce( 100 + math.cos( CurTime() + ent:EntIndex() * 1337 ) * 5 + math.Rand(-1,1), 1 )
	end
	weapon.OnThink = function( ent, active )
		ent:AimTurret()
	end
	self:AddWeapon( weapon )
end

function ENT:ThinkWeapons()
	-- placeholder for any continuous weapon logic, such as heat management or auto-reload
end

function ENT:AimTurret()
    if CLIENT then
        self:CalcHeadAim()
    end
end
