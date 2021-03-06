-- Combat & Stacking Overhaul Functions
-- Author: Gedemon
-- DateCreated: 7/31/2013 10:29 PM
--------------------------------------------------------------

print("Loading Combat & Stacking Overhaul Functions...")
print("-------------------------------------")


--------------------------------------------------------------
-- Globals
--------------------------------------------------------------
g_DebugCombat = true
g_StartNum = 0
g_EndNum = 0
g_NavalCounterAttack = {}
g_ArtilleryCounterFire = {}
g_OffensiveFirstStrike = {}
g_DefensiveFirstStrike = {}

function SetStartCombatNum()
	local savedData = Modding.OpenSaveData()
	g_StartNum = savedData.GetValue("StartCombatNum") or 0
	g_StartNum = g_StartNum + 1
	savedData.SetValue("StartCombatNum", g_StartNum)
end
function SetEndCombatNum()
	local savedData = Modding.OpenSaveData()
	g_EndNum = savedData.GetValue("EndCombatNum") or 0
	g_EndNum = g_EndNum + 1
	savedData.SetValue("EndCombatNum", g_EndNum)
end


function ResetCombatTracking()
	g_NavalCounterAttack = {}
	g_ArtilleryCounterFire = {}
	g_OffensiveFirstStrike = {}
	g_DefensiveFirstStrike = {}
end

--------------------------------------------------------------
-- Combat Results
--------------------------------------------------------------

function CombatResult (iAttackingPlayer, iAttackingUnit, attackerDamage, attackerFinalDamage, attackerMaxHP, iDefendingPlayer, iDefendingUnit, defenderDamage, defenderFinalDamage, defenderMaxHP, iInterceptingPlayer, iInterceptingUnit, interceptorDamage, plotX, plotY)

	local pAttackingPlayer = Players[ iAttackingPlayer ]
	if pAttackingPlayer then -- In case the combat was aborted...
		
		SetStartCombatNum()
		local turn = Game.GetGameTurn()
		Dprint("")
		Dprint("------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------", g_DebugCombat)
		Dprint("COMBAT Started #".. tostring(g_StartNum), g_DebugCombat)
		Dprint("------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------", g_DebugCombat)

		local pAttackingUnit = pAttackingPlayer:GetUnitByID( iAttackingUnit );		
		Dprint ("Attacking from plot at " .. pAttackingUnit:GetPlot():GetX() .. "," ..pAttackingUnit:GetPlot():GetY(), g_DebugCombat)
		Dprint ("Attacker is " .. tostring(pAttackingUnit:GetName()) .. ", Current Damage = " .. tostring(pAttackingUnit:GetDamage()), g_DebugCombat)

		local pDefendedPlot = GetPlot(plotX, plotY)
		local pDefendingCity
		local defendingPlotKey
		if pDefendedPlot then
			Dprint ("Defending plot at " .. pDefendedPlot:GetX() .. "," ..pDefendedPlot:GetY(), g_DebugCombat)
			pDefendingCity = pDefendedPlot:GetPlotCity()
			defendingPlotKey = GetPlotKey(pDefendedPlot)
		end

		local attackingPlayerName = pAttackingPlayer:GetCivilizationShortDescription()
		local attackingUnitName = pAttackingUnit:GetName() or iAttackingUnit	

		local pDefendingPlayer = Players[iDefendingPlayer]
		local pDefendingUnit = pDefendingPlayer:GetUnitByID( iDefendingUnit )

		local defendingPlayerName = pDefendingPlayer:GetCivilizationShortDescription()
		local defendingUnitName

		local defenderHealth = defenderMaxHP - defenderFinalDamage

		if pDefendingUnit then
			defendingUnitName = pDefendingUnit:GetName() or iDefendingUnit
			Dprint ("Defender is unit : " .. tostring(defendingUnitName).. ", Current Damage = " .. tostring(pDefendingUnit:GetDamage()), g_DebugCombat)

		elseif pDefendingCity then
			defendingUnitName = pDefendingCity:GetName()
			Dprint ("Defender is city of " .. tostring(defendingUnitName), g_DebugCombat)

			-- Check if units need to escape the city
			local bEscapeCity = false
			if defenderHealth <= MIN_HP_LEFT_BEFORE_ESCAPING_CITY and not pAttackingUnit:IsRanged() then
				bEscapeCity = true
			end
			local unitCount = pDefendedPlot:GetNumUnits()
			if unitCount > 0 then 
				Dprint ("List of units in the city : ", bDebug)
			end
			for i = 0, unitCount - 1, 1 do	
    			local testUnit = pDefendedPlot:GetUnit(i)
				if testUnit then
					Dprint("   - unit num" .. i+1 .. " : " .. testUnit:GetName(), bDebug)
				end
			end
			if bEscapeCity then
				--EscapeUnitsFromPlot(pDefendedPlot, true, 0, iAttackingPlayer)
			end
		end
		
		local pInterceptingPlayer = Players[iInterceptingPlayer]
		local pInterceptingUnit 
		local interceptingUnitName

		if pInterceptingPlayer then
			Dprint ("Found intercepting player: ".. tostring(pInterceptingPlayer:GetName()), g_DebugCombat)
			pInterceptingUnit = pInterceptingPlayer:GetUnitByID( iInterceptingUnit )
			if pInterceptingUnit then
				interceptingUnitName = pInterceptingUnit:GetName() or pInterceptingUnit:GetID()
				Dprint ("Selected Interceptor is ".. tostring(interceptingUnitName), g_DebugCombat)
			end
		end

		-- determine combat type

		local combatType = MELEE -- default type

		if pAttackingUnit:GetDomainType() == DomainTypes.DOMAIN_AIR then
			if pDefendingUnit and pDefendingUnit:GetDomainType() == DomainTypes.DOMAIN_AIR then -- dogfight !
				Dprint ("Attack type : Dogfight", g_DebugCombat)
				combatType = DOGFIGHT
			elseif pInterceptingUnit then
				if pInterceptingUnit:GetDomainType() == DomainTypes.DOMAIN_AIR then
					combatType = INTERCEPT
				else
					combatType = GRDINTERCEPT
				end
			elseif pDefendingCity then
				combatType = CITYBOMB			
			else			
				combatType = AIRBOMB
			end

		elseif pAttackingUnit:IsHasPromotion( GameInfo.UnitPromotions.PROMOTION_INVISIBLE_SUBMARINE.ID ) then
			Dprint ("Attack type : From Submarine", g_DebugCombat)
			combatType = SUBATTACK

		elseif pDefendingUnit and pDefendingUnit:IsHasPromotion( GameInfo.UnitPromotions.PROMOTION_INVISIBLE_SUBMARINE.ID ) then
			Dprint ("Attack type : Hunting Submarine", g_DebugCombat)
			combatType = SUBHUNT

		elseif pAttackingUnit:IsRanged() and (pAttackingUnit:GetDomainType() ~= DomainTypes.DOMAIN_AIR) and not (pAttackingUnit:IsHasPromotion( GameInfo.UnitPromotions.PROMOTION_INVISIBLE_SUBMARINE.ID )) then		
			Dprint ("Attack type : Ranged", g_DebugCombat)
			combatType = RANGED
		end
		
		-- value for combat logging		
		local AttackerUniqueID, DefenderUniqueID, InterceptorUniqueID, AttackerToDefender, AttackerToInterceptor, DefenderToAttacker, InterceptorToAttacker, AttackerXP, DefenderXP, InterceptorXP
		local AttackerPlayerID, DefenderPlayerID, InterceptorPlayerID, AttackerCivType, DefenderCivType, InterceptorCivType, AttackerUnitType, DefenderUnitType, InterceptorUnitType

		local bCity = ( pDefendingCity ~= nil )
		
		--[[
		AttackerUnitKey = GetUnitKey(pAttackingUnit)
		AttackerUniqueID = g_UnitData[AttackerUnitKey].UniqueID
		AttackerPlayerID = iAttackingPlayer
		AttackerCivType = GetCivTypeFromPlayerID(iAttackingPlayer)
		AttackerUnitType = GameInfo.Units[pAttackingUnit:GetUnitType()].Type
		
		DefenderPlayerID = iDefendingPlayer
		DefenderCivType = GetCivTypeFromPlayerID(iDefendingPlayer)
		
		if pDefendingUnit then
			DefenderUnitKey = GetUnitKey(pDefendingUnit)
			DefenderUniqueID = g_UnitData[DefenderUnitKey].UniqueID
			DefenderUnitType = GameInfo.Units[pDefendingUnit:GetUnitType()].Type
		end

		if pInterceptingUnit then
			InterceptorUnitKey = GetUnitKey(pInterceptingUnit)
			InterceptorUniqueID = g_UnitData[InterceptorUnitKey].UniqueID
			InterceptorPlayerID = iInterceptingPlayer
			InterceptorCivType = GetCivTypeFromPlayerID(InterceptorPlayerID)
			InterceptorUnitType = GameInfo.Units[pInterceptingUnit:GetUnitType()].Type
			InterceptorToAttacker = interceptorDamage
		end
		--]]

		AttackerToDefender = defenderDamage
		DefenderToAttacker = attackerDamage
		
		-- display combat result
		Dprint("---------------------------------------------------------------------------------------------------------------", g_DebugCombat)
		Dprint ("Combat Started:		" .. Locale.ToUpper(attackingPlayerName) .."		attack			".. Locale.ToUpper(defendingPlayerName), g_DebugCombat);
		Dprint("---------------------------------------------------------------------------------------------------------------", g_DebugCombat)
		Dprint ("Attacking Unit:		" .. attackingUnitName, g_DebugCombat);
		Dprint ("Defending Unit:							".. defendingUnitName, g_DebugCombat);
		-- if interception was made
		if pInterceptingUnit then
			Dprint ("Intercepting Unit:						".. interceptingUnitName, g_DebugCombat);
			Dprint ("From Interceptor:		".. interceptorDamage, g_DebugCombat);
			Dprint ("From Opponent:		".. attackerDamage .."					".. defenderDamage, g_DebugCombat);
		else	
			Dprint ("Receveid Damage:		".. attackerDamage .."					".. defenderDamage, g_DebugCombat);
		end
		Dprint ("Final Damage:		".. attackerFinalDamage .."					"..  defenderFinalDamage, g_DebugCombat);
		if pAttackingUnit:IsRanged() and pAttackingUnit:GetDomainType() ~= DomainTypes.DOMAIN_AIR then -- fix bad leftHP calculation for ranged unit
			Dprint ("HitPoints left:		".. attackerMaxHP - pAttackingUnit:GetDamage() .."					"..  defenderHealth, g_DebugCombat);
		else
			Dprint ("HitPoints left:		".. attackerMaxHP - attackerFinalDamage .."					"..  defenderHealth, g_DebugCombat);
		end
		-- retreat ?
		local bRetreat = false
		local diffDamage = defenderDamage - attackerDamage;
		-- note : aren't ranged units able to do melee attack ? we should test something else...
		if not pAttackingUnit:IsRanged() and pAttackingUnit:GetDomainType() ~= DomainTypes.DOMAIN_SEA then
			Dprint("-----------------", g_DebugCombat)

			Dprint (pAttackingUnit:GetName().. " has ".. pAttackingUnit:MovesLeft() .. " moves left.", g_DebugCombat)

			Dprint  ("diffDamage: " .. diffDamage, g_DebugCombat);
			if diffDamage > 0 then				
				local ratioHitPoint = defenderHealth / diffDamage;
				Dprint  ("ratioHitPoint: " .. ratioHitPoint, g_DebugCombat);
				if ratioHitPoint < 5 and defenderHealth > 0 then				
					if pDefendingUnit then -- cities can't retreat...
						--if not IsNeverRetreating(pDefendingUnit:GetUnitType()) then
							Dprint ("RETREAT !!!", g_DebugCombat);
							bRetreat = Retreat (iAttackingPlayer, iAttackingUnit, iDefendingPlayer, iDefendingUnit, defenderDamage);
						--else
						--	Dprint ("Retreat ? defender unit says : NEVER !!!", g_DebugCombat);
						--end
					end
				end
			end
		end

		-- give XP to interceptor
		if pInterceptingUnit and interceptorDamage > 0 then
			Dprint ("-----------------", g_DebugCombat)
			Dprint ("Give XP to " .. interceptingUnitName .. " for intercepting and dealed damage to " .. pAttackingUnit:GetName(), g_DebugCombat);
			pInterceptingUnit:ChangeExperience(EXPERIENCE_INTERCEPTING_UNIT_AIR)
			-- to do: add damage to interceptor ?
		end

		--[[
		-- update damage in unit table
		g_UnitData[AttackerUnitKey].Damage = attackerFinalDamage

		if pDefendingUnit then
			g_UnitData[DefenderUnitKey].Damage = defenderFinalDamage
		end

		--if pInterceptingUnit then
		--	g_UnitData[InterceptorUnitKey].Damage = attackerFinalDamage
		--end
	
		-- update combatXP for involved units
		AttackerXP = UpdateCombatXP(pAttackingUnit)
		if pDefendingUnit then DefenderXP = UpdateCombatXP(pDefendingUnit) end
		if pInterceptingUnit then InterceptorXP = UpdateCombatXP(pInterceptingUnit) end
		
		Dprint ("-----------------", g_DebugCombat)
		Dprint ("Updating Combat Log...", g_DebugCombat);
		table.insert(g_CombatsLog, {
			Turn = Game.GetGameTurn(), 
			PlotKey = defendingPlotKey,
			CombatType = combatType,
			DefenderIsCity = bCity,
			AttackerUniqueID = AttackerUniqueID,			-- uniqueID from g_UnitData
			DefenderUniqueID = DefenderUniqueID,
			InterceptorUniqueID = InterceptorUniqueID,
			AttackerToDefender = AttackerToDefender,
			AttackerToInterceptor = AttackerToInterceptor,
			DefenderToAttacker = DefenderToAttacker,
			InterceptorToAttacker = InterceptorToAttacker,
			AttackerXP = AttackerXP,
			DefenderXP = DefenderXP,
			InterceptorXP = InterceptorXP,
			AttackerPlayerID = AttackerPlayerID,
			DefenderPlayerID = DefenderPlayerID,
			InterceptorPlayerID = InterceptorPlayerID,
			AttackerCivType = AttackerCivType,			-- string
			DefenderCivType = DefenderCivType,
			InterceptorCivType = InterceptorCivType,
			AttackerUnitType = AttackerUnitType,			-- string
			DefenderUnitType = DefenderUnitType,
			InterceptorUnitType = InterceptorUnitType,
			Retreat = bRetreat,
		})

		local cityMaxDamage = math.floor(defenderMaxHP * MAX_CITY_BOMBARD_DAMAGE / 100)
		if pAttackingUnit:GetDomainType() == DomainTypes.DOMAIN_AIR and pDefendingCity and (defenderFinalDamage > cityMaxDamage) then -- Air attack on city dealing more damage than city max.
			Dprint ("-----------------", g_DebugCombat)
			Dprint ("Damage (" .. defenderFinalDamage ..") dealed to  " .. pDefendingCity:GetName() .. " are superior to  " .. cityMaxDamage .." (".. MAX_CITY_BOMBARD_DAMAGE .. "% of " .. defenderMaxHP .." HP max for city)", g_DebugCombat)
			local diff = defenderFinalDamage - cityMaxDamage -- difference between the max damage allowed to the city via air bombing, and the actual total damage
			local extraDamage = math.min( defenderDamage, diff) -- return the extra damage done by the air bombing from the maximum allowed
			pDefendingCity:ChangeDamage( - extraDamage ) --- restore the extra damage to the city HP
			TransfertDamage( pDefendingCity, extraDamage)
		end		
		--]]

		-- Combat message

		-- Player is attacking ?
		if iAttackingPlayer == Game:GetActivePlayer() then
			Dprint ("- Active player is attacking...", g_DebugCombat)
			Dprint ("- combatType = " ..combatType, g_DebugCombat)

			if combatType == AIRBOMB and pDefendingUnit then
				Dprint ("- Alert text for AIR BOMB...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey(), attackerDamage, defenderDamage))
			
			elseif combatType == CITYBOMB then
				Dprint ("- Alert text for AIR BOMB on city...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_CITY_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingCity:GetName(), attackerDamage, defenderDamage))
			
			elseif (combatType == INTERCEPT or combatType == GRDINTERCEPT) and pDefendingUnit then
				Dprint ("- Alert text for INTERCEPT...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey(), attackerDamage, defenderDamage))
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_AIR_UNIT_HURT", pAttackingUnit:GetNameKey(), pInterceptingUnit:GetNameKey(), interceptorDamage))
			
			elseif (combatType == INTERCEPT or combatType == GRDINTERCEPT) and bCity  then
				Dprint ("- Alert text for INTERCEPT on city attack...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_CITY_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingCity:GetName(), attackerDamage, defenderDamage))
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_AIR_UNIT_HURT", pAttackingUnit:GetNameKey(), pInterceptingUnit:GetNameKey(), interceptorDamage))
			
			elseif combatType == RANGED and pDefendingUnit then
				Dprint ("- Alert text for RANGED...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_BY_RANGED", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey(), defenderDamage))
			
			elseif combatType == RANGED and not pDefendingUnit and not pDefendingCity  then
				Dprint ("- Alert text for RANGED on unknown city...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_UNKNOWN_CITY_BY_RANGED", pAttackingUnit:GetNameKey(), defenderDamage))
						
			elseif combatType == RANGED and pDefendingCity  then
				Dprint ("- Alert text for RANGED on city...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_CITY_BY_RANGED", pAttackingUnit:GetNameKey(), pDefendingCity:GetName(), defenderDamage))
			
			elseif bRetreat then
				Dprint ("- Alert text for RETREAT...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_RETREAT", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey()))
				--Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ATTACK_RETREAT_FULL", pAttackingUnit:GetNameKey(), defenderDamage, pDefendingUnit:GetNameNoDesc(), attackerDamage))
			end
		end
		-- Player is defending ?
		if iDefendingPlayer == Game:GetActivePlayer() then
			Dprint ("- Active player is defending...", g_DebugCombat)
			Dprint ("- combatType = " ..combatType, g_DebugCombat)

			if combatType == AIRBOMB and pDefendingUnit then
				Dprint ("- Alert text for AIR BOMB...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey(), attackerDamage, defenderDamage))
			
			elseif combatType == CITYBOMB then
				Dprint ("- Alert text for AIR BOMB on city...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOUR_CITY_ATTACKED_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingCity:GetName(), attackerDamage, defenderDamage))
			

			elseif (combatType == INTERCEPT or combatType == GRDINTERCEPT) and pDefendingUnit  then
				Dprint ("- Alert text for INTERCEPT...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey(), attackerDamage, defenderDamage))
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_HURT_ENEMY_AIR", pAttackingUnit:GetNameKey(), pInterceptingUnit:GetNameKey(), interceptorDamage))
			
			elseif (combatType == INTERCEPT or combatType == GRDINTERCEPT) and pDefendingCity  then
				Dprint ("- Alert text for INTERCEPT on city attack...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOUR_CITY_ATTACKED_BY_AIR", pAttackingUnit:GetNameKey(), pDefendingCity:GetName(), attackerDamage, defenderDamage))
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_HURT_ENEMY_AIR", pAttackingUnit:GetNameKey(), pInterceptingUnit:GetNameKey(), interceptorDamage))
			
			elseif combatType == RANGED and pDefendingUnit then
				Dprint ("- Alert text for RANGED...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_ARE_ATTACKED_BY_RANGED", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey(), defenderDamage))
			
			elseif combatType == RANGED and not pDefendingUnit and not pDefendingCity then
				Dprint ("- Alert text for RANGED on unknown city...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOUR_UNKNOWN_CITY_ATTACKED_BY_RANGED", pAttackingUnit:GetNameKey(), defenderDamage))
						
			elseif combatType == RANGED and pDefendingCity then
				Dprint ("- Alert text for RANGED on city...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOUR_CITY_ATTACKED_BY_RANGED", pAttackingUnit:GetNameKey(), pDefendingCity:GetName(), defenderDamage))
			
			elseif bRetreat then
				Dprint ("- Alert text for RETREAT...", g_DebugCombat)
				Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_RETREAT", pAttackingUnit:GetNameKey(), pDefendingUnit:GetNameKey()))
				--Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_MISC_YOU_RETREAT_FULL", pAttackingUnit:GetNameKey(), defenderDamage, pDefendingUnit:GetNameNoDesc(), attackerDamage))
			end
		end
	end

	Dprint("------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------", g_DebugCombat)

end
--GameEvents.CombatResult.Add( CombatResult )

function CombatEnded (iAttackingPlayer, iAttackingUnit, attackerDamage, attackerFinalDamage, attackerMaxHP, iDefendingPlayer, iDefendingUnit, defenderDamage, defenderFinalDamage, defenderMaxHP, iInterceptingPlayer, iInterceptingUnit, interceptorDamage, plotX, plotY)
	
	local bDebugEndCombat = false

	local pAttackingPlayer = Players[ iAttackingPlayer ]
	if pAttackingPlayer then -- In case the combat was aborted...
		
		SetEndCombatNum()
		local turn = Game.GetGameTurn()

		Dprint("")
		Dprint("------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------", g_DebugCombat)
		Dprint("COMBAT Ended #".. tostring(g_EndNum), g_DebugCombat)
		Dprint("------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------", g_DebugCombat)
		
		

		local pAttackingUnit = pAttackingPlayer:GetUnitByID( iAttackingUnit );		
		Dprint ("Attacking from plot at " .. pAttackingUnit:GetPlot():GetX() .. "," ..pAttackingUnit:GetPlot():GetY(), g_DebugCombat)
		Dprint ("Attacker is " .. tostring(pAttackingUnit:GetName()) .. ", Current Damage = " .. tostring(pAttackingUnit:GetDamage()), g_DebugCombat)

		local pDefendedPlot = GetPlot(plotX, plotY)
		local pDefendingCity
		local defendingPlotKey
		if pDefendedPlot then
			Dprint ("Defending plot at " .. pDefendedPlot:GetX() .. "," ..pDefendedPlot:GetY(), g_DebugCombat)
			pDefendingCity = pDefendedPlot:GetPlotCity()
			defendingPlotKey = GetPlotKey(pDefendedPlot)
		end

		local attackingPlayerName = pAttackingPlayer:GetCivilizationShortDescription()
		local attackingUnitName = pAttackingUnit:GetName() or iAttackingUnit	

		local pDefendingPlayer = Players[iDefendingPlayer]
		local pDefendingUnit = pDefendingPlayer:GetUnitByID( iDefendingUnit )

		local defendingPlayerName = pDefendingPlayer:GetCivilizationShortDescription()
		local defendingUnitName

		local defenderHealth = defenderMaxHP - defenderFinalDamage

		if pDefendingUnit then
			defendingUnitName = pDefendingUnit:GetName() or iDefendingUnit
			Dprint ("Defender is unit : " .. tostring(defendingUnitName).. ", Current Damage = " .. tostring(pDefendingUnit:GetDamage()), g_DebugCombat)

		elseif pDefendingCity then
			defendingUnitName = pDefendingCity:GetName()
			Dprint ("Defender is city of " .. tostring(defendingUnitName), g_DebugCombat)
		end
		
		local pInterceptingPlayer = Players[iInterceptingPlayer]
		local pInterceptingUnit 
		local interceptingUnitName

		if pInterceptingPlayer then
			Dprint ("Found intercepting player: ".. tostring(pInterceptingPlayer:GetName()), g_DebugCombat)
			pInterceptingUnit = pInterceptingPlayer:GetUnitByID( iInterceptingUnit )
			if pInterceptingUnit then
				interceptingUnitName = pInterceptingUnit:GetName() or pInterceptingUnit:GetID()
				Dprint ("Selected Interceptor is ".. tostring(interceptingUnitName), g_DebugCombat)
			end
		end

		-- determine combat type

		local combatType = MELEE -- default type

		if pAttackingUnit:GetDomainType() == DomainTypes.DOMAIN_AIR then
			if pDefendingUnit and pDefendingUnit:GetDomainType() == DomainTypes.DOMAIN_AIR then -- dogfight !
				Dprint ("Attack type : Dogfight", g_DebugCombat)
				combatType = DOGFIGHT
			elseif pInterceptingUnit then
				combatType = INTERCEPT
			elseif pDefendingCity then
				combatType = CITYBOMB			
			else			
				combatType = AIRBOMB
			end

		elseif pAttackingUnit:IsHasPromotion( GameInfo.UnitPromotions.PROMOTION_INVISIBLE_SUBMARINE.ID ) then
			Dprint ("Attack type : From Submarine", g_DebugCombat)
			combatType = SUBATTACK

		elseif pDefendingUnit and pDefendingUnit:IsHasPromotion( GameInfo.UnitPromotions.PROMOTION_INVISIBLE_SUBMARINE.ID ) then
			Dprint ("Attack type : Hunting Submarine", g_DebugCombat)
			combatType = SUBHUNT

		elseif pAttackingUnit:IsRanged() and (pAttackingUnit:GetDomainType() ~= DomainTypes.DOMAIN_AIR) and not (pAttackingUnit:IsHasPromotion( GameInfo.UnitPromotions.PROMOTION_INVISIBLE_SUBMARINE.ID )) then		
			Dprint ("Attack type : Ranged", g_DebugCombat)
			combatType = RANGED
		end
		
		-- value for combat logging		
		local AttackerUniqueID, DefenderUniqueID, InterceptorUniqueID, AttackerToDefender, AttackerToInterceptor, DefenderToAttacker, InterceptorToAttacker, AttackerXP, DefenderXP, InterceptorXP
		local AttackerPlayerID, DefenderPlayerID, InterceptorPlayerID, AttackerCivType, DefenderCivType, InterceptorCivType, AttackerUnitType, DefenderUnitType, InterceptorUnitType

		local bCity = ( pDefendingCity ~= nil )
		
		--[[
		AttackerUnitKey = GetUnitKey(pAttackingUnit)
		AttackerUniqueID = g_UnitData[AttackerUnitKey].UniqueID
		AttackerPlayerID = iAttackingPlayer
		AttackerCivType = GetCivTypeFromPlayerID(iAttackingPlayer)
		AttackerUnitType = GameInfo.Units[pAttackingUnit:GetUnitType()].Type
		
		DefenderPlayerID = iDefendingPlayer
		DefenderCivType = GetCivTypeFromPlayerID(iDefendingPlayer)

		if pDefendingUnit then
			DefenderUnitKey = GetUnitKey(pDefendingUnit)
			DefenderUniqueID = g_UnitData[DefenderUnitKey].UniqueID
			DefenderUnitType = GameInfo.Units[pDefendingUnit:GetUnitType()].Type
		end

		if pInterceptingUnit then
			InterceptorUnitKey = GetUnitKey(pInterceptingUnit)
			InterceptorUniqueID = g_UnitData[InterceptorUnitKey].UniqueID
			InterceptorPlayerID = iInterceptingPlayer
			InterceptorCivType = GetCivTypeFromPlayerID(InterceptorPlayerID)
			InterceptorUnitType = GameInfo.Units[pInterceptingUnit:GetUnitType()].Type
			InterceptorToAttacker = interceptorDamage
		end
		--]]

		AttackerToDefender = defenderDamage
		DefenderToAttacker = attackerDamage

		-- display combat result
		Dprint("---------------------------------------------------------------------------------------------------------------", bDebugEndCombat)
		Dprint ("Combat Ended:		" .. Locale.ToUpper(attackingPlayerName) .."		attack			".. Locale.ToUpper(defendingPlayerName), bDebugEndCombat);
		Dprint("---------------------------------------------------------------------------------------------------------------", bDebugEndCombat)
		Dprint ("Attacking Unit:		" .. attackingUnitName, bDebugEndCombat);
		Dprint ("Defending Unit:							".. defendingUnitName, bDebugEndCombat);
		-- if interception was made
		if pInterceptingUnit then
			Dprint ("Intercepting Unit:						".. interceptingUnitName, bDebugEndCombat);
			Dprint ("From Interceptor:		".. interceptorDamage, bDebugEndCombat);
			Dprint ("From Opponent:		".. attackerDamage .."					".. defenderDamage, bDebugEndCombat);
		else	
			Dprint ("Receveid Damage:		".. attackerDamage .."					".. defenderDamage, bDebugEndCombat);
		end
		Dprint ("Final Damage:		".. attackerFinalDamage .."					"..  defenderFinalDamage, bDebugEndCombat);
		if pAttackingUnit:IsRanged() and pAttackingUnit:GetDomainType() ~= DomainTypes.DOMAIN_AIR then -- fix bad leftHP calculation for ranged unit
			Dprint ("HitPoints left:		".. attackerMaxHP - pAttackingUnit:GetDamage() .."					"..  defenderHealth, bDebugEndCombat);
		else
			Dprint ("HitPoints left:		".. attackerMaxHP - attackerFinalDamage .."					"..  defenderHealth, bDebugEndCombat);
		end

		-- call OnCityAttacked functions
		if pDefendingCity then

			Dprint("City owner	= " .. pDefendingCity:GetOwner(), g_DebugCombat)
			Dprint("Final damage= " .. defenderFinalDamage, g_DebugCombat)
			Dprint("Attacker ID = " .. iAttackingPlayer, g_DebugCombat)

			Dprint("City has been attacked, calling LuaEvents.OnCityAttacked ...", g_DebugCombat)
			LuaEvents.OnCityAttacked(iAttackingUnit, defendingPlotKey, iAttackingPlayer, iDefendingPlayer)
			
			if defenderFinalDamage >= defenderMaxHP then --pDefendingCity:GetGameTurnAcquired() == turn or  then -- little hack, see if defenderFinalDamage can be used here.
				Dprint("City has been captured, calling LuaEvents.OnCityCaptured ...", g_DebugCombat)
				LuaEvents.OnCityCaptured(iAttackingUnit, defendingPlotKey, iAttackingPlayer, iDefendingPlayer)
			end
		end
	end
	

	Dprint("------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------", g_DebugCombat)

end
--GameEvents.CombatEnded.Add( CombatEnded )


--------------------------------------------------------------
-- Retreat
--------------------------------------------------------------

function SetDirection (unit, attackDirection)
	local direction_types = {
			DirectionTypes.DIRECTION_NORTHEAST,
			DirectionTypes.DIRECTION_EAST,
			DirectionTypes.DIRECTION_SOUTHEAST,
			DirectionTypes.DIRECTION_SOUTHWEST,
			DirectionTypes.DIRECTION_WEST,
			DirectionTypes.DIRECTION_NORTHWEST
	}
	for loop, direction in ipairs(direction_types) do
	-- compte direction clock, si inf 3 tourne cloc sinon counter
		if unit:GetFacingDirection() == attackDirection then
			return
		else
			unit:RotateFacingDirectionClockwise(1);
		end
	end
end

function GetAttackDirection (attackingPlot, defendingPlot)
	local direction_types = {
			DirectionTypes.DIRECTION_NORTHEAST,
			DirectionTypes.DIRECTION_EAST,
			DirectionTypes.DIRECTION_SOUTHEAST,
			DirectionTypes.DIRECTION_SOUTHWEST,
			DirectionTypes.DIRECTION_WEST,
			DirectionTypes.DIRECTION_NORTHWEST
	}
	local attackX = attackingPlot:GetX();
	local attackY = attackingPlot:GetY();
	--local defendX = defendingPlot:GetX();
	--local defendY = defendingPlot:GetY();
	-- loop through adjacent plots.
	local prevDir = direction_types[6]
	local nextDir = 0 
	for loop, direction in ipairs(direction_types) do
		local adjPlot = Map.PlotDirection(attackX, attackY, direction)
		if adjPlot == defendingPlot then -- bug here : sometimes there's no adjPlot to defending plot...
			nextDir = direction_types[loop+1] or direction_types[1]
			Dprint ("attack direction = " .. direction ..", next = ".. nextDir ..", prev = ".. prevDir, g_DebugCombat);
			return direction, prevDir, nextDir
		end
		prevDir = direction_types[loop]
	end
	Dprint ("WARNING: can find defending plot adjacent to attacker, returning previous direction only: " .. prevDir);
	return prevDir, prevDir, prevDir -- bad bugfix
end

function CanRetreat(retreatPlot)
	if  retreatPlot == nil then
		Dprint ("can't retreat, nil plot", g_DebugCombat);
		return false
	end
	if retreatPlot:GetNumUnits() == 0 and not retreatPlot:IsImpassable() and not retreatPlot:IsWater() and not retreatPlot:IsCity() and not retreatPlot:IsMountain() then
		return true
	else
		if retreatPlot:GetNumUnits() > 0 then Dprint ("can't retreat, need an empty plot", g_DebugCombat); end
		if retreatPlot:IsImpassable() then Dprint ("can't retreat, impassable plot", g_DebugCombat); end
		if retreatPlot:IsWater() then Dprint ("can't retreat, water plot", g_DebugCombat); end
		if retreatPlot:IsCity() then Dprint ("can't retreat, city plot", g_DebugCombat); end
		if retreatPlot:IsMountain() then Dprint ("can't retreat, mountain plot", g_DebugCombat); end
		return false
	end
end

function Retreat (iAttackingPlayer, iAttackingUnit, iDefendingPlayer, iDefendingUnit, retreatDamageBase)
	local pAttackingUnit = Players[ iAttackingPlayer ]:GetUnitByID( iAttackingUnit );
	local pDefendingUnit = Players[ iDefendingPlayer ]:GetUnitByID( iDefendingUnit );
	-- attackdirection may be wrong. should test from attackingplot and defensiveplot, require a new function ?
	--local attackDirection = pAttackingUnit:GetFacingDirection();
	local attackingPlot = pAttackingUnit:GetPlot();	
	local defendingPlot = pDefendingUnit:GetPlot();
	local firstDirection, secondDirection, thirdDirection = GetAttackDirection (attackingPlot, defendingPlot);
	Dprint ("possible retreat direction = " .. firstDirection ..", ".. secondDirection ..", ".. thirdDirection, g_DebugCombat);
	local defendingX = defendingPlot:GetX();
	local defendingY = defendingPlot:GetY();
	local findPlotToRetreat = false;
	local nextPlot, prevPlot = nil, nil
	local attackDirection, prevDirection, nextDirection = 0, 0, 0
	local firstPlot = Map.PlotDirection(defendingX, defendingY, firstDirection);
	local rand = 1 --math.random( 1, 2 ) <- no randomness for MP
	if rand == 1 then
		nextPlot = Map.PlotDirection(defendingX, defendingY, secondDirection)
		nextDirection = secondDirection
		prevPlot = Map.PlotDirection(defendingX, defendingY, thirdDirection)
		prevDirection = thirdDirection
	else	
		nextPlot = Map.PlotDirection(defendingX, defendingY, thirdDirection)
		nextDirection = thirdDirection
		prevPlot = Map.PlotDirection(defendingX, defendingY, secondDirection)
		prevDirection = secondDirection
	end
	local retreatPlot = nil
	-- can we retreat here ?
	if CanRetreat(firstPlot) then
		retreatPlot = firstPlot
		findPlotToRetreat = true;
		attackDirection = firstDirection
	elseif CanRetreat(nextPlot) then
		retreatPlot = nextPlot
		findPlotToRetreat = true;
		attackDirection = nextDirection
	elseif CanRetreat(prevPlot) then
		retreatPlot = prevPlot
		findPlotToRetreat = true;
		attackDirection = prevDirection
	end
	if findPlotToRetreat then
		Dprint ("retreating to new plot, attack direction is : ".. attackDirection, g_DebugCombat);
		local retreatX = retreatPlot:GetX();
		local retreatY = retreatPlot:GetY();

		pDefendingUnit:SetXY(retreatX,retreatY);
		pDefendingUnit:SetMoves(pDefendingUnit:MovesLeft() - (2*MOVE_DENOMINATOR)) -- 2 moves removed

		SetDirection (pDefendingUnit, attackDirection);
		
		pAttackingUnit:SetMoves(pAttackingUnit:MovesLeft() + MOVE_DENOMINATOR) -- allow at least one move
		pAttackingUnit:PopMission()
		pAttackingUnit:PushMission(MissionTypes.MISSION_MOVE_TO, defendingX, defendingY, 0, 0, 1, MissionTypes.MISSION_MOVE_TO, defendingPlot, pDefendingUnit)
		pAttackingUnit:SetMoves(pAttackingUnit:MovesLeft() - MOVE_DENOMINATOR) -- remove free move from above

		return true
	end
	-- if we can't retreat, give extra damage
	if findPlotToRetreat == false then	

		Dprint ("can't retreat !", g_DebugCombat)
		local retreatDamage = Round(retreatDamageBase / 2)
		pDefendingUnit:SetMoves(0)
		local currentDamage = pDefendingUnit:GetDamage()
		local currentHP = pDefendingUnit:GetCurrHitPoints()
		retreatDamage = math.min(retreatDamage, currentHP-1)
		Dprint ("currentdamage :" .. currentDamage, g_DebugCombat)
		Dprint ("extradamage :" .. retreatDamage, g_DebugCombat)
		pDefendingUnit:SetDamage( currentDamage + retreatDamage)
		if iDefendingPlayer == Game:GetActivePlayer() then
			Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_YOU_UNIT_EXTRA_DAMAGE_NO_RETREAT", pDefendingUnit:GetNameKey(), retreatDamage))
		end		
		if iAttackingPlayer == Game:GetActivePlayer() then
			Events.GameplayAlertMessage(Locale.ConvertTextKey("TXT_KEY_YOU_GIVE_EXTRA_DAMAGE_NO_RETREAT", pDefendingUnit:GetNameKey(), retreatDamage))
		end
	end

	return false
end 

--------------------------------------------------------------
-- First Strike
--------------------------------------------------------------
-- (now handled in the DLL code)

function ReinitUnits(playerID)
	local player = Players[playerID]
	if player and player:IsAlive() then
	
		Dprint ("ReinitUnits for " .. tostring(player:GetName()), bDebug)
		Dprint("-------------------------------------", bDebug)
	
		for unit in player:Units() do
			local unitType = unit:GetUnitType()
			if unit:IsMarkedBestDefender() then
				Dprint("WARNING: ".. unit:GetName() .." of ".. player:GetName() .." was marked 'best defender' outside combat, unmark it...") 
				unit:SetMarkedBestDefender(false)
			end
		end
	end
end



--------------------------------------------------------------
-- Notes
--------------------------------------------------------------

-- GameEvents.UnitKilledInCombat.Add (function(iPlayer, iKilledPlayer) end))




-----------------------------------------
-- Stacking Limits functions
-----------------------------------------

function SetStackingLimitOnNewCity(iPlayer, x, y)
	Dprint ("-------------------------------------")
	Dprint ("Set Stacking limits in new city...")
	local player = Players[iPlayer]
	local city = GetPlot(x,y):GetPlotCity()
	SetCityStackingLimit(city)
end

function SetCityStackingLimit(city)
	local airLimit = GameDefines.CITY_AIR_UNIT_LIMIT
	local seaLimit = GameDefines.CITY_SEA_UNIT_LIMIT
	local landLimit = GameDefines.CITY_LAND_UNIT_LIMIT
	for building in GameInfo.Buildings() do -- to do: cache buildings with stacking effect in a global table on load ?
		if (city:GetNumBuilding(building.ID) > 0  ) then -- to do: do we want to take the number of buildings of same type as a factor ? 
			airLimit = airLimit + building.AirStackChange
			seaLimit = seaLimit + building.SeaStackChange
			landLimit = landLimit + building.LandStackChange
		end
	end
	if airLimit > 0 then
		city:SetAirStackLimit(airLimit)
	end
	if seaLimit > 0 then
		city:SetSeaStackLimit(seaLimit)
	end
	if landLimit > 0 then
		city:SetLandStackLimit(landLimit)
	end
	Dprint (" - " .. tostring(city:GetName()) .."		Air = " .. tostring(airLimit) ..", Sea = " .. tostring(seaLimit) ..", Land = " .. tostring(landLimit), bDebug)
end

function SetPlayerCitiesStackingLimit(iPlayer)

	local player = Players[iPlayer]
	if not player then
		return
	end
	
	if not player:IsEverAlive() then
		return
	end

	Dprint ("Set Stacking limits in cities for " .. tostring(player:GetName()), bDebug)
	Dprint("-------------------------------------", bDebug)

	for city in player:Cities() do
		SetCityStackingLimit(city)
	end
end
-- GameEvents.PlayerDoTurn.Add(SetPlayerCitiesStackingLimit)

function InitializeCitiesStackingLimit()
	for iPlayer = 0, GameDefines.MAX_PLAYERS-1 do
		SetPlayerCitiesStackingLimit(iPlayer)
	end
end


function InitializePlayerUnits()
	for iPlayer = 0, GameDefines.MAX_PLAYERS-1 do
		ReinitUnits(iPlayer)
	end
end