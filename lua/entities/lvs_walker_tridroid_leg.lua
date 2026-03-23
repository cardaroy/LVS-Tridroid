AddCSLuaFile()

ENT.Type            = "anim"

function ENT:SetupDataTables()
	self:NetworkVar( "Entity",0, "Base" )
	self:NetworkVar( "String",0, "LocationIndex" )
end

if SERVER then
	function ENT:Initialize()
		-- TODO: set actual upper leg model
		self:SetModel( "models/tridroid/CIS_Tridroid_upperleg.mdl" )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
	end

	function ENT:Think()
		return false
	end
else
	-- Lower leg model
	ENT.LowerLegModel = "models/tridroid/CIS_Tridroid_lowerleg.mdl"

	-- Local offset from upper leg origin to knee pivot point
	-- This is where the lower leg attaches to the upper leg
	ENT.KneeOffset = Vector(230, 0, 230)

	-- Angle offset to align the lower leg model with the facing direction
	ENT.LowerAngOffset = Angle(-30, 0, 0)

	-- Local position offset applied in the lower leg's own space to align the mesh with the knee
	-- Tweak X/Y/Z here to slide the mesh so it connects at the yellow cross
	ENT.LowerPosOffset = Vector(0, 0, 0)

	-- Offset applied to the foot landing target (ENDPOS) in the body's local space
	-- Shifts the invisible foot target so the IK angles line up between upper and lower leg
	-- X = forward/back, Y = left/right, Z = up/down
	ENT.FootOffset = Vector(0, 0, 0)

	-- 3 legs at 120 degree intervals
	-- TODO: adjust positions to match model attachment spread
	ENT.StartPositions = {
		["F"]  = Vector(0, -200, 45),
		["RL"] = Vector(-173, 100, 45),
		["RR"] = Vector(173, 100, 45),
	}

	-- Maps UpdateLeg network index to location ID
	ENT.LocToID = {
		[1] = "RR",
		[2] = "F",
		[3] = "RL",
	}

	function ENT:Think()
		local Base = self:GetBase()

		if not IsValid( Base ) then return end

		if Base:GetIsRagdoll() then
			local EntTable = self:GetTable()
			if IsValid( EntTable._LowerLeg ) then
				EntTable._LowerLeg:Remove()
			end

			return
		end

		local EntTable = self:GetTable()
		local LocIndex = self:GetLocationIndex()

		if not Base:HitGround() then
			local Pos = Base:LocalToWorld( EntTable.StartPositions[ LocIndex ] ) + Base:LocalToWorld( EntTable.FootOffset ) - Base:GetPos()

			self:RunIK( Pos, Base )
			EntTable._OldPos = Pos
			EntTable._smPos = Pos

			return
		end

		local Up = Base:GetUp()
		local Forward = Base:GetForward()
		local Vel = Base:GetVelocity()

		local Speed = Vel:Length()
		local VelForwardMul = math.min( Speed / 100, 1 )
		local VelForward = Vel:GetNormalized() * VelForwardMul + Forward * (1 - VelForwardMul)

		local TraceStart = Base:LocalToWorld( EntTable.StartPositions[ LocIndex ] ) + VelForward * math.Clamp( 400 - Speed * 2, 100, 200 ) * VelForwardMul

		local trace = util.TraceLine( {
			start = TraceStart + Vector(0,0,200),
			endpos = TraceStart - Vector(0,0,300) + (TraceStart - Base:GetPos()):GetNormalized() * 200,
			filter = function( ent )
				if ent == Base or Base.HoverCollisionFilter[ ent:GetCollisionGroup() ] then return false end

				return true
			end,
		} )

		local UpdateLeg = EntTable.LocToID[ Base:GetUpdateLeg() ] == LocIndex

		EntTable._OldPos = EntTable._OldPos or trace.HitPos
		EntTable._smPos = EntTable._smPos or EntTable._OldPos

		if EntTable._OldUpdateLeg ~= UpdateLeg then
			EntTable._OldUpdateLeg = UpdateLeg

			if UpdateLeg then
				EntTable.UpdateNow = true
			end
		end

		if EntTable.UpdateNow and not EntTable.MoveLeg then
			-- Don't move the leg if the new target is very close to where it already is
			if EntTable._smPos:DistToSqr( trace.HitPos ) < 900 then
				EntTable.UpdateNow = nil
				return
			end

			-- TODO: set actual tridroid hydraulic sounds
			sound.Play( Sound( "lvs/vehicles/hsd/hydraulic_stop0"..math.random(1,2)..".wav" ), self:GetPos(), SNDLVL_100dB )

			EntTable.UpdateNow = nil
			EntTable.MoveLeg = true
			EntTable.MoveDelta = 0
		end

		local ShaftOffset = 0
		local ENDPOS = EntTable._smPos + Up * 20

		if EntTable.MoveLeg then
			local traceWater = util.TraceLine( {
				start = TraceStart + Vector(0,0,200),
				endpos = ENDPOS,
				filter = Base:GetCrosshairFilterEnts(),
				mask = MASK_WATER,
			} )

			if traceWater.Hit then
				local T = CurTime()

				if (EntTable._NextFX or 0) < T then
					EntTable._NextFX = T + 0.05

					local effectdata = EffectData()
						effectdata:SetOrigin( traceWater.HitPos )
						effectdata:SetEntity( Base )
						effectdata:SetMagnitude( 50 )
					util.Effect( "lvs_hover_water", effectdata )
				end
			end

			if EntTable.MoveDelta >= 1 then
				EntTable.MoveLeg = false
				EntTable.MoveDelta = nil

				-- TODO: set actual tridroid footstep sounds
				sound.Play( Sound( "lvs/vehicles/hsd/footstep0"..math.random(1,3)..".wav" ), ENDPOS, SNDLVL_100dB )

				local effectdata = EffectData()
					effectdata:SetOrigin( trace.HitPos )
				util.Effect( "lvs_walker_stomp", effectdata )

				sound.Play( Sound( "lvs/vehicles/hsd/hydraulic_start0"..math.random(1,2)..".wav" ), self:GetPos(), SNDLVL_100dB )
			else
				EntTable.MoveDelta = math.min( EntTable.MoveDelta + RealFrameTime() * 2, 1 )

				EntTable._smPos = LerpVector( EntTable.MoveDelta, EntTable._OldPos, trace.HitPos )

				local MulZ = math.max( math.sin( EntTable.MoveDelta * math.pi ), 0 )

				ShaftOffset = MulZ ^ 2 * 30
				ENDPOS = ENDPOS + Up * MulZ * 50
			end
		else
			EntTable._OldPos = EntTable._smPos
		end

		-- Apply foot offset in body-local space to shift the IK target
		ENDPOS = ENDPOS + Base:LocalToWorld( EntTable.FootOffset ) - Base:GetPos()

		self:RunIK( ENDPOS, Base, ShaftOffset )
	end

	function ENT:RunIK( ENDPOS, Base, shaftoffset )
		local EntTable = self:GetTable()

		-- Upper leg: pivot at root, face toward foot (yaw only) - same as before, this works
		local Ang = Base:WorldToLocalAngles( (ENDPOS - self:GetPos()):Angle() )
		self:SetAngles( Base:LocalToWorldAngles( Angle(0,Ang.y,0) ) )

		-- Get the knee position (tip of upper leg)
		local KneePos = self:LocalToWorld( EntTable.KneeOffset )

		-- Create the lower leg prop if it doesn't exist yet
		if not IsValid( EntTable._LowerLeg ) then
			local prop = ents.CreateClientProp()
			prop:SetModel( EntTable.LowerLegModel )
			prop:Spawn()
			EntTable._LowerLeg = prop
		end

		-- Lower leg: pivot at knee, face toward foot - same approach as upper leg
		local LowerAng = (ENDPOS-KneePos):Angle() + EntTable.LowerAngOffset
		local upperYaw = self:GetAngles().y
		local LowerAng = Angle(LowerAng.p, upperYaw, LowerAng.r) + EntTable.LowerAngOffset
		EntTable._LowerLeg:SetAngles( LowerAng )
		-- Apply local position offset (in the lower leg's rotated space) to align mesh with knee
		local offsetPos = KneePos + LowerAng:Forward() * EntTable.LowerPosOffset.x + LowerAng:Right() * EntTable.LowerPosOffset.y + LowerAng:Up() * EntTable.LowerPosOffset.z
		EntTable._LowerLeg:SetPos( offsetPos )

		-- Store debug positions for Draw()
		EntTable._dbgHip = self:GetPos()
		EntTable._dbgKnee = KneePos
		EntTable._dbgFoot = ENDPOS
	end

	function ENT:OnRemove()
		local EntTable = self:GetTable()
		if IsValid( EntTable._LowerLeg ) then
			EntTable._LowerLeg:Remove()
		end
	end

	function ENT:Draw()
		local Base = self:GetBase()

		if not IsValid( Base ) then return end

		if Base:GetIsRagdoll() then return end

		self:DrawModel()

		local EntTable = self:GetTable()
		local LocIndex = self:GetLocationIndex()

		--[[ Debug: draw IK skeleton + joint markers
		local hip = EntTable._dbgHip
		local knee = EntTable._dbgKnee
		local foot = EntTable._dbgFoot

		local HoverHeight = 350
		if hip and knee and foot then
			cam.Start3D()
				-- Local axes at hip: RED=X(forward), GREEN=Y(right), BLUE=Z(up)
				local axLen = 50
				local fwd = self:GetForward() * axLen
				local rgt = self:GetRight() * axLen
				local up = self:GetUp() * axLen
				render.DrawLine( hip, hip + fwd, Color(255,0,0), true )   -- X = red
				render.DrawLine( hip, hip + rgt, Color(0,255,0), true )   -- Y = green
				render.DrawLine( hip, hip + up, Color(0,100,255), true )  -- Z = blue

				-- Upper leg: hip to knee (white)
				render.DrawLine( hip, knee, Color(255,255,255), true )
				-- Lower leg: knee to foot (cyan)
				render.DrawLine( knee, foot, Color(0,255,255), true )

				-- Joint markers (small crosshairs)
				local sz = 7
				-- Hip = red
				render.DrawLine( hip - Vector(sz,0,0) + Vector(0,0,HoverHeight), hip + Vector(sz,0,0) + Vector(0,0,HoverHeight), Color(255,0,0), true )
				render.DrawLine( hip - Vector(0,sz,0) + Vector(0,0,HoverHeight), hip + Vector(0,sz,0) + Vector(0,0,HoverHeight), Color(255,0,0), true )
				render.DrawLine( hip - Vector(0,0,sz) + Vector(0,0,HoverHeight), hip + Vector(0,0,sz) + Vector(0,0,HoverHeight), Color(255,0,0), true )
				-- Knee = yellow
				render.DrawLine( knee - Vector(sz,0,0), knee + Vector(sz,0,0), Color(255,255,0), true )
				render.DrawLine( knee - Vector(0,sz,0), knee + Vector(0,sz,0), Color(255,255,0), true )
				render.DrawLine( knee - Vector(0,0,sz), knee + Vector(0,0,sz), Color(255,255,0), true )
				-- Foot = magenta
			--	render.DrawLine( foot - Vector(sz,0,0), foot + Vector(sz,0,0), Color(255,0,255), true )
			--	render.DrawLine( foot - Vector(0,sz,0), foot + Vector(0,sz,0), Color(255,0,255), true )
			--	render.DrawLine( foot - Vector(0,0,sz), foot + Vector(0,0,sz), Color(255,0,255), true )
			cam.End3D()
		end
		--[[
		if not EntTable._dbgBounds then
			EntTable._dbgBounds = true
			local mins, maxs = self:GetModelRenderBounds()
			print("[LVS Tridroid] Upper leg render bounds - mins: " .. tostring(mins) .. " maxs: " .. tostring(maxs))
			print("[LVS Tridroid] Try KneeOffset near the max extent of the upper leg model")
		end

		local mins, maxs = self:GetModelRenderBounds()
		--
		cam.Start3D()
			-- GREEN cross = upper leg origin (hip pivot)
			local big = 20
			render.DrawLine( origin - Vector(big,0,0), origin + Vector(big,0,0), Color(0,255,0), true )
			render.DrawLine( origin - Vector(0,big,0), origin + Vector(0,big,0), Color(0,255,0), true )
			render.DrawLine( origin - Vector(0,0,big), origin + Vector(0,0,big), Color(0,255,0), true )

			-- YELLOW wireframe = upper leg model bounds (find the tip)
			render.DrawWireframeBox( origin, self:GetAngles(), mins, maxs, Color(255,255,0), true )

			-- CYAN crosses = all 8 corners of the upper leg bounds (one of these is near the knee tip)
			local corners = {
				Vector(mins.x, mins.y, mins.z),
				Vector(mins.x, mins.y, maxs.z),
				Vector(mins.x, maxs.y, mins.z),
				Vector(mins.x, maxs.y, maxs.z),
				Vector(maxs.x, mins.y, mins.z),
				Vector(maxs.x, mins.y, maxs.z),
				Vector(maxs.x, maxs.y, mins.z),
				Vector(maxs.x, maxs.y, maxs.z),
			}
			for _, c in ipairs(corners) do
				local wp = self:LocalToWorld(c)
				render.DrawLine( wp - Vector(5,0,0), wp + Vector(5,0,0), Color(0,255,255), true )
				render.DrawLine( wp - Vector(0,5,0), wp + Vector(0,5,0), Color(0,255,255), true )
				render.DrawLine( wp - Vector(0,0,5), wp + Vector(0,0,5), Color(0,255,255), true )
			end

			-- RED cross = lower leg model origin
			if IsValid( EntTable._LowerLeg ) then
				local o = EntTable._LowerLeg:GetPos()
				render.DrawLine( o - Vector(big,0,0), o + Vector(big,0,0), Color(255,0,0), true )
				render.DrawLine( o - Vector(0,big,0), o + Vector(0,big,0), Color(255,0,0), true )
				render.DrawLine( o - Vector(0,0,big), o + Vector(0,0,big), Color(255,0,0), true )
			end
		cam.End3D()

		-- Label
		local LocIndex = self:GetLocationIndex()
		local pos = origin + Vector(0,0,50)
		cam.Start3D2D( pos, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.5 )
			draw.SimpleTextOutlined( LocIndex or "?", "DermaLarge", 0, 0, Color(255,255,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0,0,0) )
		cam.End3D2D()
		--]]
	end
end
