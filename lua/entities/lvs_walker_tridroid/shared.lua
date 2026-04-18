ENT.Base = "lvs_walker_atte_hoverscript"

ENT.PrintName = "Octuptarra Tri-Droid"
ENT.Author = "Cards"
ENT.Information = "Octuptarra Separatist Walker Droid"
ENT.Category = "[LVS] - Star Wars"

ENT.VehicleCategory = "Star Wars"
ENT.VehicleSubCategory = "Walkers"

ENT.Spawnable		= true
ENT.AdminSpawnable	= false


ENT.MDL = "models/tridroid/CIS_Tridroid.mdl"
ENT.GibModels = {
	"models/tridroid/CIS_Tridroid_gib1.mdl",
	"models/tridroid/CIS_Tridroid_gib2.mdl",
	"models/tridroid/CIS_Tridroid_gib3.mdl",
	"models/tridroid/CIS_Tridroid_gib4.mdl",
	"models/tridroid/CIS_Tridroid_gib5.mdl",
}

ENT.AITEAM = 1

-- TODO: tune health for balance
ENT.MaxHealth = 5000

ENT.ForceLinearMultiplier = 1
ENT.ForceAngleMultiplier = 1
ENT.ForceAngleDampingMultiplier = 1

-- TODO: tune hover parameters once model is in
ENT.HoverHeight = 150
ENT.HoverTraceLength = 1500
ENT.HoverHullRadius = 50

ENT.TurretTurnRate = 100

ENT.CanMoveOn = {
	["func_door"] = true,
	["func_movelinear"] = true,
	["prop_physics"] = true,
}

ENT.lvsShowInSpawner = true

function ENT:OnSetupDataTables()
	self:AddDT( "Int", "UpdateLeg" )
	self:AddDT( "Bool", "IsRagdoll" )
	self:AddDT( "Bool", "IsMoving" )
	self:AddDT( "Bool", "NWGround" )
	self:AddDT( "Vector", "AIAimVector" )
end

function ENT:GetEyeTrace()
	local startpos = self:GetPos()

	local pod = self:GetDriverSeat()

	if IsValid( pod ) then
		-- TODO: adjust local offset to match model eye position
		startpos = pod:LocalToWorld( Vector(0,0,33) )
	end

	local trace = util.TraceLine( {
		start = startpos,
		endpos = (startpos + self:GetAimVector() * 50000),
		filter = self:GetCrosshairFilterEnts()
	} )

	return trace
end

function ENT:GetAimVector()
	if self:GetAI() then
		return self:GetAIAimVector()
	end

	local Driver = self:GetDriver()

	if IsValid( Driver ) then
		return Driver:GetAimVector()
	else
		return self:GetForward()
	end
end

function ENT:HitGround()
	return self:GetNWGround()
end
